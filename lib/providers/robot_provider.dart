import 'package:flutter/foundation.dart';

import '../models/motion_signature.dart';
import '../models/robot.dart';
import '../repositories/data_repository.dart';

/// 로봇과 모션 시그니처.
///
/// 시그니처가 바뀌면 대기 모션이 즉시 바뀌어야 한다 (05-1). 그 반영은 화면이
/// [signature] 를 보고 SimController.setIdle 을 부르는 식으로 붙는다 — 여기서는
/// 시뮬레이터를 직접 건드리지 않는다 (docs/conventions.md 규칙 2 대비, 계층 분리).
class RobotProvider extends ChangeNotifier {
  RobotProvider(this._repo);

  final DataRepository _repo;

  Robot get robot => _repo.robot;
  /// 저장소가 통째로 바뀐 뒤(전시 데이터 초기화) 화면을 다시 그리게 한다.
  void refresh() => notifyListeners();
  MotionSignature get signature => robot.signature;

  /// 05 를 한 번이라도 마쳤는가. 첫 실행 분기에 쓴다.
  bool get onboarded => _repo.setting<bool>(SettingKeys.onboarded) ?? false;

  Future<void> updateSignature(MotionSignature next) async {
    if (next == signature) return;
    await _repo.saveRobot(robot.copyWith(signature: next));
    notifyListeners();
  }

  /// 05 를 마쳤다고 표시한다 (Skip 포함 — 기본값으로 끝낸 것도 마친 것이다).
  Future<void> markOnboarded() async {
    if (onboarded) return;
    await _repo.saveSetting(SettingKeys.onboarded, true);
    notifyListeners();
  }

  /// 08-2 Reset to default.
  Future<void> resetSignature() => updateSignature(MotionSignature.seed);

  Future<void> rename(String name) async {
    final t = name.trim();
    if (t.isEmpty || t == robot.name) return;
    await _repo.saveRobot(robot.copyWith(name: t));
    notifyListeners();
  }
}
