import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/signature_options.dart';
import '../data/strings.dart';
import '../models/motion_signature.dart';
import '../models/recipe.dart';
import '../providers/robot_provider.dart';
import '../providers/voice_provider.dart';
import '../services/motion_engine.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../widgets/app_shell.dart';
import '../widgets/composer.dart';
import '../widgets/gray_box.dart';

/// 05 의 네 단계.
enum SignatureStep { personality, relationship, expression, preview }

/// 화면에 넘기는 인자.
class SignatureArgs {
  const SignatureArgs({this.edit = false, this.focus});

  /// 08-2 에서 항목을 탭해 들어온 편집 모드.
  /// 진행 바·Skip 을 숨기고, 고르는 즉시 저장하고 돌아간다.
  final bool edit;

  /// 편집 모드에서 어느 항목을 고치러 왔는지.
  final SignatureStep? focus;
}

/// 05 모션 시그니처 — 성격 · 관계 방식 · 움직임 표현 · 미리보기.
///
/// **답을 고르면 대기 모션이 바로 바뀐다** (PRD §2). 설명을 읽는 게 아니라
/// 눈으로 보고 고르는 화면이다.
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key, this.args = const SignatureArgs()});

  final SignatureArgs args;

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  late SignatureStep _step;

  /// 초안. 화면이 첫 프레임을 그릴 때 이미 값이 있어야 한다 —
  /// Provider 를 initState 에서 읽을 수 없어 시드로 시작하고 곧바로 덮어쓴다.
  MotionSignature _draft = MotionSignature.seed;

  /// 05-3 은 A/B 를 번갈아 재생한다. 지금 어느 쪽인지.
  bool _showingA = true;
  Timer? _abTimer;

  /// 05-2 는 세 방식 인사를 순서대로 짧게 보여 준다.
  Timer? _tourTimer;
  int _tourIndex = 0;
  bool _touring = false;

  SimController get _sim => SimHost.controllerOf(context);
  bool get _isEdit => widget.args.edit;

  @override
  void initState() {
    super.initState();
    _step = widget.args.focus ?? SignatureStep.personality;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _draft = context.read<RobotProvider>().signature);
      _enterStep();
    });
  }

  @override
  void dispose() {
    _abTimer?.cancel();
    _tourTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- 재생

  /// 지금 초안대로 대기 모션을 바꾼다. 고르는 순간 눈에 보여야 한다.
  Future<void> _applyIdle() async {
    final params = MotionEngine.signatureToParams(_draft);
    try {
      await _sim.setIdle(
        behavior: params.idleBehavior,
        speed: params.speed,
        amplitude: params.amplitude,
      );
    } catch (_) {}
  }

  /// 시그니처가 반영된 인사. 관계 방식에 따라 앞에 동작이 하나 붙는다 (PRD §6-9).
  Future<void> _playGreeting() async {
    final params = MotionEngine.signatureToParams(_draft);
    final recipe = MotionEngine.applySignature(
      Recipe(steps: [
        if (params.greetPrefix != null) RecipeStep(behavior: params.greetPrefix!),
        const RecipeStep(behavior: 'greet'),
      ]),
      params,
    );
    try {
      await _sim.playRecipe(recipe.toJson());
      await _sim.setFace('smile');
    } catch (_) {}
  }

  void _enterStep() {
    _abTimer?.cancel();
    _tourTimer?.cancel();
    _touring = false;

    switch (_step) {
      case SignatureStep.personality:
        _applyIdle();
      case SignatureStep.relationship:
        _startRelationshipTour();
      case SignatureStep.expression:
        _startAbLoop();
      case SignatureStep.preview:
        _playGreeting();
    }
  }

  /// 05-2 — 세 방식의 인사를 순서대로 짧게 보여 준다.
  void _startRelationshipTour() {
    _touring = true;
    _tourIndex = 0;
    void playNext() {
      if (!mounted || !_touring) return;
      final option = kRelationshipOptions[_tourIndex % kRelationshipOptions.length];
      final params = MotionEngine.signatureToParams(_draft);
      unawaited(_sim
          .playBehavior(option.greetBehavior,
              speed: params.speed, amplitude: params.amplitude)
          .catchError((_) => ''));
      setState(() => _tourIndex++);
    }

    playNext();
    _tourTimer = Timer.periodic(const Duration(seconds: 3), (_) => playNext());
  }

  /// 05-3 — A 와 B 를 번갈아 재생해 차이를 보여 준다.
  void _startAbLoop() {
    void playCurrent() {
      if (!mounted) return;
      final expression = _showingA ? kExpressionA : kExpressionB;
      final params =
          MotionEngine.signatureToParams(_draft.copyWith(expression: expression));
      unawaited(_sim
          .playBehavior('greet', speed: params.speed, amplitude: params.amplitude)
          .catchError((_) => ''));
    }

    playCurrent();
    _abTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _showingA = !_showingA);
      playCurrent();
    });
  }

  // ---------------------------------------------------------------- 선택

  Future<void> _choose(MotionSignature next) async {
    setState(() => _draft = next);
    await _applyIdle();

    if (_isEdit) {
      // 편집 모드는 고르는 즉시 저장하고 돌아간다 (08-2).
      await context.read<RobotProvider>().updateSignature(_draft);
      if (!mounted) return;
      await _playGreeting();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    _advance();
  }

  void _advance() {
    final next = switch (_step) {
      SignatureStep.personality => SignatureStep.relationship,
      SignatureStep.relationship => SignatureStep.expression,
      SignatureStep.expression => SignatureStep.preview,
      SignatureStep.preview => SignatureStep.preview,
    };
    setState(() => _step = next);
    _enterStep();
  }

  void _back() {
    if (_isEdit || _step == SignatureStep.personality) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _step = switch (_step) {
        SignatureStep.preview => SignatureStep.expression,
        SignatureStep.expression => SignatureStep.relationship,
        _ => SignatureStep.personality,
      };
    });
    _enterStep();
  }

  Future<void> _finish({bool skipped = false}) async {
    final robot = context.read<RobotProvider>();
    await robot.updateSignature(skipped ? MotionSignature.seed : _draft);
    await robot.markOnboarded();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  /// 05-4 "A bit softer" — 한 단계 부드럽게 재생해 본다.
  ///
  /// 시그니처 자체를 바꾸지는 않는다. 어떤 느낌인지 보여 주기만 한다.
  Future<void> _softerPreview() async {
    final params = MotionEngine.signatureToParams(_draft);
    final greeting = MotionEngine.applySignature(
      const Recipe(steps: [RecipeStep(behavior: 'greet')]),
      params,
    );
    try {
      await _sim.playRecipe(MotionEngine.applySoftener(greeting).toJson());
      await _sim.setFace('smile');
    } catch (_) {}
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
      onFinal: _answerByVoice,
    );
    if (!mounted || ok) return;
    if (voice.isPermissionDenied) {
      await showPermissionSheet(context, S.permMicTitle);
    }
  }

  /// 말한 내용과 가장 가까운 답안을 고른다. 안 맞으면 아무것도 안 고른다.
  void _answerByVoice(String text) {
    if (!mounted) return;
    final lower = text.toLowerCase();
    int score(String label) => label
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.length > 2 && lower.contains(w))
        .length;

    switch (_step) {
      case SignatureStep.personality:
        final best = kPersonalityOptions
            .reduce((a, b) => score(b.label) > score(a.label) ? b : a);
        if (score(best.label) > 0) _choose(applyPersonality(_draft, best));
      case SignatureStep.relationship:
        final best = kRelationshipOptions
            .reduce((a, b) => score(b.label) > score(a.label) ? b : a);
        if (score(best.label) > 0) {
          _choose(_draft.copyWith(relationship: best.value));
        }
      case SignatureStep.expression:
        final best = kExpressionOptions
            .reduce((a, b) => score(b.label) > score(a.label) ? b : a);
        if (score(best.label) > 0) _choose(_draft.copyWith(expression: best.value));
      case SignatureStep.preview:
        break;
    }
  }

  // ---------------------------------------------------------------- 그리기

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceProvider>();

    return AppShell(
      onBack: _back,
      title: _isEdit ? S.signatureTitle : null,
      showRobotStatus: false,
      actions: [
        if (!_isEdit && _step != SignatureStep.preview)
          TextButton(
            onPressed: () => _finish(skipped: true),
            child: const Text(S.actionSkip),
          ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!_isEdit) _ProgressBar(step: _step),
          const SizedBox(height: 12),
          _card(),
          const SizedBox(height: 24),
          Text(
            voice.isListening
                ? (voice.text.isEmpty ? S.composerListening : voice.text)
                : _question(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: voice.isListening ? Gray.dim : Gray.text,
            ),
          ),
          const SizedBox(height: 20),
          _options(),
          if (_step != SignatureStep.preview) ...[
            const SizedBox(height: 20),
            Center(
              child: IconButton.filled(
                onPressed: _toggleMic,
                style: IconButton.styleFrom(
                  backgroundColor:
                      voice.isListening ? Colors.red.shade600 : Gray.accent,
                ),
                icon: Icon(voice.isListening ? Icons.stop : Icons.mic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card() {
    String? label;
    if (_step == SignatureStep.expression) {
      label = 'Playing ${_showingA ? 'A' : 'B'} on Purebot…';
    } else if (_step == SignatureStep.relationship && _touring) {
      final o = kRelationshipOptions[(_tourIndex - 1).clamp(0, 2) % 3];
      label = o.label;
    }

    return Container(
      decoration: BoxDecoration(
        color: Gray.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Gray.line),
      ),
      clipBehavior: Clip.antiAlias,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(label,
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _question() => switch (_step) {
        SignatureStep.personality => S.signatureStep1,
        SignatureStep.relationship => S.signatureStep2,
        SignatureStep.expression => S.signatureStep3,
        SignatureStep.preview => S.signatureStep4,
      };

  Widget _options() {
    switch (_step) {
      case SignatureStep.personality:
        final current = personalityFor(_draft);
        return Column(
          children: [
            for (final o in kPersonalityOptions)
              _OptionRow(
                title: o.label,
                subtitle: o.description,
                // 편집 모드에서는 지금 답을 강조한다.
                selected: _isEdit && o.id == current.id,
                onTap: () => _choose(applyPersonality(_draft, o)),
              ),
          ],
        );

      case SignatureStep.relationship:
        return Column(
          children: [
            for (final o in kRelationshipOptions)
              _OptionRow(
                title: o.label,
                subtitle: o.description,
                selected: _isEdit && o.value == _draft.relationship,
                onTap: () => _choose(_draft.copyWith(relationship: o.value)),
              ),
          ],
        );

      case SignatureStep.expression:
        return Column(
          children: [
            for (final o in kExpressionOptions)
              _OptionRow(
                title: o.label,
                subtitle: o.description,
                selected: _isEdit && o.value == _draft.expression,
                onTap: () => _choose(_draft.copyWith(expression: o.value)),
              ),
          ],
        );

      case SignatureStep.preview:
        return Column(
          children: [
            Text(
              signatureSummary(_draft),
              style: const TextStyle(fontSize: 13, color: Gray.dim, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _finish(),
              child: const Text(S.signatureLooksGood),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _softerPreview,
                    child: const Text(S.signatureABitSofter),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _step = SignatureStep.personality);
                      _enterStep();
                    },
                    child: const Text(S.signatureStartOver),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});
  final SignatureStep step;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final s in SignatureStep.values)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: s.index <= step.index ? Gray.accent : Gray.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Gray.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Gray.accent : Gray.line, width: selected ? 2 : 1),
        ),
        child: ListTile(
          title: Text(title, style: const TextStyle(fontSize: 15)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: selected ? const Icon(Icons.check, color: Gray.accent) : null,
          onTap: onTap,
        ),
      );
}
