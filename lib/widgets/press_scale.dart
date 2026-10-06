import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 누르는 동안 살짝 작아진다.
///
/// 흰 알약이 글로우 위에 떠 있는 화면이라 잉크 번짐만으로는 눌린 게 잘 안 보인다.
/// 크기로 알려 주는 쪽이 이 화면과 맞는다.
///
/// 탭 처리는 하지 않는다 — 안쪽 [InkWell] 이 그대로 받는다. 여기서는 손가락이
/// 닿아 있는지만 본다.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled || v == _down) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        // 안쪽 InkWell 이 제스처를 가져가도 포인터는 여기까지 온다.
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: AppMotion.maybe(context, AppMotion.quick),
          curve: AppMotion.easeIn,
          child: widget.child,
        ),
      );
}
