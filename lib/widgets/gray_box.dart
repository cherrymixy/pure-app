import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 회색박스 단계의 기본 조각들.
///
/// 색은 STEP 20 에서 토큰으로 돌려놨다 — 임의의 회색을 쓰면 브랜드 색과 어긋나 보여
/// 오히려 헷갈린다. 레이아웃·치수는 아직 시안을 안 봤고, STEP 22 에서 Figma 컴포넌트를
/// 읽어 이 파일을 통째로 교체한다.
abstract final class Gray {
  static const bg = AppColors.bgCanvas;
  static const card = AppColors.bgSurface;
  static const line = AppColors.borderDefault;
  static const text = AppColors.textPrimary;
  static const dim = AppColors.textSecondary;
  static const accent = AppColors.bgBrand;
  static const warn = AppColors.sage700;
}

/// 상황 칩 · 필터 칩 공용.
class GrayChip extends StatelessWidget {
  const GrayChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.onRemove,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 8, onRemove == null ? 14 : 6, 8),
        decoration: BoxDecoration(
          color: selected ? Gray.accent : Gray.card,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? Gray.accent : Gray.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected ? Colors.white : Gray.text,
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: selected ? Colors.white : Gray.dim,
              ),
          ],
        ),
      ),
    );
  }
}

/// 섹션 제목.
class GraySectionLabel extends StatelessWidget {
  const GraySectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Gray.dim,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
}

/// 빈 화면.
class GrayEmptyState extends StatelessWidget {
  const GrayEmptyState({
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Gray.dim)),
              if (actionLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

/// 토스트. 3초(액션이 있으면 5초) 뒤 사라진다.
void showGrayToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: actionLabel == null ? 3 : 5),
      behavior: SnackBarBehavior.floating,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}

/// 확인 시트. 되돌릴 수 없는 동작 앞에 세운다.
Future<bool> showGrayConfirm(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(fontSize: 13, color: Gray.dim)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
