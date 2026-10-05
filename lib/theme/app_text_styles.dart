import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 타이포 토큰 — Figma `F / Typography` (노드 458:4812) 에서 그대로 옮겼다.
///
/// 이름은 Figma 스타일 이름을 따른다. `PURE/Title/M` → [titleM].
/// 폰트 파일 연결은 STEP 21 에서 한다 — 그 전까지는 시스템 폰트로 떨어진다.
abstract final class AppTextStyles {
  /// Figma `F / Typography` 에 적힌 패밀리.
  /// STEP 21 에서 assets/fonts/ 에 넣고 pubspec 에 등록한다.
  static const String fontFamily = 'Google Sans Flex';

  /// 한글이 섞일 때의 대체 폰트. 영어 UI 지만 사용자가 입력한 글자는 한글일 수 있다.
  static const List<String> fontFamilyFallback = ['Apple SD Gothic Neo'];

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
}
