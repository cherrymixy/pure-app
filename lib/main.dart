import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/chat_provider.dart';
import 'providers/generation_provider.dart';
import 'providers/library_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/voice_provider.dart';
import 'providers/robot_provider.dart';
import 'repositories/data_repository.dart';
import 'repositories/local_repository.dart';
import 'app_routes.dart';
import 'sim/sim_host.dart';
import 'widgets/demo_mode_toggle.dart';
import 'services/generation/generation_service.dart';
import 'services/thumbnail_store.dart';
import 'services/video_input_service.dart';
import 'theme/app_theme.dart';
import 'services/voice_input_service.dart';

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
        Provider<VideoInputService>(
          create: (_) => VideoInputService(store: thumbnails),
        ),
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
        ChangeNotifierProvider(create: (_) => VoiceProvider(VoiceInputService())),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'PURE',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // 개발 중 특정 화면을 바로 열어 확인하기 위한 통로.
          //   ./scripts/dev.sh install --dart-define=START_ROUTE=/library
          // 전시 빌드에서는 비어 있어 항상 스플래시로 시작한다.
          onGenerateInitialRoutes: AppRoutes.initialRoutes,
          builder: (context, child) {
            // 시뮬레이터 WebView 는 앱에 하나뿐이고 화면 위를 떠다닌다.
            // 스플래시가 떠 있는 동안 뒤에서 wasm 을 올린다.
            return SimHost(
              child: DemoModeToggle(
                toggle: context.read<GenerationProvider>().toggleDemoMode,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
