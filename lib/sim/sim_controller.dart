import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 시뮬레이터가 보내오는 이벤트.
///
/// `sim/src/runtime.ts` 의 `SimEvent` 와 같은 모양이다. 계약을 바꾸려면 양쪽을
/// 같이 고쳐야 하고, 플레이북상 사람의 승인이 필요하다.
sealed class SimEvent {
  const SimEvent();

  static SimEvent? parse(Object? raw) {
    final map = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : raw is Map
            ? raw.cast<String, dynamic>()
            : null;
    if (map == null) return null;

    return switch (map['type']) {
      'ready' => SimReady(
          limits: _parseLimits(map['limits']),
          behaviors: _stringList(map['behaviors']),
          faces: _stringList(map['faces']),
        ),
      'playing' => SimPlaying(
          id: map['id'] as String? ?? '',
          durationSec: (map['duration'] as num?)?.toDouble() ?? 0,
          behavior: map['behavior'] as String? ?? '',
        ),
      'ended' => SimEnded(id: map['id'] as String? ?? ''),
      'error' => SimError(message: map['message'] as String? ?? 'unknown'),
      _ => null,
    };
  }

  static List<String> _stringList(Object? v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  static Map<String, (double, double)> _parseLimits(Object? v) {
    final out = <String, (double, double)>{};
    if (v is! Map) return out;
    v.forEach((key, value) {
      if (value is List && value.length == 2) {
        out[key.toString()] = ((value[0] as num).toDouble(), (value[1] as num).toDouble());
      }
    });
    return out;
  }
}

/// 엔진·모델·표정이 모두 준비됐다. 관절 범위도 이때 함께 온다.
class SimReady extends SimEvent {
  const SimReady({required this.limits, required this.behaviors, required this.faces});

  /// 계약 관절 이름 → (최소, 최대) 도.
  ///
  /// robot.xml 에서 런타임에 읽어 온 값이다. Dart 쪽에 상수 파일을 두지 않는 이유 —
  /// 모델을 고치면 이 값이 자동으로 따라오고, 두 숫자가 어긋날 일이 없다.
  final Map<String, (double, double)> limits;
  final List<String> behaviors;
  final List<String> faces;
}

class SimPlaying extends SimEvent {
  const SimPlaying({required this.id, required this.durationSec, required this.behavior});
  final String id;
  final double durationSec;
  final String behavior;
}

class SimEnded extends SimEvent {
  const SimEnded({required this.id});
  final String id;
}

class SimError extends SimEvent {
  const SimError({required this.message});
  final String message;
}

/// `window.pure` 의 Dart 쪽 거울 (PRD 부록 B).
///
/// 메서드 이름과 인자는 JS 계약과 1:1 이다. 레시피·클립은 `models/` 의 Dart 클래스를
/// `toJson()` 으로 넘긴다 — 스키마가 같다.
class SimController {
  SimController();

  InAppWebViewController? _web;
  final _events = StreamController<SimEvent>.broadcast();
  final _readyCompleter = Completer<SimReady>();

  /// 시뮬레이터가 보내오는 이벤트 스트림.
  Stream<SimEvent> get events => _events.stream;

  /// 엔진 준비 완료. 관절 범위·허용 목록을 담고 있다.
  Future<SimReady> get ready => _readyCompleter.future;

  bool get isReady => _readyCompleter.isCompleted;

  SimReady? _readyInfo;

  /// 마지막 ready 정보. 아직 준비 전이면 null.
  SimReady? get info => _readyInfo;

  // ------------------------------------------------------------ 내부 연결

  /// `SimView` 가 WebView 를 만든 뒤 붙여 준다.
  void attach(InAppWebViewController controller) {
    _web = controller;
    controller.addJavaScriptHandler(
      handlerName: 'pureEvent',
      callback: (args) {
        final event = SimEvent.parse(args.isEmpty ? null : args.first);
        if (event == null) return null;
        if (event is SimReady && !_readyCompleter.isCompleted) {
          _readyInfo = event;
          _readyCompleter.complete(event);
        }
        if (!_events.isClosed) _events.add(event);
        return null;
      },
    );
  }

  void detach() {
    _web = null;
  }

  Future<void> dispose() async {
    await _events.close();
  }

  /// 로딩 실패처럼 JS 가 아예 못 뜬 경우를 바깥에서 알린다.
  void reportError(String message) {
    if (!_events.isClosed) _events.add(SimError(message: message));
  }

  Future<Object?> _call(String expression) async {
    final web = _web;
    if (web == null) throw StateError('시뮬레이터 WebView 가 아직 붙지 않았습니다');
    // 계약 함수가 던지면 메시지를 그대로 Dart 로 올린다 — 조용히 삼키지 않는다.
    final result = await web.evaluateJavascript(source: '''
      (function () {
        try { return { ok: true, value: $expression }; }
        catch (e) { return { ok: false, error: String(e && e.message || e) }; }
      })()
    ''');
    if (result is Map && result['ok'] == false) {
      throw SimCallException(result['error']?.toString() ?? 'unknown');
    }
    return result is Map ? result['value'] : result;
  }

  String _json(Object? value) => jsonEncode(value);

  // ------------------------------------------------------------ 계약 (부록 B)

  /// 동작 15종 중 하나를 재생한다. 끝나면 대기 모션으로 돌아간다.
  Future<String> playBehavior(String name, {double? speed, double? amplitude}) async {
    final params = _json({
      'speed': ?speed,
      'amplitude': ?amplitude,
    });
    final id = await _call("window.pure.playBehavior(${_json(name)}, $params)");
    return id?.toString() ?? '';
  }

  /// 레시피(동작 조합)를 순서대로 재생한다. 끝나면 `SimEnded`.
  Future<String> playRecipe(Map<String, Object?> recipe, {double? speed, double? amplitude}) async {
    final params = _json({
      'speed': ?speed,
      'amplitude': ?amplitude,
    });
    final id = await _call("window.pure.playRecipe(${_json(recipe)}, $params)");
    return id?.toString() ?? '';
  }

  /// 키프레임 클립을 직접 재생한다 (Tier 2). amplitude 는 적용되지 않는다.
  Future<String> playClip(Map<String, Object?> clip, {double? speed}) async {
    final params = _json({'speed': ?speed});
    final id = await _call("window.pure.playClip(${_json(clip)}, $params)");
    return id?.toString() ?? '';
  }

  /// 대기 모션. 시그니처가 바뀌면 여기로 반영한다.
  Future<void> setIdle({String? behavior, double? speed, double? amplitude}) async {
    final params = _json({
      'behavior': ?behavior,
      'speed': ?speed,
      'amplitude': ?amplitude,
    });
    await _call('window.pure.setIdle($params)');
  }

  /// 표정 7종 중 하나.
  Future<void> setFace(String name) async => _call('window.pure.setFace(${_json(name)})').then((_) {});

  /// 재생을 멈추고 대기 모션으로 돌아간다. 그 자리에 얼어붙지 않는다.
  Future<void> stop() async => _call('window.pure.stop()').then((_) {});

  /// 카메라. 생략한 값은 기본 시점을 쓴다.
  Future<void> setView({double? azimuth, double? elevation, double? distance}) async {
    final v = _json({
      'azimuth': ?azimuth,
      'elevation': ?elevation,
      'distance': ?distance,
    });
    await _call('window.pure.setView($v)');
  }

  /// 전체 화면에서 드래그 회전을 켜고 끈다.
  Future<void> enableOrbit(bool on) async =>
      _call('window.pure.enableOrbit($on)').then((_) {});

  /// 현재 프레임 PNG dataURL. 라이브러리 썸네일이 이 경로를 쓴다.
  Future<String> capture() async {
    final data = await _call('window.pure.capture()');
    return data?.toString() ?? '';
  }

  /// 표정 영상 재생 상태. `?probe=1` 로 띄운 빌드에서만 값이 온다 (검증용).
  Future<Map<String, Object?>> faceStatus() async {
    final raw = await _call('window.__simFace ? window.__simFace() : null');
    return raw is Map ? raw.cast<String, Object?>() : const {};
  }

  Future<String> version() async => (await _call('window.pure.version'))?.toString() ?? '';
}

/// 계약 함수가 던진 에러 (허용 목록 밖 이름, 범위 밖 값 등).
class SimCallException implements Exception {
  SimCallException(this.message);
  final String message;
  @override
  String toString() => 'SimCallException: $message';
}
