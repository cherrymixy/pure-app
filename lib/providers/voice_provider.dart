import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/voice_input_service.dart';

/// 음성 입력을 쓰는 두 곳.
enum VoiceConsumer {
  /// 홈 입력창 — 받아서 **채우기만** 한다. 자동 전송하지 않는다 (PRD §9).
  composer,

  /// 질문형 06-9 — 끝나는 즉시 답으로 보낸다.
  questionFlow,
}

/// 음성 상태를 화면에 전달한다.
///
/// 어디에 쓸지는 [start] 를 부르는 쪽이 정하고, 결과는 [onFinal] 콜백으로 간다.
/// 서비스는 소비자를 모른다.
class VoiceProvider extends ChangeNotifier {
  VoiceProvider(this._service) {
    _resultSub = _service.results.listen(_onResult);
    _levelSub = _service.soundLevel.listen((l) {
      _level = l;
      notifyListeners();
    });
    _statusSub = _service.statuses.listen((s) {
      notifyListeners();
      if (s == VoiceStatus.done) _deliverFinal();
    });
  }

  final VoiceInputService _service;
  StreamSubscription<VoiceResult>? _resultSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<VoiceStatus>? _statusSub;

  VoiceConsumer? _consumer;
  void Function(String text)? _onFinal;
  bool _delivered = false;

  double _level = 0;
  String _text = '';

  VoiceStatus get status => _service.status;
  bool get isListening => _service.isListening;
  bool get isPermissionDenied => _service.isPermissionDenied;

  /// 파형용 음량 0~1.
  double get level => _level;

  /// 실시간 자막.
  String get text => _text;

  VoiceConsumer? get consumer => _consumer;

  /// 듣기 시작. [onFinal] 은 인식이 끝났을 때 한 번만 불린다.
  Future<bool> start({
    required VoiceConsumer consumer,
    required void Function(String text) onFinal,
  }) async {
    _consumer = consumer;
    _onFinal = onFinal;
    _delivered = false;
    _text = '';
    _level = 0;
    notifyListeners();

    final ok = await _service.start();
    notifyListeners();
    return ok;
  }

  /// 사용자가 마이크를 다시 눌러 멈춘다.
  Future<void> stop() => _service.stop();

  /// 결과를 버린다 (화면을 떠나거나 X 를 누를 때).
  Future<void> cancel() async {
    _onFinal = null;
    _consumer = null;
    _text = '';
    await _service.cancel();
    notifyListeners();
  }

  void _onResult(VoiceResult r) {
    _text = r.text;
    notifyListeners();
    if (r.isFinal) _deliverFinal();
  }

  /// 최종 결과를 한 번만 전달한다.
  ///
  /// `done` 상태와 `isFinal` 결과가 둘 다 올 수 있어서, 안 막으면 질문형에서 같은 답이
  /// 두 번 전송된다.
  void _deliverFinal() {
    if (_delivered) return;
    final text = _text.trim();
    if (text.isEmpty) return;
    _delivered = true;
    _onFinal?.call(text);
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _levelSub?.cancel();
    _statusSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
