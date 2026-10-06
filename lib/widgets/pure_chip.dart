import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'press_scale.dart';

/// Figma `Chip` (`452:4215`) — 추천 답안 · 필터.
///
/// 시안 값: 높이 43, 좌우 패딩 16, radius/full, 흰 배경, `PURE/Label/S`(13/18 Medium).
/// 시안 설명: *M·S × Default / Selected / Dimmed.*
class PureChip extends StatelessWidget {
  const PureChip({
    super.key,
    required this.label,
    this.onTap,
    this.state = PureChipState.normal,
    this.size = PureChipSize.m,
    this.onRemove,
  });

  final String label;
  final VoidCallback? onTap;
  final PureChipState state;
  final PureChipSize size;

  /// 첨부 칩처럼 지울 수 있을 때.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = state == PureChipState.selected;
    final dimmed = state == PureChipState.dimmed;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: PressScale(
        enabled: !dimmed && onTap != null,
        child: Material(
          color: selected ? AppColors.bgInverse : AppColors.bgSurface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: dimmed ? null : onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                size.paddingX,
                0,
                onRemove == null ? size.paddingX : AppSpacing.x8,
                0,
              ),
              child: SizedBox(
                height: size.height,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelS.copyWith(
                        color: selected
                            ? AppColors.textOnInverse
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (onRemove != null)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.x4),
                        child: InkResponse(
                          onTap: onRemove,
                          radius: 16,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: selected
                                ? AppColors.iconOnInverse
                                : AppColors.iconSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PureChipState { normal, selected, dimmed }

enum PureChipSize {
  /// 시안 기본. 높이 43 · 좌우 16.
  m(height: 43, paddingX: AppSpacing.x16),

  /// 시안 Chip S. 높이 32 · 좌우 12 — 08-5 활동 기록 필터가 쓴다.
  s(height: 32, paddingX: AppSpacing.x12);

  const PureChipSize({required this.height, required this.paddingX});

  final double height;
  final double paddingX;
}
