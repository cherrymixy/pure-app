/// 08-3 `My robots` 의 기기 목록 — 시안 `481:3579` 의 더미.
///
/// 전시에는 로봇이 하나뿐이지만 시안이 둘을 보여 준다. 두 번째(Desk Lamp)는
/// 꺼져 있는 상태로만 있고 아무 동작도 하지 않는다.
library;

class RobotDevice {
  const RobotDevice({
    required this.name,
    required this.model,
    required this.status,
    this.connected = false,
  });

  final String name;
  final String model;

  /// "Connected" / "Offline".
  final String status;

  /// 지금 쓰고 있는 기기인가 (오른쪽 체크).
  final bool connected;
}

const List<RobotDevice> kRobotDevices = [
  RobotDevice(
    name: 'Purebot',
    model: 'Purebot Arm',
    status: 'Connected',
    connected: true,
  ),
  RobotDevice(
    name: 'Desk Lamp',
    model: 'Desk Lamp Arm 01',
    status: 'Offline',
  ),
];
