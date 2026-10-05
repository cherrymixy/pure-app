import 'package:flutter/foundation.dart';

import '../models/motion_spec.dart';
import '../repositories/data_repository.dart';
import '../services/generation/generation_client.dart';
import '../services/generation/generation_service.dart';

/// 생성 화면 상태 (06-3 ~ 06-E1).
enum GenerationStatus {
  idle,

  /// 점 3개가 도는 중.
  generating,

  /// 20초가 지나 "Still working on it…" 이 떠 있는 중.
  delayed,

  done,

  failed,
}

/// 생성 상태와 데모 모드 토글.
class GenerationProvider extends ChangeNotifier {
  GenerationProvider(this._service, this._repo) {
    _service.forceDemo = forceDemo;
  }

  final GenerationService _service;
  final DataRepository _repo;

  GenerationStatus _status = GenerationStatus.idle;
  GenerationResult? _last;
  String? _error;

  GenerationStatus get status => _status;
  bool get isBusy =>
      _status == GenerationStatus.generating || _status == GenerationStatus.delayed;

  GenerationResult? get last => _last;
  String? get error => _error;

  /// 마지막 결과가 데모였는가 — 화면의 "Using demo motions" 배지.
  bool get lastWasDemo => _last?.isDemo ?? false;

  // ---------------------------------------------------------------- 데모 모드

  /// 강제 데모 토글 (로봇 이름 5번 탭).
  bool get forceDemo => _repo.setting<bool>(SettingKeys.forceDemoMode) ?? false;

  /// 실제 GPT 를 쓸 수 있는 상태인가.
  bool get canUseOpenAI => _service.canUseOpenAI;

  Future<bool> toggleDemoMode() async {
    final next = !forceDemo;
    await _repo.saveSetting(SettingKeys.forceDemoMode, next);
    _service.forceDemo = next;
    notifyListeners();
    return next;
  }

  // ---------------------------------------------------------------- 생성

  /// 모션을 만든다. 취소되면 null 을 돌려준다 (호출부가 따로 다룰 게 없다).
  ///
  /// 실패해도 데모 결과가 오므로 null 이 아닌 값은 항상 쓸 수 있다.
  Future<GenerationResult?> generate(GenerationRequest request) async {
    _status = GenerationStatus.generating;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.generate(
        request,
        onDelay: () {
          if (_status == GenerationStatus.generating) {
            _status = GenerationStatus.delayed;
            notifyListeners();
          }
        },
      );
      _last = result;
      _status = GenerationStatus.done;
      notifyListeners();
      return result;
    } on GenerationException catch (e) {
      if (e.failure == GenerationFailure.cancelled) {
        // 새 요청이 들어와 밀렸다. 그 요청이 상태를 이어 받는다.
        return null;
      }
      _error = e.message;
      _status = GenerationStatus.failed;
      notifyListeners();
      return null;
    }
  }

  /// 생성 중이던 요청을 끊는다.
  void cancel() {
    _service.cancelInFlight();
    if (isBusy) {
      _status = GenerationStatus.idle;
      notifyListeners();
    }
  }

  /// 06-9 Softer — 다시 생성하지 않는다.
  MotionSpec soften(MotionSpec spec) => _service.soften(spec);

  void reset() {
    _status = GenerationStatus.idle;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
