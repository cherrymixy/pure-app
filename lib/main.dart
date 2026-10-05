import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/chat_provider.dart';
import 'providers/generation_provider.dart';
import 'providers/library_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/robot_provider.dart';
import 'repositories/data_repository.dart';
import 'repositories/local_repository.dart';
import 'screens/sim_debug_screen.dart';
import 'services/generation/generation_service.dart';
import 'services/thumbnail_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 전시 중 화면이 꺼지지 않게.
  await WakelockPlus.enable();

  // 저장소를 먼저 올린다. 화면이 뜰 때는 이미 데이터가 메모리에 있다.
  final repo = await LocalRepository.forApp();
  await repo.init();
  final thumbnails = await ThumbnailStore.forApp();

  runApp(PureApp(repository: repo, thumbnails: thumbnails));
}

class PureApp extends StatelessWidget {
  const PureApp({super.key, required this.repository, required this.thumbnails});

  final DataRepository repository;
  final ThumbnailStore thumbnails;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DataRepository>.value(value: repository),
        Provider<ThumbnailStore>.value(value: thumbnails),
        ChangeNotifierProvider(create: (_) => ProfileProvider(repository)),
        ChangeNotifierProvider(create: (_) => RobotProvider(repository)),
        ChangeNotifierProvider(create: (_) => ChatProvider(repository)),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(repository, thumbnails: thumbnails),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider(repository)),
        ChangeNotifierProvider(
          create: (_) => GenerationProvider(GenerationService(), repository),
        ),
      ],
      child: MaterialApp(
        title: 'PURE',
        debugShowCheckedModeBanner: false,
        // STEP 3 확인용. STEP 10 에서 실제 화면(00 스플래시 → 06 홈)으로 바뀐다.
        home: const SimDebugScreen(),
      ),
    );
  }
}
