import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'sim_controller.dart';
import 'sim_view.dart';

/// 앱 전체에서 **하나뿐인** 시뮬레이터를 들고 있는 호스트.
///
/// 10MB wasm 을 컴파일하는 비용 때문에 화면마다 WebView 를 만들 수 없다
/// (docs/conventions.md 규칙 14). 대신 WebView 를 앱 최상단 Stack 에 한 번만 띄워 두고,
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
  _SlotRequest(
    this.key,
    this.priority,
    this.radius,
    this.viewport,
    this.route,
    this.scaffold,
  );

  final GlobalKey key;

  /// 같은 시점에 여러 화면이 요청하면 큰 쪽이 이긴다 (전체 화면 > 카드).
  final int priority;

  final double radius;

  /// 이 자리가 스크롤 안에 있으면 그 스크롤 영역. 밖으로 나간 부분은 잘라 낸다.
  final BuildContext? viewport;

  /// 이 자리가 올라탄 라우트. 위에 시트나 다이얼로그가 덮이면 자리를 비운다 —
  /// WebView 는 앱 최상단에 있어서 가만 두면 시트 **위에** 그려진다.
  final ModalRoute<Object?>? route;

  /// 이 자리가 올라탄 Scaffold. 사이드바는 라우트를 쌓지 않아서 따로 본다.
  final ScaffoldState? scaffold;
}

class SimHostState extends State<SimHost> with SingleTickerProviderStateMixin {
  final SimController controller = SimController();
  final List<_SlotRequest> _requests = [];

  Rect? _rect;
  Rect? _clip;
  double _radius = 0;
  bool _updateScheduled = false;

  /// 자리를 매 프레임 다시 잰다.
  ///
  /// [SimSlot] 의 `LayoutBuilder` 는 **크기**가 바뀔 때만 다시 불린다. 채팅처럼
  /// 스크롤로 **위치만** 움직이는 경우에는 안 불려서 WebView 가 옛 자리에 남는다.
  /// 그래서 프레임마다 재 보고, 값이 달라졌을 때만 옮긴다.
  late final Ticker _ticker = createTicker(_onFrame)..start();

  /// 지금 시뮬레이터가 화면에 보이는가.
  bool get isVisible => _rect != null;

  @override
  void initState() {
    super.initState();
    _ticker; // late final 을 깨워 티커를 시작시킨다.
  }

  @override
  void dispose() {
    _ticker.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onFrame(Duration _) {
    if (_requests.isEmpty) return;
    _applyWinner();
  }

  /// [SimSlot] 이 자리를 요청하거나 갱신한다.
  void putSlot(
    GlobalKey key,
    int priority,
    double radius,
    BuildContext? viewport,
    ModalRoute<Object?>? route,
    ScaffoldState? scaffold,
  ) {
    final i = _requests.indexWhere((r) => r.key == key);
    if (i >= 0) {
      final existing = _requests[i];
      if (existing.priority == priority &&
          existing.radius == radius &&
          existing.viewport == viewport &&
          existing.route == route &&
          existing.scaffold == scaffold) {
        _scheduleUpdate();
        return;
      }
      _requests[i] = _SlotRequest(key, priority, radius, viewport, route, scaffold);
    } else {
      _requests.add(_SlotRequest(key, priority, radius, viewport, route, scaffold));
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
    // 시트·다이얼로그·사이드바가 덮은 자리는 셈에서 뺀다 — 가만 두면 WebView 가
    // 그 위에 그려진다.
    final live = _requests
        .where((r) => (r.route?.isCurrent ?? true) && !(r.scaffold?.isDrawerOpen ?? false))
        .toList();

    if (live.isEmpty) {
      if (_rect != null) {
        setState(() {
          _rect = null;
          _clip = null;
        });
      }
      return;
    }

    live.sort((a, b) => b.priority.compareTo(a.priority));
    final winner = live.first;

    final box = winner.key.currentContext?.findRenderObject() as RenderBox?;
    final hostBox = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    if (hostBox == null || !hostBox.hasSize) return;

    final origin = box.localToGlobal(Offset.zero, ancestor: hostBox);
    final next = origin & box.size;

    // 스크롤 안의 자리면 그 영역 밖으로 나간 부분은 보이지 않아야 한다.
    Rect? clip;
    final viewportBox = winner.viewport?.findRenderObject();
    if (viewportBox is RenderBox && viewportBox.hasSize && viewportBox.attached) {
      clip = viewportBox.localToGlobal(Offset.zero, ancestor: hostBox) &
          viewportBox.size;
    }

    if (next != _rect || clip != _clip || winner.radius != _radius) {
      setState(() {
        _rect = next;
        _clip = clip;
        _radius = winner.radius;
      });
    }
  }

  /// 자리가 없을 때 치워 두는 곳. 없애지 않는다 — 없애면 wasm 을 다시 올려야 한다.
  static const Rect _offscreen = Rect.fromLTWH(-10000, 0, 320, 240);

  @override
  Widget build(BuildContext context) {
    final rect = _rect ?? _offscreen;

    // 보이는 창 = 자리 ∩ 스크롤 영역. 창은 잘라 내는 틀이고, WebView 자체는
    // 늘 자리 크기 그대로라 스크롤 중에 리사이즈되지 않는다.
    var view = rect;
    var window = _clip == null ? rect : rect.intersect(_clip!);
    if (window.width <= 0 || window.height <= 0) {
      window = _offscreen;
      view = _offscreen;
    }

    return Stack(
      children: [
        widget.child,
        Positioned.fromRect(
          rect: window,
          child: ClipRect(
            child: IgnorePointer(
              // 자리를 차지하지 않을 때는 터치를 먹지 않게.
              ignoring: _rect == null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: view.left - window.left,
                    top: view.top - window.top,
                    width: view.width,
                    height: view.height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_radius),
                      child: SimView(controller: controller),
                    ),
                  ),
                ],
              ),
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

  void _register() => _host?.putSlot(
        _key,
        widget.priority,
        widget.borderRadius,
        // 스크롤 안이면 그 뷰포트를 함께 넘긴다 — 밖으로 나간 부분을 잘라 내려고.
        Scrollable.maybeOf(context)?.context,
        ModalRoute.of(context),
        Scaffold.maybeOf(context),
      );

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
