import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// 처음 붙을 때 한 번만 떠오른다 — 흐림에서 또렷해지며 [AppMotion.riseFrom] 만큼
/// 올라온다.
///
/// 채팅은 목록이 다시 그려질 때마다 모든 말풍선이 itemBuilder 를 거친다. 그래서
/// **반드시 메시지 id 를 key 로** 줘야 한다 — 그래야 Flutter 가 기존 말풍선의
/// 상태를 그대로 두고 새로 들어온 것만 움직인다. key 없이 쓰면 새 말풍선이
/// 올라올 때마다 화면 전체가 깜빡인다.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child});

  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: AppMotion.easeIn,
  );

  @override
  void initState() {
    super.initState();
    // 첫 프레임을 그린 뒤에 시작한다 — 레이아웃이 잡히기 전에 움직이면 튄다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _t.value) * AppMotion.riseFrom),
            child: child,
          ),
        ),
      );
}
