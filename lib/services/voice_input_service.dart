import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 마이크 상태.
enum VoiceStatus {
  /// 아직 준비 전.
  idle,

  /// 기기가 음성 인식을 못 한다.
  unavailable,

  /// 마이크나 음성 인식 권한이 거부됐다 (01-E1 시트를 띄울 상태).
  permissionDenied,

  /// 듣는 중.
  listening,

  /// 끝났다. [VoiceInputService.transcript] 에 결과가 있다.
  done,

  /// 인식 중 오류.
  error,
}

/// 인식 결과 한 조각.
class VoiceResult {
  const VoiceResult({required this.text, required this.isFinal});

  final String text;

  /// 중간 결과인지 최종인지. 홈 입력창은 중간 결과도 보여 준다.
  final bool isFinal;
}

/// 음성 → 글자.
///
/// 기기 안에서 처리되고, 결과 텍스트만 생성 요청에 실린다.
///
/// **소비자가 둘이다** — 홈 입력창은 받아서 채우기만 하고(자동 전송 X), 질문형(06-9)은
/// 끝나는 즉시 답으로 보낸다. 서비스는 그걸 모른다. 스트림을 듣는 쪽이 정한다.
class VoiceInputService {
  VoiceInputService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  /// 영어. PRD §9.
  static const String localeId = 'en_US';

  /// 2초 무음이면 자동 종료 (PRD §9).
  static const Duration silenceTimeout = Duration(seconds: 2);

  /// 한 번에 듣는 최대 길이. 전시에서 마이크가 열린 채 방치되는 걸 막는다.
  static const Duration maxListen = Duration(seconds: 30);

  final _results = StreamController<VoiceResult>.broadcast();
  final _levels = StreamController<double>.broadcast();
  final _statuses = StreamController<VoiceStatus>.broadcast();

  /// 중간·최종 인식 결과.
  Stream<VoiceResult> get results => _results.stream;

  /// 입력 음량 0~1. 파형 그리는 데 쓴다.
  Stream<double> get soundLevel => _levels.stream;

  Stream<VoiceStatus> get statuses => _statuses.stream;

  VoiceStatus _status = VoiceStatus.idle;
  VoiceStatus get status => _status;

  String _transcript = '';

  /// 지금까지 알아들은 문장.
  String get transcript => _transcript;

  String? _lastError;
  String? get lastError => _lastError;

  bool _initialized = false;
  bool get isListening => _status == VoiceStatus.listening;

  /// 권한이 거부된 상태인가. 화면이 01-E1 시트를 띄울지 판단한다.
  bool get isPermissionDenied => _status == VoiceStatus.permissionDenied;

  void _setStatus(VoiceStatus s) {
    _status = s;
    if (!_statuses.isClosed) _statuses.add(s);
  }

  // ---------------------------------------------------------------- 준비

  /// 한 번만 호출하면 된다. 권한 요청도 여기서 일어난다.
  ///
  /// 거부되면 false 를 돌려주고 상태가 [VoiceStatus.permissionDenied] 가 된다.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      final ok = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        // 최종 결과가 안 오면 마지막 중간 결과를 최종으로 쓴다.
        finalTimeout: const Duration(seconds: 2),
      );
      _initialized = ok;
      if (!ok) {
        _setStatus(
          _lastError == 'permission' ? VoiceStatus.permissionDenied : VoiceStatus.unavailable,
        );
      } else {
        _setStatus(VoiceStatus.idle);
      }
      return ok;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(VoiceStatus.unavailable);
      return false;
    }
  }

  // ---------------------------------------------------------------- 듣기

  /// 듣기 시작. 2초 무음이면 알아서 멈춘다.
  Future<bool> start() async {
    if (!await initialize()) return false;
    if (isListening) return true;

    _transcript = '';
    _lastError = null;

    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          pauseFor: silenceTimeout,
          listenFor: maxListen,
          cancelOnError: true,
          /*
           * onDevice 는 쓰지 않는다.
           *
           * speech_to_text 7.5.0 에는 알려진 버그가 있다(issue #673): 기기가 기기 내
           * 인식을 지원하지 않으면 에러를 내고도 **마이크를 켜 둔 채** 멈춰서, 그 뒤로
           * 앱을 다시 켤 때까지 음성 입력이 영영 안 된다. 수정본은 7.6.0-beta 에만 있다.
           * 끄면 아이폰이 기기 내/서버 인식을 알아서 고른다 — 영어 짧은 문장이라
           * 품질 차이는 거의 없다. 정식 버전이 나오면 다시 본다.
           */
          onDevice: false,
          listenMode: ListenMode.dictation,
        ),
      );
      _setStatus(VoiceStatus.listening);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(VoiceStatus.error);
      return false;
    }
  }

  /// 사용자가 직접 멈춘다. 지금까지 들은 것은 최종 결과로 올라온다.
  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _speech.stop();
    } catch (_) {}
    if (_status == VoiceStatus.listening) _setStatus(VoiceStatus.done);
  }

  /// 버린다. 결과를 쓰지 않는다 (입력창을 닫거나 화면을 떠날 때).
  Future<void> cancel() async {
    if (!_initialized) return;
    try {
      await _speech.cancel();
    } catch (_) {}
    _transcript = '';
    _setStatus(VoiceStatus.idle);
  }

  // ---------------------------------------------------------------- 콜백

  void _onResult(SpeechRecognitionResult result) {
    _transcript = result.recognizedWords;
    if (!_results.isClosed) {
      _results.add(VoiceResult(text: _transcript, isFinal: result.finalResult));
    }
    if (result.finalResult) _setStatus(VoiceStatus.done);
  }

  void _onLevel(double level) {
    // iOS 는 대략 -2~10 dB 범위를 준다. 파형이 쓰기 좋게 0~1 로 편다.
    final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
    if (!_levels.isClosed) _levels.add(normalized);
  }

  void _onError(SpeechRecognitionError error) {
    _lastError = error.errorMsg;
    if (error.errorMsg.contains('permission') || error.errorMsg.contains('denied')) {
      _setStatus(VoiceStatus.permissionDenied);
      return;
    }
    // speech_not_recognized 는 "아무 말 안 했다" 뿐이다 — 오류로 올리지 않는다.
    if (error.errorMsg.contains('no_match') ||
        error.errorMsg.contains('speech_timeout')) {
      _setStatus(VoiceStatus.done);
      return;
    }
    _setStatus(VoiceStatus.error);
  }

  void _onStatus(String status) {
    // 'listening' / 'notListening' / 'done'
    if (status == 'done' || status == 'notListening') {
      if (_status == VoiceStatus.listening) _setStatus(VoiceStatus.done);
    }
  }

  // ---------------------------------------------------------------- 테스트 통로
  //
  // 음성 인식은 실기기에서만 제대로 돈다(시뮬레이터 마이크는 신뢰할 수 없다).
  // 플러그인 없이도 상태 전이와 스트림 배선을 검증할 수 있게 열어 둔다.

  @visibleForTesting
  void emitResult(String text, {required bool isFinal}) => _onResult(
        SpeechRecognitionResult.init(
          [SpeechRecognitionWords(text, null, 1.0)],
          isFinal ? ResultType.finalResult : ResultType.partial,
        ),
      );

  @visibleForTesting
  void emitLevel(double raw) => _onLevel(raw);

  @visibleForTesting
  void emitError(String message) =>
      _onError(SpeechRecognitionError(message, false));

  @visibleForTesting
  void emitPlatformStatus(String status) => _onStatus(status);

  @visibleForTesting
  void markInitialized() {
    _initialized = true;
    _setStatus(VoiceStatus.idle);
  }

  @visibleForTesting
  void markListening() => _setStatus(VoiceStatus.listening);

  Future<void> dispose() async {
    await cancel();
    await _results.close();
    await _levels.close();
    await _statuses.close();
  }
}
