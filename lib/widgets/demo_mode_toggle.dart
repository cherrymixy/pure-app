import 'package:flutter/material.dart';

/// 데모 모드 토글을 화면 어디서나 집을 수 있게 내려 보내는 통로. main 에서 꽂는다.
///
/// PRD §6-7 의 숨은 토글 — 사이드바에서 로봇 이름을 5번 두드리면 불린다.
class DemoModeToggle extends InheritedWidget {
  const DemoModeToggle({super.key, required this.toggle, required super.child});

  /// 토글한 뒤의 상태(켜졌는가)를 돌려준다.
  final Future<bool> Function() toggle;

  static Future<bool> Function()? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DemoModeToggle>()?.toggle;

  @override
  bool updateShouldNotify(DemoModeToggle oldWidget) => false;
}
