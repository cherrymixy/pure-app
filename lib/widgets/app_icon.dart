import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Figma 에서 뽑은 아이콘.
///
/// SVG 안의 색은 무시하고 [color] 로 칠한다 — 그래야 같은 아이콘을 밝은 배경과
/// 어두운 배경에 모두 쓸 수 있다.
///
/// 화면 177개가 쓰는 아이콘은 다섯 종류뿐이다. 나머지(화살표·닫기·체크 등)는
/// Material 기본 아이콘으로 충분하고, 시안과 어긋나는 게 보이면 STEP 23 에서 교체한다.
enum AppIconName {
  /// 재생 (42.66 × 44.74).
  play('play.svg'),

  /// 입력창 왼쪽 + (24).
  plus('plus.svg'),

  /// 입력창 오른쪽 마이크 (22).
  mic('mic.svg'),

  /// 상단 알림 종 (24.55).
  bell('bell.svg');

  const AppIconName(this.file);
  final String file;

  String get path => 'assets/images/icons/$file';
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = AppColors.iconPrimary,
  });

  final AppIconName name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        name.path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
