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
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/composer.dart';
import '../widgets/pure_chip.dart';

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
    // await 를 건넌 뒤 context 를 다시 읽지 않도록 필요한 것을 먼저 꺼내 둔다.
    final robot = context.read<RobotProvider>();
    final navigator = Navigator.of(context);

    setState(() => _draft = next);
    await _applyIdle();

    if (_isEdit) {
      // 편집 모드는 고르는 즉시 저장하고 돌아간다 (08-2).
      await robot.updateSignature(_draft);
      if (!mounted) return;
      await _playGreeting();
      if (!mounted) return;
      navigator.pop();
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
  //
  // 시안 05-1~05-4 (`479:2649` 외). 네 단계가 같은 틀을 쓴다:
  // 뒤로 + Skip / 진행 막대 / 로봇 카드(폭 전체, 261, radius 29) / 답 칩 /
  // 질문(Title/L 두 줄) / 큰 마이크 66.
  //
  // **답 칩이 질문 위에 있다.** 시안이 그렇게 그려져 있어 그대로 옮겼다 —
  // 질문이 마이크 바로 위에 오고, 고를 거리는 그 위에 깔린다.

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 9),
            _TopRow(
              onBack: _back,
              onSkip: (!_isEdit && _step != SignatureStep.preview)
                  ? () => _finish(skipped: true)
                  : null,
            ),
            const SizedBox(height: 19),
            // 편집 모드에는 진행 막대가 없다 (시안 05-1.edit_mode). 자리는 비워 둔다.
            SizedBox(
              height: 6.14,
              child: _isEdit ? null : _ProgressBar(step: _step),
            ),
            const SizedBox(height: 63),
            _RobotCard(label: _pillLabel()),
            const Spacer(),
            _chips(),
            const SizedBox(height: AppSpacing.x16),
            Text(
              voice.isListening
                  ? (voice.text.isEmpty ? S.composerListening : voice.text)
                  : _question(),
              textAlign: TextAlign.center,
              style: AppTextStyles.titleL.copyWith(
                height: 38.87 / 30.69,
                color: voice.isListening
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 37),
            _MicButton(listening: voice.isListening, onTap: _toggleMic),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 로봇 카드 왼쪽 위에 뜨는 알약. 재생 중일 때만.
  String? _pillLabel() {
    if (_step == SignatureStep.expression) {
      return fill(S.signaturePlayingSide, {'side': _showingA ? 'A' : 'B'});
    }
    if (_step == SignatureStep.preview) return S.playingOnPurebot;
    if (_step == SignatureStep.relationship && _touring) {
      return kRelationshipOptions[(_tourIndex - 1).clamp(0, 2) % 3].label;
    }
    return null;
  }

  String _question() => switch (_step) {
        SignatureStep.personality => S.signatureStep1,
        SignatureStep.relationship => S.signatureStep2,
        SignatureStep.expression => S.signatureStep3,
        SignatureStep.preview => S.signatureStep4,
      };

  /// 답은 전부 칩이다 (시안 `Suggested answers`).
  Widget _chips() {
    final List<_Answer> answers;
    switch (_step) {
      case SignatureStep.personality:
        final current = personalityFor(_draft);
        answers = [
          for (final o in kPersonalityOptions)
            _Answer(
              label: o.label,
              // 편집 모드에서는 지금 답을 강조한다.
              selected: _isEdit && o.id == current.id,
              onTap: () => _choose(applyPersonality(_draft, o)),
            ),
        ];

      case SignatureStep.relationship:
        answers = [
          for (final o in kRelationshipOptions)
            _Answer(
              label: o.label,
              selected: _isEdit && o.value == _draft.relationship,
              onTap: () => _choose(_draft.copyWith(relationship: o.value)),
            ),
        ];

      case SignatureStep.expression:
        // 시안은 앞의 둘에만 A / B 를 붙인다 — 번갈아 보여 주는 두 안이라서.
        const sides = ['A  ', 'B  ', ''];
        answers = [
          for (final (i, o) in kExpressionOptions.indexed)
            _Answer(
              label: '${sides[i.clamp(0, 2)]}${o.label}',
              selected: _isEdit && o.value == _draft.expression,
              onTap: () => _choose(_draft.copyWith(expression: o.value)),
            ),
        ];

      case SignatureStep.preview:
        answers = [
          _Answer(label: S.signatureLooksGood, onTap: () => _finish()),
          _Answer(label: S.signatureABitSofter, onTap: _softerPreview),
          _Answer(
            label: S.signatureStartOver,
            onTap: () {
              setState(() => _step = SignatureStep.personality);
              _enterStep();
            },
          ),
        ];
    }

    // 시안: 폭 354, 가운데 정렬, 간격 8.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 354),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.x8,
          runSpacing: AppSpacing.x8,
          children: [
            for (final a in answers)
              PureChip(
                label: a.label,
                state: a.selected
                    ? PureChipState.selected
                    : PureChipState.normal,
                onTap: a.onTap,
              ),
          ],
        ),
      ),
    );
  }
}

/// 답 하나.
class _Answer {
  const _Answer({required this.label, required this.onTap, this.selected = false});
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

/// 시안 `479:2653` — 뒤로(30.69 × 41.94) 와 Skip, 좌우 여백 15.34.
class _TopRow extends StatelessWidget {
  const _TopRow({required this.onBack, this.onSkip});

  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.34),
        child: SizedBox(
          height: 41.94,
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 44,
                  height: 41.94,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppIcon(AppIconName.backLarge, size: 30.69),
                  ),
                ),
              ),
              const Spacer(),
              if (onSkip != null)
                GestureDetector(
                  onTap: onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    S.actionSkip,
                    // 시안 15.34 Regular — Body/L 과 거의 같다.
                    style: AppTextStyles.bodyL.copyWith(
                      fontSize: 15.34,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// 시안 `479:2657` — 흰 트랙 349.83 × 6.14(radius 3.07), 채움은 토큰 밖 `#3d414d`.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});
  final SignatureStep step;

  static const Color _fill = Color(0xFF3D414D);

  @override
  Widget build(BuildContext context) {
    final ratio = (step.index + 1) / SignatureStep.values.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23.53),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.07),
        child: Stack(
          children: [
            Container(height: 6.14, color: AppColors.bgSurface),
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(height: 6.14, color: _fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 `Robot` (`479:2659`) — 폭 전체 · 높이 261 · radius 29.19 · 흰 바탕.
/// 시뮬레이터가 이 안에서 돈다.
class _RobotCard extends StatelessWidget {
  const _RobotCard({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(29.19),
        child: SizedBox(
          height: 261,
          width: double.infinity,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.bgSurface)),
              // WebView 는 SimHost 가 그리므로 바깥 ClipRRect 가 먹지 않는다 —
              // 라운드를 자리와 함께 넘긴다.
              const Positioned.fill(
                child: SimSlot(priority: 0, borderRadius: 29.19),
              ),
              if (label != null)
                Positioned(
                  left: AppSpacing.x24,
                  top: AppSpacing.x20,
                  child: _StatusPill(label: label!),
                ),
            ],
          ),
        ),
      );
}

/// 시안 `Pill/Status` (`479:2876`) — `bg/surface-muted`, 왼쪽 14 / 오른쪽 16 /
/// 위아래 9, 간격 8, 세이지 점 8, 글자 `PURE/Label/M`.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 9, AppSpacing.x16, 9),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.bgBrand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            Text(label, style: AppTextStyles.labelM),
          ],
        ),
      );
}

/// 시안 `Button/Mic` (`479:2662`) — 66 검은 원, 아이콘 25.8 × 34.07.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: listening ? AppColors.statusError : AppColors.bgInverse,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 66,
            height: 66,
            child: Center(
              child: listening
                  ? const Icon(Icons.stop, size: 28, color: AppColors.iconOnInverse)
                  : const AppIcon(
                      AppIconName.micLarge,
                      size: 34.07,
                      color: AppColors.iconOnInverse,
                    ),
            ),
          ),
        ),
      );
}
