/// 간격·라운드 토큰 — Figma `F / Spacing & Radius` (노드 458:4878).
///
/// 시안의 설명 그대로: **4px 그리드**. 화면 좌우 여백은 24, 카드 내부는 16~20,
/// 요소 간격은 8/12/16 을 주로 쓴다.
abstract final class AppSpacing {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;
  static const double x48 = 48;

  /// 화면 좌우 여백.
  static const double screenGutter = x24;

  /// 카드 안쪽 여백.
  static const double cardPadding = x16;
}

/// 모서리 라운드. 시안이 각 값의 쓰임새를 적어 두었다.
abstract final class AppRadius {
  /// 8 — 작은 태그.
  static const double xs = 8;

  /// 12 — 썸네일.
  static const double sm = 12;

  /// 16 — 입력창, 작은 카드.
  static const double md = 16;

  /// 20 — 카드, 말풍선.
  static const double lg = 20;

  /// 28 — 시트, 로봇 카드.
  static const double xl = 28;

  /// 999 — 버튼, 칩. 완전히 둥근 모서리.
  static const double full = 999;
}
