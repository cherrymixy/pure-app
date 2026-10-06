import 'package:flutter/material.dart';

/// 연출 값 — 색·타이포처럼 한 곳에 모아 둔다 (STEP 24).
///
/// 시안에 타임라인이 없어서 길이와 커브는 PRD 에 적힌 둘(사이드바 280ms,
/// 스플래시 0.6s/2s)을 기준으로 삼고 나머지는 그 리듬에 맞췄다. 숫자를
/// 위젯마다 흩어 두면 나중에 하나만 고치고 끝낼 수 없다.
///
/// 길이는 셋뿐이다. 더 늘리면 "비슷하지만 다른" 연출이 생긴다.
abstract final class AppMotion {
  /// 누른 느낌 — 칩·버튼의 눌림.
  static const Duration quick = Duration(milliseconds: 120);

  /// 들고 나는 것 — 말풍선 등장, 페이드.
  static const Duration enter = Duration(milliseconds: 240);

  /// 화면이 바뀌는 것 — 사이드바(PRD 280ms), 스크롤, 전환.
  static const Duration screen = Duration(milliseconds: 280);

  /// 스플래시에서 다음 화면으로.
  static const Duration splashOut = Duration(milliseconds: 320);

  /// 들어오는 것은 빨리 시작해 천천히 멈춘다.
  static const Curve easeIn = Curves.easeOutCubic;

  /// 나가는 것은 반대.
  static const Curve easeOut = Curves.easeInCubic;

  /// 말풍선이 떠오르는 높이.
  static const double riseFrom = 8;

  /// 기기에서 '동작 줄이기'를 켰으면 길이를 0 으로 만든다.
  ///
  /// 관람객 중에 멀미를 하는 사람이 있을 수 있고, 전시장 기기에서 켜 둘 수도
  /// 있다. 애니메이션을 끄는 쪽이지 기능을 끄는 게 아니다.
  static Duration maybe(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
