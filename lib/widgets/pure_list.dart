import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// 시안 `Frame` (`488:4740` · `488:4747`) — 흰 카드 radius 20, 위아래 4.
class PureCard extends StatelessWidget {
  const PureCard({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(children: rows),
      );
}

/// 메뉴 한 줄 — 왼쪽 16 / 오른쪽 14 / 위아래 14, 간격 12, 꺾쇠 18.
class PureRow extends StatelessWidget {
  const PureRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconSize = 18,
    this.value,
    this.trailingText,
    this.trailingIcon,
    this.trailing,
    this.valueIsBrand = false,
    this.labelOnTop = false,
    this.showChevron = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final AppIconName? icon;
  final double iconSize;

  /// 라벨 아래(또는 위) 한 줄.
  final String? value;

  /// 꺾쇠 왼쪽 작은 글자 (로봇 수 등).
  final String? trailingText;

  /// 꺾쇠 대신 보여 줄 아이콘 (고른 기기의 체크 등).
  final AppIconName? trailingIcon;

  /// 꺾쇠 대신 넣을 것 (스위치 등).
  final Widget? trailing;

  final bool valueIsBrand;

  /// 모션 시그니처 행처럼 작은 라벨이 위, 값이 아래인가.
  final bool labelOnTop;

  final bool showChevron;

  /// 되돌릴 수 없는 행동 — 글자가 빨개진다.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final small = AppTextStyles.bodyS.copyWith(
      color: valueIsBrand ? AppColors.textBrand : AppColors.textSecondary,
    );
    final big = AppTextStyles.bodyM.copyWith(
      fontWeight: FontWeight.w500,
      color: danger ? AppColors.textError : AppColors.textPrimary,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x16,
          14,
          14,
          14,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 36,
                height: 36,
                child: Center(child: AppIcon(icon!, size: iconSize)),
              ),
              const SizedBox(width: AppSpacing.x12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: labelOnTop
                    ? [
                        Text(label, style: small),
                        const SizedBox(height: 2),
                        Text(value ?? '', style: big),
                      ]
                    : [
                        Text(label, style: big),
                        if (value != null) ...[
                          const SizedBox(height: 2),
                          Text(value!, style: small),
                        ],
                      ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: AppSpacing.x8),
              Text(
                trailingText!,
                style: AppTextStyles.labelS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.x12),
              trailing!,
            ],
            if (trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.x12),
              AppIcon(trailingIcon!, size: 18),
            ],
            if (showChevron) ...[
              const SizedBox(width: AppSpacing.x12),
              const AppIcon(
                AppIconName.chevron,
                size: 18,
                color: AppColors.iconSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
