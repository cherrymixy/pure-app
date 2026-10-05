import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/question_tree.dart';
import '../data/strings.dart';
import '../models/motion_spec.dart';
import '../providers/chat_provider.dart';
import '../providers/generation_provider.dart';
import '../providers/library_provider.dart';
import '../providers/robot_provider.dart';
import '../providers/voice_provider.dart';
import '../services/generation/generation_client.dart';
import '../services/motion_engine.dart';
import '../services/thumbnail_store.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../widgets/app_shell.dart';
import '../widgets/composer.dart';
import '../widgets/gray_box.dart';
import '../widgets/robot_card.dart';
import '../widgets/save_sheet.dart';
import 'home_screen.dart';

/// 06-9 질문형 생성 3단계.
///
/// 1단계 "언제" · 2단계 "어떻게" · 3단계 "이거 맞아?".
/// 1단계에서는 질문 트리의 **예시 모션**을, 2단계부터는 지금까지의 답으로 만든
/// **초안**을 카드에서 재생한다.
///
/// 답과 초안은 Chat 메시지로도 기록된다 — 채팅과 같은 대화 위에 올라간다
/// (부록 D 결정).
class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key, required this.entry});

  final ChatEntry entry;

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  static const int totalSteps = 3;

  late final QuestionBranch _branch;

  int _step = 1;
  WhenOption? _when;
  HowOption? _how;
  MotionSpec? _draft;
  bool _failed = false;
  String? _draftMessageId;

  final _text = TextEditingController();

  SimController get _sim => SimHost.controllerOf(context);

  @override
  void initState() {
    super.initState();
    _branch = branchForChip(widget.entry.chipId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final chat = context.read<ChatProvider>();
    await chat.ensureCurrent();
    // 사용자가 보낸 첫 문장을 대화에 남긴다.
    final text = widget.entry.text;
    if (text != null && text.trim().isNotEmpty) {
      await chat.addUserMessage(text: text);
    }
    await _playExample();
  }

  // ---------------------------------------------------------------- 재생

  /// 1단계 예시 모션.
  Future<void> _playExample() async {
    final option = _when ?? _branch.whenOptions.first;
    try {
      await _sim.playBehavior(option.exampleBehavior);
      await _sim.setFace('neutral');
    } catch (_) {}
  }

  Future<void> _playDraft() async {
    final draft = _draft;
    if (draft == null) return;
    try {
      await _sim.playRecipe(draft.recipe.toJson());
      await _sim.setFace(draft.face);
    } catch (_) {}
  }

  Future<void> _replay() => _step == 1 ? _playExample() : _playDraft();

  // ---------------------------------------------------------------- 단계 이동

  Future<void> _chooseWhen(WhenOption option) async {
    final chat = context.read<ChatProvider>();
    setState(() {
      _when = option;
      _step = 2;
      _failed = false;
    });
    await chat.addUserMessage(text: option.label.replaceAll('\n', ' '));
    await _generateDraft();
  }

  Future<void> _chooseHow(HowOption option) async {
    final chat = context.read<ChatProvider>();
    setState(() {
      _how = option;
      _step = 3;
      _failed = false;
    });
    await chat.addUserMessage(text: option.label.replaceAll('\n', ' '));
    await _generateDraft();
  }

  void _back() {
    if (_step == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      if (_step == 3) {
        _step = 2;
        _how = null;
      } else {
        _step = 1;
        _when = null;
        _draft = null;
      }
      _failed = false;
    });
    _replay();
  }

  // ---------------------------------------------------------------- 생성

  Future<void> _generateDraft() async {
    final gen = context.read<GenerationProvider>();
    final robot = context.read<RobotProvider>();
    final chat = context.read<ChatProvider>();

    final pending = await chat.addPendingReply();
    if (!mounted) return;

    final result = await gen.generate(GenerationRequest(
      signature: robot.signature,
      text: _promptText(),
      chipId: widget.entry.chipId,
      whenOptionId: _when?.id,
      howOptionId: _how?.id,
      situation: _when?.situation,
    ));

    if (!mounted) return;
    if (result == null) {
      await chat.failReply(pending.id);
      if (mounted) setState(() => _failed = true);
      return;
    }

    await chat.completeReply(pending.id, result.spec);
    if (!mounted) return;
    setState(() {
      _draft = result.spec;
      _draftMessageId = pending.id;
    });
    await _playDraft();
    await _captureThumbnail(result.spec);
  }

  /// 지금까지의 답을 한 문장으로. GPT 에는 이게 상황 설명이 된다.
  String _promptText() {
    final parts = <String>[
      if (widget.entry.text != null && widget.entry.text!.trim().isNotEmpty)
        widget.entry.text!.trim(),
      if (_when != null) 'When: ${_when!.label.replaceAll('\n', ' ')}',
      if (_how != null) 'How: ${_how!.hint}',
    ];
    return parts.join('. ');
  }

  Future<void> _captureThumbnail(MotionSpec spec) async {
    final messageId = _draftMessageId;
    if (messageId == null) return;
    final waitMs =
        (MotionEngine.estimateSeconds(spec.recipe) * 1000).clamp(600, 4000).round();
    await Future<void>.delayed(Duration(milliseconds: waitMs));
    if (!mounted) return;
    try {
      final data = await _sim.capture();
      if (data.isEmpty || !mounted) return;
      final path = await context
          .read<ThumbnailStore>()
          .savePngDataUrl(data, id: spec.id, replacing: spec.thumbnailPath);
      if (path == null || !mounted) return;
      await context.read<ChatProvider>().attachThumbnail(messageId, path);
      if (mounted) setState(() => _draft = _draft?.copyWith(thumbnailPath: path));
    } catch (_) {}
  }

  // ---------------------------------------------------------------- 3단계 동작

  /// Softer — 다시 생성하지 않고 한 단계 낮춘다.
  Future<void> _softer() {
    final draft = _draft;
    if (draft == null) return Future.value();
    final softened = context.read<GenerationProvider>().soften(draft);
    setState(() => _draft = softened);
    return _playDraft();
  }

  Future<void> _tryAgain() async {
    setState(() => _failed = false);
    await _generateDraft();
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;

    final chat = context.read<ChatProvider>();
    final library = context.read<LibraryProvider>();

    final request = await showSaveSheet(
      context,
      spec: draft,
      lastUserText: widget.entry.text,
      // 반응 상황은 1단계 답으로 미리 채운다.
      initialSituation: _when?.situation,
    );
    if (request == null || !mounted) return;

    final outcome = await library.save(
      id: 'saved.${draft.id}',
      name: request.name,
      spec: draft,
      chatId: chat.currentId ?? '',
      situation: request.situation,
    );
    if (!mounted) return;

    switch (outcome) {
      case SaveSucceeded():
        showGrayToast(
          context,
          S.toastSavedToLibrary,
          actionLabel: S.actionView,
          onAction: () => Navigator.pushNamed(context, AppRoutes.library),
        );
        Navigator.popUntil(context, (r) => r.isFirst);
      case SaveRejected(:final reason):
        showGrayToast(
          context,
          reason == SaveRejectReason.nameTaken ? S.errorNameTaken : S.errorNameEmpty,
        );
    }
  }

  // ---------------------------------------------------------------- 마이크

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceProvider>();
    if (voice.isListening) {
      await voice.stop();
      return;
    }
    final ok = await voice.start(
      consumer: VoiceConsumer.questionFlow,
      // 질문형은 받는 즉시 답으로 쓴다 (PRD §9).
      onFinal: _answerByVoice,
    );
    if (!mounted || ok) return;
    if (voice.isPermissionDenied) {
      await showPermissionSheet(context, S.permMicTitle);
    }
  }

  /// 말한 내용과 가장 가까운 선택지를 고른다.
  void _answerByVoice(String text) {
    if (!mounted) return;
    final lower = text.toLowerCase();

    int score(String label) {
      final words = label.toLowerCase().replaceAll('\n', ' ').split(' ');
      return words.where((w) => w.length > 2 && lower.contains(w)).length;
    }

    if (_step == 1) {
      final best = _branch.whenOptions.reduce(
        (a, b) => score(b.label) > score(a.label) ? b : a,
      );
      if (score(best.label) > 0) _chooseWhen(best);
    } else if (_step == 2) {
      final best = _branch.howOptions.reduce(
        (a, b) => score(b.label) > score(a.label) ? b : a,
      );
      if (score(best.label) > 0) _chooseHow(best);
    }
  }

  // ---------------------------------------------------------------- 그리기

  @override
  Widget build(BuildContext context) {
    final gen = context.watch<GenerationProvider>();
    final voice = context.watch<VoiceProvider>();
    final busy = gen.isBusy;

    return AppShell(
      onBack: _back,
      title: fill(S.questionProgress, {'step': _step, 'total': totalSteps}),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Card(
            step: _step,
            draft: _draft,
            exampleLabel: (_when ?? _branch.whenOptions.first).exampleLabel,
            busy: busy,
            failed: _failed,
            onReplay: _replay,
            onRetry: _tryAgain,
            onFullscreen: _draft == null
                ? null
                : () => Navigator.pushNamed(context, AppRoutes.preview,
                    arguments: _draft),
          ),
          const SizedBox(height: 28),
          Text(
            voice.isListening
                ? (voice.text.isEmpty ? S.composerListening : voice.text)
                : _question(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.35,
              fontWeight: FontWeight.w500,
              // 듣는 중에는 질문을 흐리게 하고 자막을 그 자리에 놓는다.
              color: voice.isListening ? Gray.dim : Gray.text,
            ),
          ),
          const SizedBox(height: 24),
          _answers(busy),
          const SizedBox(height: 20),
          Center(
            child: IconButton.filled(
              onPressed: busy ? null : _toggleMic,
              style: IconButton.styleFrom(
                backgroundColor: voice.isListening ? Colors.red.shade600 : Gray.accent,
              ),
              icon: Icon(voice.isListening ? Icons.stop : Icons.mic),
            ),
          ),
        ],
      ),
    );
  }

  String _question() => switch (_step) {
        1 => kStep1Question,
        2 => kStep2Question,
        _ => kStep3Question,
      };

  Widget _answers(bool busy) {
    if (_step == 3) {
      return Column(
        children: [
          FilledButton(
            onPressed: busy || _draft == null ? null : _save,
            child: const Text(S.questionSaveIt),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy || _draft == null ? null : _softer,
                  child: const Text(S.questionSofter),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : _tryAgain,
                  child: const Text(S.actionRetry),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final labels = _step == 1
        ? _branch.whenOptions.map((o) => o.label).toList()
        : _branch.howOptions.map((o) => o.label).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++)
          _CircleAnswer(
            label: labels[i],
            onTap: busy
                ? null
                : () => _step == 1
                    ? _chooseWhen(_branch.whenOptions[i])
                    : _chooseHow(_branch.howOptions[i]),
          ),
      ],
    );
  }
}

/// 원형 답안 버튼. 라벨은 2줄까지.
class _CircleAnswer extends StatelessWidget {
  const _CircleAnswer({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 92,
        height: 92,
        child: Material(
          color: onTap == null ? Gray.line : Gray.card,
          shape: const CircleBorder(side: BorderSide(color: Gray.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.25),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 질문 위의 카드 — 1단계는 예시 모션, 2단계부터는 초안.
class _Card extends StatelessWidget {
  const _Card({
    required this.step,
    required this.draft,
    required this.exampleLabel,
    required this.busy,
    required this.failed,
    required this.onReplay,
    required this.onRetry,
    this.onFullscreen,
  });

  final int step;
  final MotionSpec? draft;
  final String exampleLabel;
  final bool busy;
  final bool failed;
  final VoidCallback onReplay;
  final VoidCallback onRetry;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    if (failed) return FailedBubble(onRetry: onRetry);

    final label = step == 1
        ? '${S.exampleChip} / $exampleLabel'
        : (busy ? null : S.playingOnPurebot);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Gray.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Gray.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: onFullscreen,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF0A0A0D)),
                  const SimSlot(priority: 0),
                  if (label != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(label,
                            style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  if (busy)
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white38),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: busy ? null : onReplay,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text(S.actionPlayAgain),
        ),
      ],
    );
  }
}
