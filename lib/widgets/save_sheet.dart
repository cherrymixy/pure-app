import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/situations.dart';
import '../data/strings.dart';
import '../models/motion_spec.dart';
import '../models/saved_motion.dart';
import '../providers/library_provider.dart';
import '../services/motion_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';
import 'pure_button.dart';

/// 저장 시트가 돌려주는 것.
class SaveRequest {
  const SaveRequest({
    required this.name,
    required this.situation,
    required this.kind,
  });

  final String name;

  /// 어떤 상황에 묶이는가. onlyWhenAsked 면 상황 없이 손으로만 재생.
  final Situation situation;

  /// 그 상황이 왔을 때 묻지 않고 재생할지(auto) 물어볼지(askFirst).
  final ReactionKind kind;
}

/// 06-7 저장 시트 — Figma `483:19167`(기본) · `483:19694`(대체 경고).
///
/// 시안 값: 위 모서리 radius 28 · 좌우 패딩 24 · 위 10 / 아래 44 · 손잡이 36×5.
/// 이름 입력은 `bg/surface-muted` 높이 52 radius 16, 선택지는 한 덩어리(radius 18)
/// 안에 두 줄로 들어간다.
///
/// 같은 상황에 이미 자동 재생 모션이 있으면 노란 경고가 뜨고 버튼이
/// "Replace and save" 로 바뀐다. 기존 모션은 **지워지지 않고** "물어보고 재생" 으로
/// 내려간다 (부록 D 결정).
Future<SaveRequest?> showSaveSheet(
  BuildContext context, {
  required MotionSpec spec,
  String? lastUserText,
  Situation? initialSituation,
}) {
  return showModalBottomSheet<SaveRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bgOverlay,
    builder: (context) => _SaveSheet(
      spec: spec,
      lastUserText: lastUserText,
      initialSituation: initialSituation,
    ),
  );
}

class _SaveSheet extends StatefulWidget {
  const _SaveSheet({
    required this.spec,
    this.lastUserText,
    this.initialSituation,
  });

  final MotionSpec spec;
  final String? lastUserText;
  final Situation? initialSituation;

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  late final TextEditingController _name;

  /// 되묻기나 칩에서 상황을 이미 알고 들어왔는가.
  bool get _situationKnown =>
      widget.initialSituation != null &&
      widget.initialSituation != Situation.onlyWhenAsked;

  /// 상황을 아는 경우의 선택 — 묻지 않고 재생할지.
  bool _playWithoutAsking = true;

  /// 상황을 모르는 경우의 선택.
  Situation _situation = Situation.onlyWhenAsked;

  @override
  void initState() {
    super.initState();
    final library = context.read<LibraryProvider>();
    // 이름은 상황 사전 + 마지막 문장 규칙으로 짓는다. GPT 를 다시 부르지 않는다.
    final suggested = widget.spec.name.trim().isNotEmpty
        ? widget.spec.name.trim()
        : MotionEngine.suggestName(
            situation: widget.initialSituation,
            lastUserText: widget.lastUserText,
          );
    // 이미 쓰는 이름이면 번호를 붙여 제안한다.
    _name = TextEditingController(
      text: MotionEngine.suggestName(
        situation: widget.initialSituation,
        lastUserText: suggested,
        taken: library.all.map((m) => m.name),
      ),
    );
    _situation = widget.initialSituation ?? Situation.onlyWhenAsked;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 저장될 상황. 상황을 알고 들어왔으면 그대로 쓴다 (시안은 다시 묻지 않는다).
  Situation get _resolvedSituation =>
      _situationKnown ? widget.initialSituation! : _situation;

  ReactionKind get _resolvedKind {
    if (_resolvedSituation == Situation.onlyWhenAsked) return ReactionKind.manual;
    if (!_situationKnown) return ReactionKind.auto;
    return _playWithoutAsking ? ReactionKind.auto : ReactionKind.askFirst;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final trimmed = _name.text.trim();
    final nameOk = library.isNameAvailable(trimmed);

    // 경고는 **자동 재생으로 저장할 때만** 뜬다 — 물어보고 재생이면 밀어낼 일이 없다.
    final conflict = _resolvedKind == ReactionKind.auto
        ? library.conflictFor(_resolvedSituation)
        : null;

    return Padding(
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
        // 시안: 위 10 · 아래 44 · 좌우 24.
        padding: const EdgeInsets.fromLTRB(AppSpacing.x24, 10, AppSpacing.x24, 44),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Grabber()),
              const SizedBox(height: 22),
              Text(S.saveSheetTitle, style: AppTextStyles.titleM),
              const SizedBox(height: 18),

              _FieldLabel(S.saveSheetNameLabel),
              const SizedBox(height: 6),
              _NameField(controller: _name, onChanged: () => setState(() {})),
              if (trimmed.isNotEmpty && !nameOk) ...[
                const SizedBox(height: 6),
                // 시안에 없지만 이름이 겹치면 왜 저장이 안 되는지 알려야 한다.
                Text(
                  S.errorNameTaken,
                  style: AppTextStyles.bodyS.copyWith(color: AppColors.textError),
                ),
              ],
              const SizedBox(height: 18),

              _FieldLabel(S.saveSheetHowLabel),
              const SizedBox(height: 6),
              if (conflict != null) const SizedBox(height: 8),
              _Options(
                children: _situationKnown
                    ? [
                        _OptionRow(
                          selected: _playWithoutAsking,
                          title: S.saveSheetPlayWithoutAsking,
                          hint: S.saveSheetPlayWithoutAskingHint,
                          onTap: () => setState(() => _playWithoutAsking = true),
                        ),
                        _OptionRow(
                          selected: !_playWithoutAsking,
                          title: S.saveSheetAskBeforePlaying,
                          hint: S.saveSheetAskBeforePlayingHint,
                          onTap: () => setState(() => _playWithoutAsking = false),
                        ),
                      ]
                    : [
                        // 상황을 모르고 들어왔으면(자유 텍스트·영상) 먼저 그것부터
                        // 고르게 한다 — 시안에는 없는 갈래다.
                        for (final s in kSituationOrder)
                          _OptionRow(
                            selected: _situation == s,
                            title: isAutoSituation(s)
                                ? situationLabel(s)
                                : S.saveSheetOnlyWhenIAsk,
                            onTap: () => setState(() => _situation = s),
                          ),
                      ],
              ),

              if (conflict != null) ...[
                const SizedBox(height: 10),
                _ReplaceWarning(
                  text: fill(S.saveSheetReplaceWarning, {
                    'name': conflict.name,
                    'situation': _lowerFirst(situationLabel(_resolvedSituation)),
                  }),
                ),
              ],

              const SizedBox(height: AppSpacing.x20),
              PureButton(
                label: conflict != null ? S.saveSheetReplaceAction : S.actionSave,
                onPressed: (trimmed.isEmpty || !nameOk)
                    ? null
                    : () => Navigator.pop(
                          context,
                          SaveRequest(
                            name: trimmed,
                            situation: _resolvedSituation,
                            kind: _resolvedKind,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// 시안 `483:19335` — 36 × 5, radius 3, `bg/disabled`.
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

/// "Name" · "How should it play?" — `PURE/Body/S`, `text/secondary`.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
      );
}

/// 시안 `Input/Name` — 높이 52 · radius 16 · `bg/surface-muted` · 왼쪽 패딩 18.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.only(left: 18, right: AppSpacing.x16),
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: controller,
          maxLength: LibraryProvider.nameMax,
          onChanged: (_) => onChanged(),
          style: AppTextStyles.bodyL,
          decoration: const InputDecoration(
            // 테마의 채움(filled)이 상자 안에 또 상자를 만든다.
            filled: false,
            counterText: '',
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      );
}

/// 시안 `Trigger options` — 한 덩어리, radius 18, `bg/surface-muted`, 위아래 4.
class _Options extends StatelessWidget {
  const _Options({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
}

/// 선택지 한 줄 — 좌우 16 · 간격 12 · 체크 22. 고르면 제목이 Medium 이 된다.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.selected,
    required this.title,
    required this.onTap,
    this.hint,
  });

  final bool selected;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x16,
            vertical: 14,
          ),
          child: Row(
            children: [
              _Check(selected: selected),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        hint!,
                        // 시안 14 Regular — Label/M 과 크기·행간이 같고 굵기만 다르다.
                        style: AppTextStyles.labelM.copyWith(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// 고른 표시 — 22 원. 고르면 검정 바탕에 흰 체크, 아니면 1.5 테두리만.
class _Check extends StatelessWidget {
  const _Check({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? AppColors.bgInverse : AppColors.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(11),
          border: selected
              ? null
              : Border.all(color: AppColors.borderDefault, width: 1.5),
        ),
        child: selected
            ? const Center(
                child: AppIcon(
                  AppIconName.check,
                  size: 13,
                  color: AppColors.iconOnInverse,
                ),
              )
            : null,
      );
}

/// 시안 `Replace warning` (`480:3925`) — radius 14 · 좌우 12 / 위아래 10 · 간격 8.
/// 색 셋 다 토큰 밖이라 시안 값을 그대로 쓴다.
class _ReplaceWarning extends StatelessWidget {
  const _ReplaceWarning({required this.text});
  final String text;

  static const Color _bg = Color(0xFFFFF7EA);
  static const Color _fg = Color(0xFF5A3D00);
  static const Color _icon = Color(0xFFB26A00);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: 10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon(AppIconName.alert, size: 16, color: _icon),
            const SizedBox(width: AppSpacing.x8),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyS.copyWith(color: _fg),
              ),
            ),
          ],
        ),
      );
}
