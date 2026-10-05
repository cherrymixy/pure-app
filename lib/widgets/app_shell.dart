import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/signature_options.dart';
import '../data/strings.dart';
import '../providers/notification_provider.dart';
import '../providers/robot_provider.dart';
import 'gray_box.dart';
import 'pure_sidebar.dart';

/// 모든 화면이 쓰는 셸 — 좌상단 햄버거 / 상단 로봇 상태 / 우상단 알림 (PRD §4 공통).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.showRobotStatus = true,
    this.actions = const [],
    this.onBack,
    this.floating,
  });

  final Widget child;

  /// 제목이 있으면 로봇 상태 대신 제목을 보여 준다.
  final String? title;

  final bool showRobotStatus;
  final List<Widget> actions;

  /// 뒤로가기를 쓰는 화면은 햄버거 대신 화살표.
  final VoidCallback? onBack;

  /// 입력창처럼 바닥에 붙는 것.
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Gray.bg,
      drawer: onBack == null ? const PureSidebar() : null,
      appBar: AppBar(
        backgroundColor: Gray.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: title != null
            ? Text(title!, style: const TextStyle(fontSize: 17))
            : (showRobotStatus ? const _RobotStatus() : null),
        titleSpacing: 0,
        actions: [
          ...actions,
          if (onBack == null) const _NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
      body: child,
      bottomNavigationBar: floating,
    );
  }
}

/// 상단 로봇 상태 — "Purebot · PUREBOT / LIVELY, BOUNCY".
///
/// 이름을 5번 탭하면 데모 모드가 토글된다 (PRD §6-7 숨은 토글).
class _RobotStatus extends StatefulWidget {
  const _RobotStatus();

  @override
  State<_RobotStatus> createState() => _RobotStatusState();
}

class _RobotStatusState extends State<_RobotStatus> {
  int _taps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    // 간격이 뜨면 처음부터. 실수로 쌓이는 걸 막는다.
    _taps = now.difference(_lastTap) > const Duration(seconds: 2) ? 1 : _taps + 1;
    _lastTap = now;
    if (_taps < 5) return;
    _taps = 0;
    _toggleDemo();
  }

  Future<void> _toggleDemo() async {
    // 데모 토글은 생성 Provider 가 들고 있다. 셸이 직접 알 필요는 없어서 콜백으로 찾는다.
    final toggle = DemoModeToggle.of(context);
    if (toggle == null) return;
    final on = await toggle();
    if (!mounted) return;
    showGrayToast(context, on ? S.homeDemoModeOn : S.homeDemoModeOff);
  }

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(robot.robot.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(
            '${robot.robot.name.toUpperCase()} / ${signatureSummary(robot.signature)}',
            style: const TextStyle(fontSize: 10, color: Gray.dim, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

/// 데모 토글을 셸까지 내려 보내는 통로. main 에서 꽂는다.
class DemoModeToggle extends InheritedWidget {
  const DemoModeToggle({super.key, required this.toggle, required super.child});

  final Future<bool> Function() toggle;

  static Future<bool> Function()? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoModeToggle>()?.toggle;

  @override
  bool updateShouldNotify(DemoModeToggle oldWidget) => false;
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().hasUnread;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        ),
        if (unread)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Gray.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
