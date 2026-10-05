import 'dart:io';

import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/motion_spec.dart';
import '../sim/sim_host.dart';
import 'gray_box.dart';

/// 06-4 로봇 답장 카드 — 채팅 폭 4:3.
///
/// 시뮬레이터는 앱에 하나뿐이라 **활성 카드 하나만** 실제 3D 를 보여 준다. 나머지는
/// 저장해 둔 썸네일을 깐다. 카드를 탭하면 그 카드가 활성이 되고, 시뮬레이터가 옮겨 온다.
class RobotCard extends StatelessWidget {
  const RobotCard({
    super.key,
    required this.spec,
    required this.isActive,
    this.onTap,
    this.onPlay,
    this.onSave,
    this.onFullscreen,
    this.statusLabel,
    this.saved = false,
  });

  final MotionSpec spec;

  /// 이 카드가 시뮬레이터를 차지하는가.
  final bool isActive;

  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onSave;
  final VoidCallback? onFullscreen;

  /// "Playing on Purebot…" 같은 상태 칩.
  final String? statusLabel;

  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Gray.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Gray.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: isActive ? onFullscreen : onTap,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF0A0A0D)),
                  if (isActive)
                    const SimSlot(priority: 0)
                  else
                    _Thumbnail(path: spec.thumbnailPath),
                  if (statusLabel != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _StatusChip(label: statusLabel!),
                    ),
                  if (!isActive)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: Icon(Icons.touch_app_outlined,
                          size: 16, color: Colors.white38),
                    ),
                ],
              ),
            ),
          ),
          if (spec.reasoning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                spec.reasoning,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text(S.actionPlayOnPurebot),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.check : Icons.bookmark_border, size: 18),
                    label: Text(saved ? S.toastSaved : S.actionSave),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    if (p == null || p.isEmpty) {
      return const Center(
        child: Icon(Icons.smart_toy_outlined, color: Colors.white24, size: 36),
      );
    }
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.smart_toy_outlined, color: Colors.white24, size: 36),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      );
}

/// 06-3 생성 중 — 점 3개.
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Gray.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Gray.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // 점 세 개가 순서대로 올라온다.
                  final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
                  final lift = (t < 0.5 ? t : 1 - t) * 2 * 4;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.translate(
                      offset: Offset(0, -lift),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Gray.dim,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (widget.delayed) ...[
              const SizedBox(height: 8),
              const Text(
                S.generatingSlow,
                style: TextStyle(fontSize: 12, color: Gray.dim),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 06-E1 실패 말풍선.
class FailedBubble extends StatelessWidget {
  const FailedBubble({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          decoration: BoxDecoration(
            color: Gray.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Gray.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(S.errorGenerateFailed,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(S.errorGenerateFailedBody,
                  style: TextStyle(fontSize: 12, color: Gray.dim)),
              TextButton(onPressed: onRetry, child: const Text(S.actionRetry)),
            ],
          ),
        ),
      );
}
