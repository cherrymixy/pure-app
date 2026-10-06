import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Figma `Button` (`451:4209`).
///
/// 시안 설명: *Primary(세이지) / Inverse(블랙) / Secondary(흰색) /
/// Subtle(팝업·시트 안 보조 버튼) / Text × L·S × Default·Disabled.*
///
/// 크기 L 은 높이 56 · 좌우 24 · 라벨 `PURE/Body/L Strong`,
/// S 는 높이 40 · 좌우 16 · 라벨 `PURE/Label/M`. 라운드는 둘 다 full.
/// 시안의 고정 폭(L 354 / S 120)은 쓰지 않는다 — 부모가 폭을 정한다.
class PureButton extends StatelessWidget {
  const PureButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PureButtonVariant.primary,
    this.size = PureButtonSize.l,
  });

  final String label;

  /// null 이면 Disabled 상태로 그린다.
  final VoidCallback? onPressed;

  final PureButtonVariant variant;
  final PureButtonSize size;

  bool get _disabled => onPressed == null;

  @override
  Widget build(BuildContext context) {
    // Disabled 는 variant 와 무관하게 같은 모습이다 (Text 만 배경이 없다).
    final background = _disabled
        ? (variant == PureButtonVariant.text
            ? Colors.transparent
            : AppColors.bgDisabled)
        : variant.background;
    final foreground = _disabled ? AppColors.textDisabled : variant.foreground;

    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: size.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.paddingX),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: size.textStyle.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PureButtonVariant {
  /// 세이지. 화면의 주된 행동 하나.
  primary(AppColors.bgBrand, AppColors.textOnBrand),

  /// 블랙.
  inverse(AppColors.bgInverse, AppColors.textOnInverse),

  /// 흰색.
  secondary(AppColors.bgSurface, AppColors.textPrimary),

  /// 팝업·시트 안 보조 버튼.
  subtle(AppColors.bgSurfaceMuted, AppColors.textPrimary),

  /// 배경 없이 글자만.
  text(Colors.transparent, AppColors.textLink);

  const PureButtonVariant(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

enum PureButtonSize {
  l(height: 56, paddingX: AppSpacing.x24),
  s(height: 40, paddingX: AppSpacing.x16);

  const PureButtonSize({required this.height, required this.paddingX});

  final double height;
  final double paddingX;

  TextStyle get textStyle =>
      this == PureButtonSize.l ? AppTextStyles.bodyLStrong : AppTextStyles.labelM;
}
