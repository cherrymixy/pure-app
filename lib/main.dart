import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/env.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 전시 중 화면이 꺼지지 않게.
  WakelockPlus.enable();
  runApp(const PureApp());
}

class PureApp extends StatelessWidget {
  const PureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PURE',
      debugShowCheckedModeBanner: false,
      home: const _ScaffoldPlaceholder(),
    );
  }
}

/// STEP 1 스캐폴드 확인용. STEP 10 에서 실제 화면으로 교체된다.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PURE',
              style: TextStyle(fontSize: 48, letterSpacing: 8),
            ),
            const SizedBox(height: 12),
            Text(
              Env.hasApiKey ? 'API key loaded' : 'Demo mode (no API key)',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
