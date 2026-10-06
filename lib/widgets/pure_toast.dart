import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// 잠깐 떴다 사라지는 알림 — Figma `Toast` (`483:21729`).
///
/// 시안 값: `bg/inverse` 바탕 · radius 16 · 좌우 16 / 위아래 14 · 간격 10 ·
/// 세이지 체크 16 · 글자 `PURE/Label/M` · 오른쪽 동작은 `text/brand`.
void showPureToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      // Material 의 바탕·그림자를 지우고 시안 모양을 직접 그린다.
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      // 홈·채팅은 바닥에 입력창(59 + 여백)이 있다. 그 위로 띄운다.
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x24,
        0,
        AppSpacing.x24,
        86,
      ),
      duration: Duration(seconds: actionLabel == null ? 3 : 5),
      content: _Toast(
        message: message,
        actionLabel: actionLabel,
        onAction: () {
          messenger.hideCurrentSnackBar();
          onAction?.call();
        },
      ),
    ),
  );
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.message,
    required this.onAction,
    this.actionLabel,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgInverse,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const AppIcon(
              AppIconName.check,
              size: 16,
              color: AppColors.iconBrand,
            ),
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
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.labelM.copyWith(
                    color: AppColors.textBrand,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
