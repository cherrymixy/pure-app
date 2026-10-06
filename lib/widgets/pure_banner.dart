import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// 화면 위에 걸리는 알림 띠 — Figma `Banner/Offline` (`483:21358`).
///
/// 시안 값: `bg/inverse` · radius 16 · 왼쪽 16 / 오른쪽 8 / 위아래 8 · 간격 10 ·
/// 아이콘 16 · 본문 `PURE/Label/M` `text/on-inverse` ·
/// 오른쪽 알약은 흰색 16% · 좌우 12 / 위아래 6 · radius 14 · 13 Medium 흰색.
///
/// 시안은 "No internet connection / Retry" 지만, 이 앱은 연결 상태를 보지 않는다.
/// 대신 시연 중 데모 모드가 켜져 있다는 걸 알린다 (PRD §6-7).
class PureBanner extends StatelessWidget {
  const PureBanner({
    super.key,
    required this.message,
    this.icon = AppIconName.wifiOff,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppIconName icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgInverse,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x16,
          AppSpacing.x8,
          AppSpacing.x8,
          AppSpacing.x8,
        ),
        child: Row(
          children: [
            AppIcon(icon, size: 16, color: AppColors.iconOnInverse),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.labelM.copyWith(
                  color: AppColors.textOnInverse,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 10),
              _ActionPill(label: actionLabel!, onTap: onAction),
            ],
          ],
        ),
      );
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x12,
              vertical: 6,
            ),
            child: Text(
              label,
              style: AppTextStyles.labelS.copyWith(
                color: AppColors.textOnInverse,
              ),
            ),
          ),
        ),
      );
}
