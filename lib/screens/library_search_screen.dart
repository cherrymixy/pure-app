import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/situations.dart';
import '../data/strings.dart';
import '../providers/library_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/pure_empty.dart';
import '../widgets/pure_chip.dart';
import 'library_screen.dart';

/// 07-3 검색 — Figma `482:5004`.
///
/// 시안 값: 검색창 292×48(radius 22, 1.5 `border/strong`) + Cancel /
/// 필터 칩 / 결과 수 / 목록. 이름의 일치 글자는 세이지로 강조한다.
class LibrarySearchScreen extends StatefulWidget {
  const LibrarySearchScreen({super.key});

  @override
  State<LibrarySearchScreen> createState() => _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends State<LibrarySearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final q = _query.text.trim();
    final results = library.search(q, situationLabel: situationLabel);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 시안: 검색창 위 12 (상태바 50 → 62).
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      controller: _query,
                      onChanged: () => setState(() {}),
                      onClear: () => setState(_query.clear),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      S.librarySearchCancel,
                      // 시안 15 Medium — Body/M 과 크기가 같고 굵기만 다르다.
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 시안: 검색창 아래 16, 칩 43, 그 아래 11.
            const SizedBox(height: AppSpacing.x16),
            _FilterRow(value: library.filter, onChanged: library.setFilter),
            const SizedBox(height: 11),
            // 시안 07-3.no_results 에는 결과 수 줄이 없다.
            if (q.isNotEmpty && results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  0,
                  AppSpacing.x24,
                  6,
                ),
                child: Text(
                  fill(
                    results.length == 1
                        ? S.librarySearchResultOne
                        : S.librarySearchResults,
                    {'count': results.length},
                  ),
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            Expanded(
              child: q.isNotEmpty && results.isEmpty
                  ? PureNoResults(
                      title: fill(S.emptySearchTitle, {'query': q}),
                      body: S.emptySearchBody,
                      actionLabel: S.emptySearchAction,
                      // 찾던 말을 들고 홈으로 간다.
                      onAction: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x24,
                        0,
                        AppSpacing.x24,
                        AppSpacing.x24,
                      ),
                      children: [
                        for (final m in results) ...[
                          MotionCard(
                            motion: m,
                            playing: false,
                            onPlay: () => Navigator.pushNamed(
                              context,
                              AppRoutes.motionDetail,
                              arguments: m.id,
                            ),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.motionDetail,
                              arguments: m.id,
                            ),
                            nameSpan: _highlight(m.name, q),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 일치하는 글자를 세이지로 (시안 `482:5030`).
  InlineSpan? _highlight(String name, String query) {
    if (query.isEmpty) return null;
    final lower = name.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < name.length) {
      final found = lower.indexOf(q, i);
      if (found < 0) {
        spans.add(TextSpan(text: name.substring(i)));
        break;
      }
      if (found > i) spans.add(TextSpan(text: name.substring(i, found)));
      spans.add(
        TextSpan(
          text: name.substring(found, found + q.length),
          style: const TextStyle(color: AppColors.textBrand),
        ),
      );
      i = found + q.length;
    }
    return TextSpan(children: spans);
  }
}

/// 시안 `Search field` — 높이 48 · radius 22 · 1.5 `border/strong` ·
/// 왼쪽 16 / 오른쪽 12 · 간격 10.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderStrong, width: 1.5),
        ),
        padding: const EdgeInsets.only(left: AppSpacing.x16, right: 12),
        child: Row(
          children: [
            const AppIcon(AppIconName.search, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => onChanged(),
                style: AppTextStyles.bodyL,
                decoration: InputDecoration(
                  hintText: S.librarySearchHint,
                  hintStyle: AppTextStyles.bodyL.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            if (controller.text.isNotEmpty) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: const AppIcon(AppIconName.close, size: 16),
              ),
            ],
          ],
        ),
      );
}

/// 라이브러리와 같은 필터 칩 줄.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});

  final LibraryFilter value;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 43,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          children: [
            for (final f in LibraryFilter.values)
              Padding(
                padding: EdgeInsets.only(
                  right: f == LibraryFilter.values.last ? 0 : AppSpacing.x8,
                ),
                child: PureChip(
                  label: switch (f) {
                    LibraryFilter.all => S.libraryFilterAll,
                    LibraryFilter.auto => S.libraryFilterAuto,
                    LibraryFilter.manual => S.libraryFilterManual,
                  },
                  state: f == value
                      ? PureChipState.selected
                      : PureChipState.normal,
                  onTap: () => onChanged(f),
                ),
              ),
          ],
        ),
      );
}
