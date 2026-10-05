import 'package:flutter/material.dart';

import 'sim_controller.dart';
import 'sim_view.dart';

/// 앱 전체에서 **하나뿐인** 시뮬레이터를 들고 있는 호스트.
///
/// 10MB wasm 을 컴파일하는 비용 때문에 화면마다 WebView 를 만들 수 없다
/// (CLAUDE.md 규칙 14). 대신 WebView 를 앱 최상단 Stack 에 한 번만 띄워 두고,
/// 보여 줄 화면이 [SimSlot] 으로 "여기에 그려 달라"고 자리를 알려 주면 그 자리로 옮긴다.
///
/// 아무도 자리를 요청하지 않으면 화면 밖으로 치운다 — 없애지 않는다. 없애면 다음에
/// 다시 10MB 를 컴파일해야 한다.
class SimHost extends StatefulWidget {
  const SimHost({super.key, required this.child});

  final Widget child;

  static SimHostState of(BuildContext context) {
    final state = context.findAncestorStateOfType<SimHostState>();
    assert(state != null, 'SimHost 가 위젯 트리에 없습니다');
    return state!;
  }

  /// 시뮬레이터 컨트롤러. 어디서든 꺼내 쓴다.
  static SimController controllerOf(BuildContext context) => of(context).controller;

  @override
  State<SimHost> createState() => SimHostState();
}

/// 자리 요청 하나.
class _SlotRequest {
  _SlotRequest(this.key, this.priority, this.radius);

  final GlobalKey key;

  /// 같은 시점에 여러 화면이 요청하면 큰 쪽이 이긴다 (전체 화면 > 카드).
  final int priority;

  final double radius;
}

class SimHostState extends State<SimHost> {
  final SimController controller = SimController();
  final List<_SlotRequest> _requests = [];

  Rect? _rect;
  double _radius = 0;
  bool _updateScheduled = false;

  /// 지금 시뮬레이터가 화면에 보이는가.
  bool get isVisible => _rect != null;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// [SimSlot] 이 자리를 요청하거나 갱신한다.
  void putSlot(GlobalKey key, int priority, double radius) {
    final i = _requests.indexWhere((r) => r.key == key);
    if (i >= 0) {
      final existing = _requests[i];
      if (existing.priority == priority && existing.radius == radius) {
        _scheduleUpdate();
        return;
      }
      _requests[i] = _SlotRequest(key, priority, radius);
    } else {
      _requests.add(_SlotRequest(key, priority, radius));
    }
    _scheduleUpdate();
  }

  /// [SimSlot] 이 사라진다.
  void releaseSlot(GlobalKey key) {
    _requests.removeWhere((r) => r.key == key);
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _applyWinner();
    });
  }

  void _applyWinner() {
    if (_requests.isEmpty) {
      if (_rect != null) setState(() => _rect = null);
      return;
    }

    _requests.sort((a, b) => b.priority.compareTo(a.priority));
    final winner = _requests.first;

    final box = winner.key.currentContext?.findRenderObject() as RenderBox?;
    final hostBox = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || hostBox == null) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: hostBox);
    final next = origin & box.size;

    if (next != _rect || winner.radius != _radius) {
      setState(() {
        _rect = next;
        _radius = winner.radius;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 자리가 없으면 화면 밖으로. 살아는 있어야 wasm 을 다시 안 올린다.
    final rect = _rect ?? const Rect.fromLTWH(-10000, 0, 320, 240);

    return Stack(
      children: [
        widget.child,
        Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            // 자리를 차지하지 않을 때는 터치를 먹지 않게.
            ignoring: _rect == null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: SimView(controller: controller),
            ),
          ),
        ),
      ],
    );
  }
}

/// 시뮬레이터를 "여기에" 그려 달라고 요청하는 자리.
///
/// 레이아웃상으로는 빈 상자다. 실제 WebView 는 [SimHost] 가 이 상자 위로 옮겨 온다.
class SimSlot extends StatefulWidget {
  const SimSlot({
    super.key,
    this.priority = 0,
    this.borderRadius = 0,
    this.placeholder,
  });

  /// 여러 자리가 동시에 있으면 큰 쪽이 이긴다. 전체 화면 10, 카드 0.
  final int priority;

  final double borderRadius;

  /// 시뮬레이터가 아직 이 자리에 없을 때 대신 보여 줄 것.
  final Widget? placeholder;

  @override
  State<SimSlot> createState() => _SimSlotState();
}

class _SimSlotState extends State<SimSlot> {
  final _key = GlobalKey();
  SimHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _host ??= context.findAncestorStateOfType<SimHostState>();
    _register();
  }

  @override
  void didUpdateWidget(SimSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priority != widget.priority ||
        oldWidget.borderRadius != widget.borderRadius) {
      _register();
    }
  }

  void _register() => _host?.putSlot(_key, widget.priority, widget.borderRadius);

  @override
  void dispose() {
    _host?.releaseSlot(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 크기·위치가 바뀌면 호스트에 다시 알린다 (회전·키보드·스크롤).
    return LayoutBuilder(
      builder: (context, _) {
        _register();
        return SizedBox.expand(key: _key, child: widget.placeholder);
      },
    );
  }
}
