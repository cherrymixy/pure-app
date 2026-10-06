import 'dart:async';

import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/motion_spec.dart';
import '../services/motion_engine.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';

/// 전체 화면 미리보기 — Figma `06-4.full_screen_preview` (`480:3782`).
///
/// 시안 값: 배경 `bg/canvas` · 닫기 24(왼쪽 20 · 위 64) · Loop 알약(세이지 21%) ·
/// 미리보기 354 정사각(radius 19.67) · 스크러버 4 · 아래 흰 버튼 56.
///
/// 시뮬레이터 인스턴스는 하나뿐이라 새로 만들지 않는다. [SimSlot] 의 priority 를
/// 카드(0)보다 높게(10) 둬서, 이 화면이 떠 있는 동안 시뮬레이터가 여기로 옮겨 온다.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.spec});

  final MotionSpec spec;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _loop = true;
  bool _playing = true;

  /// 재생 위치 — 시뮬레이터가 알려 주지 않아서 길이를 기준으로 센다.
  double _elapsed = 0;
  Timer? _tick;

  StreamSubscription<SimEvent>? _sub;

  SimController get _sim => SimHost.controllerOf(context);

  double get _total => MotionEngine.estimateSeconds(widget.spec.recipe);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _sub = _sim.events.listen((e) {
        if (e is SimEnded && mounted) {
          if (_loop) {
            _play();
          } else {
            _stopTick();
            setState(() => _playing = false);
          }
        }
      });
      // 드래그로 돌려 볼 수 있게.
      await _sim.enableOrbit(true);
      await _play();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    // 돌아가면 카드에서는 회전이 꺼져 있어야 한다.
    unawaited(_sim.enableOrbit(false));
    super.dispose();
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _play() async {
    if (!mounted) return;
    setState(() {
      _playing = true;
      _elapsed = 0;
    });
    _stopTick();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsed = (_elapsed + 0.1).clamp(0, _total));
    });

    try {
      await _sim.playRecipe(widget.spec.recipe.toJson());
      await _sim.setFace(widget.spec.face);
    } catch (_) {
      _stopTick();
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _sim.stop();
      _stopTick();
      if (mounted) setState(() => _playing = false);
    } else {
      await _play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: GestureDetector(
        // 아래로 쓸면 닫는다.
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 시안: 닫기 왼쪽 20, Loop 오른쪽 여백 ~24.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x20,
                  14,
                  AppSpacing.x24,
                  0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppIcon(AppIconName.closeLarge, size: 24),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _LoopPill(
                      on: _loop,
                      onTap: () => setState(() => _loop = !_loop),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              // 시안: 354 정사각, radius 19.67.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19.67),
                    child: const Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: AppColors.bgSurface),
                        SimSlot(priority: 10, borderRadius: 19.67),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              _Scrubber(elapsed: _elapsed, total: _total),
              const SizedBox(height: AppSpacing.x24),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  0,
                  AppSpacing.x24,
                  18,
                ),
                child: _PlayButton(playing: _playing, onTap: _toggle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시안 `Loop` (`483:19499`) — 세이지 21% 바탕, 왼쪽 10 / 오른쪽 12 / 위아래 6.
class _LoopPill extends StatelessWidget {
  const _LoopPill({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on
            ? AppColors.bgBrand.withValues(alpha: 0.21)
            : AppColors.bgSurfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, AppSpacing.x12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  AppIconName.repeat,
                  size: 14,
                  color: on ? AppColors.iconPrimary : AppColors.iconSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  S.previewLoop,
                  style: AppTextStyles.labelS.copyWith(
                    color: on ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 시안 `Scrubber` (`480:3797`) — 높이 4, radius 2, 트랙 흰색 25%.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.elapsed, required this.total});

  final double elapsed;
  final double total;

  static String _mmss(double s) {
    final v = s.round();
    return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (elapsed / total).clamp(0.0, 1.0);
    final small = AppTextStyles.caption.copyWith(fontSize: 12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const ColoredBox(color: Color(0x40FFFFFF)),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: const ColoredBox(color: AppColors.bgSurface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_mmss(elapsed), style: small),
              Text(_mmss(total), style: small),
            ],
          ),
        ],
      ),
    );
  }
}

/// 시안 `Button/Play on Purebot` (`480:3801`) — 흰 버튼 56, radius 28, 간격 8.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                playing
                    ? const Icon(Icons.stop, size: 16)
                    : const AppIcon(AppIconName.playChip, size: 16),
                const SizedBox(width: AppSpacing.x8),
                Text(
                  playing ? S.actionStop : S.actionPlayOnPurebot,
                  style: AppTextStyles.bodyLStrong,
                ),
              ],
            ),
          ),
        ),
      );
}
