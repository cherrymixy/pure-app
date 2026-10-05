import 'package:flutter/material.dart';

/// STEP 10 회색박스용 기본 조각들.
///
/// 디자인은 STEP 20~24 에서 Figma 를 읽어 전부 교체한다. 여기서는 **동작만** 본다 —
/// 색·간격·폰트를 고민하지 않는다 (CLAUDE.md 규칙 4).
abstract final class Gray {
  static const bg = Color(0xFFF4F4F6);
  static const card = Colors.white;
  static const line = Color(0xFFDDDDE3);
  static const text = Color(0xFF1A1A1F);
  static const dim = Color(0xFF75757F);
  static const accent = Color(0xFF3B5BDB);
  static const warn = Color(0xFFB8860B);
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 8, onRemove == null ? 14 : 6, 8),
        decoration: BoxDecoration(
          color: selected ? Gray.accent : Gray.card,
          borderRadius: BorderRadius.circular(18),
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
