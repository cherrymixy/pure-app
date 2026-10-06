import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';
import 'pure_button.dart';

/// 아직 아무것도 없을 때 — Figma `07-1.empty` (`481:2936`).
///
/// 시안 값: 세로 가운데 묶음(간격 10) · 아이콘 칩 64(흰 원, 아이콘 26) ·
/// 제목 `PURE/Title/M` · 본문 `PURE/Body/M` 가운데 · 검정 알약 버튼
/// (좌우 22 / 위아래 12, radius 22, 15 Medium).
class PureEmptyState extends StatelessWidget {
  const PureEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final AppIconName icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.bgSurface,
                  shape: BoxShape.circle,
                ),
                child: Center(child: AppIcon(icon, size: 26)),
              ),
              const SizedBox(height: 10),
              Text(title, style: AppTextStyles.titleM, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 10),
                _Pill(label: actionLabel!, onTap: onAction),
              ],
            ],
          ),
        ),
      );
}

/// 시안 `Button/Go to Home` (`481:2942`) — 검정 알약, 좌우 22 / 위아래 12.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgInverse,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Text(
              label,
              // 시안 15 Medium — Body/M 과 크기가 같고 굵기만 다르다.
              style: AppTextStyles.bodyM.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textOnInverse,
              ),
            ),
          ),
        ),
      );
}

/// 찾는 것이 없을 때 — Figma `07-3.no_results` (`482:5133`).
///
/// 시안 값: 제목 `PURE/Title/S` · 본문 `PURE/Body/M` · 간격 10 ·
/// 그 아래 23 · `Button` Secondary L (내용 폭).
class PureNoResults extends StatelessWidget {
  const PureNoResults({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTextStyles.titleS, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 23),
                PureButton(
                  label: actionLabel!,
                  variant: PureButtonVariant.secondary,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      );
}
