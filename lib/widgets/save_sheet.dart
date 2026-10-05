import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/situations.dart';
import '../data/strings.dart';
import '../models/motion_spec.dart';
import '../models/saved_motion.dart';
import '../providers/library_provider.dart';
import '../services/motion_engine.dart';
import 'gray_box.dart';

/// 저장 시트가 돌려주는 것.
class SaveRequest {
  const SaveRequest({required this.name, required this.situation});

  final String name;

  /// onlyWhenAsked 면 수동 재생.
  final Situation situation;
}

/// 06-7 저장 시트 — 이름 자동 제안 + 반응 상황 + 대체 경고.
///
/// 같은 상황에 이미 자동 재생 모션이 있으면 노란 경고를 띄우고, 버튼 문구가
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
  late Situation _situation;

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
    _situation = widget.initialSituation ?? Situation.comesHome;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final trimmed = _name.text.trim();
    final conflict = library.conflictFor(_situation);
    final nameOk = library.isNameAvailable(trimmed);
    final tooLong = trimmed.length > LibraryProvider.nameMax;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(S.saveSheetTitle,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              const Text(S.saveSheetNameLabel,
                  style: TextStyle(fontSize: 12, color: Gray.dim)),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: false,
                maxLength: LibraryProvider.nameMax,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Gray.card,
                  counterText: '',
                  errorText: trimmed.isEmpty
                      ? S.errorNameEmpty
                      : (tooLong
                          ? null
                          : (nameOk ? null : S.errorNameTaken)),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              const Text(S.saveSheetHowLabel,
                  style: TextStyle(fontSize: 12, color: Gray.dim)),
              const SizedBox(height: 4),
              for (final s in kSituationOrder)
                RadioListTile<Situation>(
                  value: s,
                  // ignore: deprecated_member_use
                  groupValue: _situation,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _situation = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isAutoSituation(s)
                        ? '${S.saveSheetPlayWithoutAsking}: ${situationLabel(s)}'
                        : S.saveSheetOnlyWhenIAsk,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

              if (conflict != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6DD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8D9A8)),
                  ),
                  child: Text(
                    fill(S.saveSheetReplaceWarning, {'name': conflict.name}),
                    style: const TextStyle(fontSize: 12, color: Gray.warn, height: 1.4),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              FilledButton(
                onPressed: (trimmed.isEmpty || !nameOk)
                    ? null
                    : () => Navigator.pop(
                          context,
                          SaveRequest(name: trimmed, situation: _situation),
                        ),
                child: Text(
                  conflict != null ? S.saveSheetReplaceAction : S.actionSave,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(S.actionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
