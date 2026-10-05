import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'screens/sim_debug_screen.dart';

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
      // STEP 3 확인용. STEP 10 에서 실제 화면(00 스플래시 → 06 홈)으로 바뀐다.
      home: const SimDebugScreen(),
    );
  }
}
