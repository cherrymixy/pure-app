import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 타이포 토큰 — Figma `F / Typography` (노드 458:4812) 에서 그대로 옮겼다.
///
/// 이름은 Figma 스타일 이름을 따른다. `PURE/Title/M` → [titleM].
/// 폰트 파일 연결은 STEP 21 에서 한다 — 그 전까지는 시스템 폰트로 떨어진다.
abstract final class AppTextStyles {
  /// 본문 폰트.
  ///
  /// Figma 에는 `Google Sans Flex` 로 적혀 있지만 **Pretendard** 를 쓴다(승아 결정).
  /// 한글까지 한 파일로 덮고 OFL 라이선스라 임베드가 자유롭다. 크기·행간·굵기는
  /// 시안 값을 그대로 쓰므로 레이아웃은 달라지지 않는다.
  static const String fontFamily = 'Pretendard';

  /// Pretendard 가 라틴·한글을 모두 덮으므로 폴백은 시스템 기본만 둔다.
  static const List<String> fontFamilyFallback = <String>[];

  /// 시안이 몇 군데서 쓰는 SemiBold. 토큰에는 없고 그 자리에서만 얹는다
  /// (08-1 모드 이름, 08-5 활동 이름 등).
  static const FontWeight semiBold = FontWeight.w600;

  static TextStyle _base({
    required double size,
    required double height,
    required FontWeight weight,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSize: size,
        // Figma 의 lineHeight(px) 를 Flutter 의 배수로 환산한다.
        height: height / size,
        fontWeight: weight,
        letterSpacing: 0,
        color: color ?? AppColors.textPrimary,
      );

  // ---- Display / Title ----

  /// 30 / 38 Regular — 홈 인사말.
  static TextStyle get display =>
      _base(size: 30, height: 38, weight: FontWeight.w400);

  /// 30 / 38 Medium.
  static TextStyle get titleL =>
      _base(size: 30, height: 38, weight: FontWeight.w500);

  /// 22 / 29 Medium — 질문형 질문.
  static TextStyle get titleM =>
      _base(size: 22, height: 29, weight: FontWeight.w500);

  /// 18 / 24 Medium — 시트 제목.
  static TextStyle get titleS =>
      _base(size: 18, height: 24, weight: FontWeight.w500);

  /// 16 / 22 Medium — 상단바 제목.
  static TextStyle get header =>
      _base(size: 16, height: 22, weight: FontWeight.w500);

  // ---- Body ----

  /// 16 / 22 Regular.
  static TextStyle get bodyL =>
      _base(size: 16, height: 22, weight: FontWeight.w400);

  /// 16 / 22 Medium.
  static TextStyle get bodyLStrong =>
      _base(size: 16, height: 22, weight: FontWeight.w500);

  /// 15 / 22 Regular — 본문 기본.
  static TextStyle get bodyM =>
      _base(size: 15, height: 22, weight: FontWeight.w400);

  /// 13 / 18 Regular — 보조 설명.
  static TextStyle get bodyS =>
      _base(size: 13, height: 18, weight: FontWeight.w400);

  // ---- Label / Caption ----

  /// 14 / 20 Medium — 버튼·칩.
  static TextStyle get labelM =>
      _base(size: 14, height: 20, weight: FontWeight.w500);

  /// 13 / 18 Medium — 작은 버튼.
  static TextStyle get labelS =>
      _base(size: 13, height: 18, weight: FontWeight.w500);

  /// 11 / 14 Regular — 섹션 라벨·시각.
  static TextStyle get caption =>
      _base(size: 11, height: 14, weight: FontWeight.w400);

  // ---- 화면 전용 ----

  /// 홈 인사말. 시안(`480:2043`)이 토큰이 아닌 값을 쓴다 — 34.78 / 42.96 Light.
  /// 다른 데서 쓰지 않는다.
  static TextStyle get homeGreeting =>
      _base(size: 34.78, height: 42.96, weight: FontWeight.w300);
}
