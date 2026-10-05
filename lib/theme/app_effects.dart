import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 그림자·블러 토큰 — Figma `F / Effect` (노드 458:4947).
abstract final class AppEffects {
  /// 카드가 바닥에서 살짝 떠 있는 정도.
  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: AppColors.alphaBlack06,
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// 입력창·시트처럼 화면 위에 떠 있는 것.
  static const List<BoxShadow> shadowFloat = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 8),
      blurRadius: 28,
    ),
  ];

  /// 시트 뒤 배경 블러.
  static const double overlayBlurRadius = 50;

  static ImageFilter get overlayBlur =>
      ImageFilter.blur(sigmaX: overlayBlurRadius / 2, sigmaY: overlayBlurRadius / 2);

  /// 홈 배경의 라디얼 글로우.
  ///
  /// 시안의 `bg/brand-glow` 를 중심에서 바깥으로 흩는다. 위치·크기는 STEP 23 에서
  /// 홈 화면 시안을 보고 맞춘다 — 여기서는 색과 번지는 방식만 정의한다.
  static RadialGradient brandGlow({double opacity = 0.55}) => RadialGradient(
        colors: [
          AppColors.bgBrandGlow.withValues(alpha: opacity),
          AppColors.bgBrandGlow.withValues(alpha: 0),
        ],
        stops: const [0, 1],
      );
}
