/// 08-1 로봇 화면의 성격 모드 — **보이기만 하는 더미** (승아 결정).
///
/// 시안(`488:4704`)에는 "Trigger now" 와 모드 셋이 있지만 PRD 에 없는 개념이라
/// 동작은 만들지 않았다. 관람객이 스쳐 볼 때 화면이 비어 보이지 않게 그리기만 한다.
/// 탭해도 아무 일도 일어나지 않는다.
library;

/// 모드 옆에 붙는 작은 칩의 색.
enum ModeChipTone {
  /// `bg/brand-subtle` + `text/brand` — 지금 켜진 모드의 성질.
  brandSubtle,

  /// `bg/brand` + 흰 글씨 — 그중에서도 고른 것.
  brand,

  /// `bg/surface-muted` + `text/primary` — 꺼져 있는 것.
  muted,
}

class ModeChip {
  const ModeChip(this.label, this.tone);
  final String label;
  final ModeChipTone tone;
}

class RobotMode {
  const RobotMode({
    required this.name,
    required this.detail,
    required this.chips,
    required this.aura,
    this.active = false,
  });

  final String name;

  /// 이름 아래 한 줄. 켜져 있으면 "Active now".
  final String detail;

  final List<ModeChip> chips;

  /// 왼쪽 48 원 그림.
  final String aura;

  final bool active;
}

/// 지금 무엇 때문에 이 모드가 켜졌는지 (시안 `488:4708`).
const String kTriggerNow = '11:00 AM, Home, Mom';

/// 시안의 세 모드 그대로.
const List<RobotMode> kRobotModes = [
  RobotMode(
    name: 'Family',
    detail: 'Active now',
    aura: 'assets/images/aura_family.svg',
    active: true,
    chips: [
      ModeChip('Slow', ModeChipTone.brandSubtle),
      ModeChip('Bow', ModeChipTone.brandSubtle),
    ],
  ),
  RobotMode(
    name: 'Partner',
    detail: 'Home / Boyfriend',
    aura: 'assets/images/aura_partner.svg',
    chips: [
      ModeChip('Playful', ModeChipTone.brand),
      ModeChip('Shy', ModeChipTone.muted),
    ],
  ),
  RobotMode(
    name: 'Focus',
    detail: 'Desk / 2 – 6 PM',
    aura: 'assets/images/aura_focus.svg',
    chips: [
      ModeChip('Still', ModeChipTone.muted),
      ModeChip('Mute', ModeChipTone.muted),
    ],
  ),
];
