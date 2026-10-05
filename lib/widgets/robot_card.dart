/// 채팅 말풍선 — Figma `Chat Bubble` (`455:4317`).
///
/// 시안이 정의한 변형은 다섯이다:
/// *User Text / Robot Text / User Media / Robot Simulation(채팅 폭 전체) / Robot Typing.*
/// 이 파일에 로봇 쪽 넷(텍스트·시뮬레이션·타이핑·실패)이, 사용자 쪽 둘은
/// `chat_screen.dart` 에 있다.
///
/// 공통 값: radius 24. 흰 말풍선은 좌우 18 / 상하 14, 글자는 `PURE/Body/L`.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/motion_spec.dart';
import '../services/motion_engine.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// 말풍선 공통 라운드. 시안 `rounded-[24px]`.
const double _bubbleRadius = 24;

/// 시뮬레이션 썸네일 바탕. 시안이 토큰이 아닌 값을 쓴다 (`#393939`).
const Color _mediaBackdrop = Color(0xFF393939);

/// 썸네일 위에 까는 어둡게. 시안 `rgba(0,0,0,0.2)`.
const Color _mediaScrim = Color(0x33000000);

/// 06-4 로봇 답장 — 채팅 폭을 꽉 채우는 검은 말풍선 + 아래 동작 칩 두 개.
///
/// 시안 값: 바탕 `neutral/900`, 좌우 20 / 상하 16, 안쪽 영상 311×232(radius 16),
/// 길이 표시는 왼쪽 12 · 아래 12 에 `PURE/Body/L Strong` 흰 글씨.
///
/// 시뮬레이터는 앱에 하나뿐이라 **활성 말풍선 하나만** 실제 3D 를 보여 준다
/// (CLAUDE.md 규칙 14). 나머지는 저장해 둔 썸네일을 깐다.
class RobotCard extends StatelessWidget {
  const RobotCard({
    super.key,
    required this.spec,
    required this.isActive,
    this.playing = false,
    this.onTap,
    this.onPlay,
    this.onSave,
    this.onFullscreen,
    this.saved = false,
  });

  final MotionSpec spec;

  /// 이 말풍선이 시뮬레이터를 차지하는가.
  final bool isActive;

  /// 지금 재생 중인가. 재생 중에는 가운데 재생 삼각형을 치운다.
  final bool playing;

  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onSave;
  final VoidCallback? onFullscreen;

  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 시안에는 없지만 GPT 가 한 줄 설명을 돌려준다 — `Robot Text` 변형으로 얹는다.
        if (spec.reasoning.isNotEmpty) ...[
          RobotTextBubble(text: spec.reasoning),
          const SizedBox(height: AppSpacing.x8),
        ],
        _SimulationBubble(
          spec: spec,
          isActive: isActive,
          playing: playing,
          onTap: isActive ? (onFullscreen ?? onTap) : onTap,
        ),
        // 시안: 말풍선 아래 10, 칩 사이 8.
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionChip(
              icon: AppIconName.playChip,
              label: S.actionPlayOnPurebot,
              inverse: true,
              onTap: onPlay,
            ),
            const SizedBox(width: AppSpacing.x8),
            _ActionChip(
              icon: AppIconName.bookmark,
              label: saved ? S.toastSaved : S.actionSave,
              onTap: onSave,
            ),
          ],
        ),
      ],
    );
  }
}

/// `Chat Bubble / Robot Simulation` — 채팅 폭 전체.
class _SimulationBubble extends StatelessWidget {
  const _SimulationBubble({
    required this.spec,
    required this.isActive,
    required this.playing,
    this.onTap,
  });

  final MotionSpec spec;
  final bool isActive;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x20,
          vertical: AppSpacing.x16,
        ),
        decoration: BoxDecoration(
          color: AppColors.neutral900,
          borderRadius: BorderRadius.circular(_bubbleRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            // 시안 311 × 232.
            aspectRatio: 311 / 232,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: _mediaBackdrop),
                if (isActive)
                  const SimSlot(priority: 0)
                else
                  _Thumbnail(path: spec.thumbnailPath),
                // 실제 3D 가 돌 때는 덮지 않는다 — 시안의 어둡게는 썸네일 위의 것이다.
                if (!isActive) const ColoredBox(color: _mediaScrim),
                if (!playing)
                  const Center(
                    child: AppIcon(
                      AppIconName.playMedia,
                      size: 34,
                      color: AppColors.iconOnInverse,
                    ),
                  ),
                Positioned(
                  left: AppSpacing.x12,
                  bottom: AppSpacing.x12,
                  child: Text(
                    _mmss(MotionEngine.estimateSeconds(spec.recipe)),
                    style: AppTextStyles.bodyLStrong.copyWith(
                      color: AppColors.textOnInverse,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) return const SizedBox.shrink();
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// 시안 `Chip/Play on Purebot` · `Chip/Save` — 좌우 14 · 상하 9 · radius 18 · 간격 6.
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.inverse = false,
  });

  final AppIconName icon;
  final String label;
  final VoidCallback? onTap;

  /// 검은 바탕(= 기본 동작)인가.
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final fg = inverse ? AppColors.textOnInverse : AppColors.textPrimary;
    return Material(
      color: inverse ? AppColors.bgInverse : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelS.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// `Chat Bubble / Robot Text` — 흰 말풍선, 왼쪽 정렬.
class RobotTextBubble extends StatelessWidget {
  const RobotTextBubble({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(_bubbleRadius),
        ),
        child: Text(text, style: AppTextStyles.bodyL),
      );
}

/// 06-3 생성 중 — 시안 `Chat Bubble / Robot Typing` (63 × 35).
///
/// 검은 알약 안에 지름 7 점 세 개가 중심 간격 12 로 놓인다.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key, this.delayed = false});

  /// 20초가 지나 지연 안내를 띄울 때.
  final bool delayed;

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 63,
          height: 35,
          decoration: BoxDecoration(
            color: AppColors.neutral900,
            borderRadius: BorderRadius.circular(17.5),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                // 점 세 개가 순서대로 올라온다.
                final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
                final lift = (t < 0.5 ? t : 1 - t) * 2 * 3;
                return Padding(
                  // 지름 7, 중심 간격 12 → 사이 5.
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Transform.translate(
                    offset: Offset(0, -lift),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.neutral0,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        if (widget.delayed) ...[
          const SizedBox(height: AppSpacing.x8),
          Text(
            S.generatingSlow,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// 06-E1 실패 — 시안 `Msg/Error` (`480:3028`).
///
/// 바탕은 흰색 위에 `rgba(98,22,22,.2)` 를 덮은 값이라 토큰에 없다 — 섞은 결과를
/// 그대로 쓴다. radius 20 · 좌우 16 / 상하 14 · 줄 간격 10.
class FailedBubble extends StatelessWidget {
  const FailedBubble({super.key, required this.onRetry});
  final VoidCallback onRetry;

  /// 흰색 + `rgba(98,22,22,.2)`.
  static const Color _bg = Color(0xFFE0D0D0);

  /// `Chip/Try again` 바탕. 시안 `#f9ecec`.
  static const Color _chipBg = Color(0xFFF9ECEC);

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 246),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  AppIconName.alert,
                  size: 16,
                  color: AppColors.textError,
                ),
                const SizedBox(width: AppSpacing.x8),
                Flexible(
                  child: Text(
                    S.errorGenerateFailed,
                    style: AppTextStyles.labelM.copyWith(
                      color: AppColors.textError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              S.errorGenerateFailedBody,
              style: AppTextStyles.bodyS.copyWith(
                fontSize: 14,
                height: 20 / 14,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: _chipBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRetry,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(12, 7, 14, 7),
                  child: _RetryLabel(),
                ),
              ),
            ),
          ],
        ),
      );
}

class _RetryLabel extends StatelessWidget {
  const _RetryLabel();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIconName.refresh, size: 13),
          const SizedBox(width: 6),
          Text(S.actionRetry, style: AppTextStyles.labelS),
        ],
      );
}

/// 길이 표시. 시안은 `00:03` 꼴로 0을 채운다.
String _mmss(double seconds) {
  final s = seconds.round();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}
