import 'package:flutter/material.dart';

/// 색 토큰 — Figma `F / Color` (노드 458:4287) 에서 그대로 옮겼다.
///
/// 라이트 테마만 쓴다(PRD 부록 D). 위젯에 hex 를 쓰지 않는다 (docs/conventions.md 규칙 9).
///
/// 두 층이다:
///  - **Primitives** — 팔레트 원색. 화면에서 직접 쓰지 않는다.
///  - **Semantic** — "이 자리에 쓰는 색". 화면은 이것만 본다.
///
/// 색을 바꾸고 싶으면 semantic 이 가리키는 primitive 를 바꾼다. 그러면 그 색을 쓰는
/// 모든 자리가 한 번에 따라온다.
abstract final class AppColors {
  // ================================================================ Primitives

  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF6F7F7);
  static const neutral100 = Color(0xFFF2F2F2);
  static const neutral150 = Color(0xFFE9EDED);
  static const neutral200 = Color(0xFFD8DCDD);
  static const neutral300 = Color(0xFFC3CBCC);
  static const neutral400 = Color(0xFFA0ABAD);
  static const neutral500 = Color(0xFF8A9698);
  static const neutral600 = Color(0xFF5F6B6D);
  static const neutral700 = Color(0xFF3D4A4D);
  static const neutral800 = Color(0xFF2C3335);
  static const neutral850 = Color(0xFF232829);
  static const neutral900 = Color(0xFF1A1E1F);
  static const neutral950 = Color(0xFF0F1213);
  static const neutral1000 = Color(0xFF000000);

  /// 브랜드 색. 파랑이 아니라 **세이지**다.
  static const sage50 = Color(0xFFE8F0F1);
  static const sage100 = Color(0xFFD3E2E4);
  static const sage200 = Color(0xFFA9C2C7);
  static const sage300 = Color(0xFF8FB3B9);
  static const sage400 = Color(0xFF789BA2);
  static const sage500 = Color(0xFF5F8189);
  static const sage600 = Color(0xFF4A666C);
  static const sage700 = Color(0xFF33474B);
  static const sage800 = Color(0xFF1E2A2C);
  static const sage900 = Color(0xFF142023);

  static const red50 = Color(0xFFFDECEC);
  static const red400 = Color(0xFFFF6B6E);
  static const red500 = Color(0xFFE5484D);
  static const red900 = Color(0xFF3A1517);

  static const blue300 = Color(0xFF7FA8FA);
  static const blue500 = Color(0xFF3B79F6);

  static const green400 = Color(0xFF4CC38A);
  static const green500 = Color(0xFF2FA36B);

  static const alphaBlack06 = Color(0x0F000000);
  static const alphaBlack35 = Color(0x59000000);
  static const alphaBlack55 = Color(0x8C000000);
  static const alphaWhite08 = Color(0x14FFFFFF);

  // ================================================================== Semantic

  // ---- 배경 ----

  /// 화면 바닥.
  static const bgCanvas = neutral100;

  /// 카드·시트.
  static const bgSurface = neutral0;
  static const bgSurfaceRaised = neutral0;

  /// 한 단계 눌린 면 (입력창 안, 비활성 칩).
  static const bgSurfaceMuted = neutral150;

  static const bgBrand = sage400;
  static const bgBrandSubtle = sage50;

  /// 홈 배경의 라디얼 글로우.
  static const bgBrandGlow = sage200;

  static const bgInverse = neutral900;
  static const bgDisabled = neutral200;
  static const bgErrorSubtle = red50;

  /// 시트·전체화면 뒤에 까는 딤.
  static const bgOverlay = alphaBlack35;

  // ---- 글자 ----

  static const textPrimary = neutral900;
  static const textSecondary = neutral500;
  static const textTertiary = neutral400;
  static const textBrand = sage400;
  static const textLink = neutral700;
  static const textOnBrand = neutral0;
  static const textOnInverse = neutral0;
  static const textDisabled = neutral500;
  static const textError = red500;

  // ---- 아이콘 ----

  static const iconPrimary = neutral900;
  static const iconSecondary = neutral500;
  static const iconBrand = sage400;
  static const iconOnBrand = neutral0;
  static const iconOnInverse = neutral0;

  // ---- 선 ----

  static const borderDefault = neutral200;
  static const borderStrong = neutral900;
  static const borderError = red500;

  // ---- 상태 ----

  /// 재생 중 — 여기만 파랑이다.
  static const statusLive = blue500;
  static const statusSuccess = green500;
  static const statusError = red500;

  /// 그림자 색 (app_effects 에서 쓴다).
  static const effectShadow = alphaBlack06;

  // ---- 시뮬레이터 ----

  /// 로봇 카드 안쪽. sim 번들의 스테이지 색과 맞춘다.
  static const simStage = Color(0xFF0A0A0D);
}
