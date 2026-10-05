import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../providers/robot_provider.dart';
import '../data/strings.dart';
import '../widgets/gray_box.dart';

/// 00 스플래시 — 2초 뒤 홈으로 (첫 실행이면 05 시그니처 먼저).
///
/// 이 2초 동안 시뮬레이터가 뒤에서 wasm 을 올린다. 홈에 도착했을 때 이미 준비돼 있게
/// 하려는 것이다 (STEP 25 전시 설정).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _go);
  }

  void _go() {
    if (!mounted) return;
    // 첫 실행이면 05 모션 시그니처를 먼저 보여 준다 (부록 D 결정).
    // "Reset demo data" 가 이 플래그도 지우므로 다음 관람객에게 다시 보여 줄 수 있다.
    final onboarded = context.read<RobotProvider>().onboarded;
    Navigator.pushReplacementNamed(
      context,
      onboarded ? AppRoutes.home : AppRoutes.signature,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Gray.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              S.appName,
              style: TextStyle(fontSize: 40, letterSpacing: 8, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 10),
            Text(
              S.splashTagline,
              style: const TextStyle(fontSize: 12, color: Gray.dim),
            ),
          ],
        ),
      ),
    );
  }
}
