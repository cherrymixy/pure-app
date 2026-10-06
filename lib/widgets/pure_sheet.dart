import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pure_button.dart';

/// 바닥에서 올라오는 시트의 공통 틀 — Figma 07-2 `481:3099` · `481:3399`.
///
/// 시안 값: 위 모서리 radius 28 · 좌우 24 · 위 10 / 아래 44 · 손잡이 36×5.
class PureSheet extends StatelessWidget {
  const PureSheet({super.key, required this.children, this.center = false});

  final List<Widget> children;

  /// 내용을 가운데로 (삭제 확인처럼).
  final bool center;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x24,
            10,
            AppSpacing.x24,
            44,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  center ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
              children: [const Center(child: _Grabber()), ...children],
            ),
          ),
        ),
      );
}

/// 시안 `Handle` — 36 × 5, radius 3, `bg/disabled`.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.bgDisabled,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

Future<T?> _show<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bgOverlay,
      builder: builder,
    );

/// 되돌릴 수 없는 행동을 묻는다 — 시안 `07-2.delete_motion` (`481:3099`).
///
/// 시안 값: 손잡이 아래 26 · 제목 Title/M 가운데 · 8 · 본문 Body/M 가운데 ·
/// 24 · 빨간 버튼 · 6 · Subtle 취소.
Future<bool> showPureConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? body,
}) async {
  final ok = await _show<bool>(
    context,
    (context) => PureSheet(
      center: true,
      children: [
        const SizedBox(height: 26),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleM,
        ),
        if (body != null) ...[
          const SizedBox(height: AppSpacing.x8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.x24),
        SizedBox(
          width: double.infinity,
          child: PureButton(
            label: confirmLabel,
            variant: PureButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: PureButton(
            label: S.actionCancel,
            variant: PureButtonVariant.subtle,
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 이름을 고친다 — 시안 `07-2.rename` (`481:3399`).
///
/// 시안 값: 손잡이 아래 22 · 제목 Title/M 왼쪽 · 16 · 입력 56(radius 16,
/// `bg/surface-muted`, 1.5 `border/strong`, 좌우 18, 오른쪽에 글자 수) ·
/// 20 · Save · 6 · Cancel.
///
/// [validate] 가 문구를 돌려주면 저장이 막히고 그 문구가 입력 아래에 뜬다.
Future<String?> showPureRename(
  BuildContext context, {
  required String title,
  required String initial,
  required int maxLength,
  String? Function(String)? validate,
}) {
  final controller = TextEditingController(text: initial);
  return _show<String>(
    context,
    (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final text = controller.text.trim();
        final error = validate?.call(text);
        final canSave = text.isNotEmpty && text != initial && error == null;

        return PureSheet(
          children: [
            const SizedBox(height: 22),
            Text(title, style: AppTextStyles.titleM),
            const SizedBox(height: AppSpacing.x16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderStrong, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: maxLength,
                      onChanged: (_) => setSheet(() {}),
                      style: AppTextStyles.bodyL,
                      decoration: const InputDecoration(
                        filled: false,
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x8),
                  Text(
                    '${controller.text.characters.length}/$maxLength',
                    style: AppTextStyles.labelS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: AppTextStyles.bodyS.copyWith(color: AppColors.textError),
              ),
            ],
            const SizedBox(height: AppSpacing.x20),
            PureButton(
              label: S.actionSave,
              onPressed: canSave ? () => Navigator.pop(context, text) : null,
            ),
            const SizedBox(height: 6),
            PureButton(
              label: S.actionCancel,
              variant: PureButtonVariant.subtle,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    ),
  );
}
