import 'package:flutter/material.dart';

import 'models/motion_spec.dart';
import 'screens/chat_history_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/preview_screen.dart';
import 'screens/question_screen.dart';
import 'screens/library_screen.dart';
import 'screens/library_search_screen.dart';
import 'screens/me_screen.dart';
import 'screens/motion_detail_screen.dart';
import 'screens/robot_screen.dart';
import 'screens/signature_screen.dart';
import 'screens/sim_debug_screen.dart';
import 'screens/splash_screen.dart';

/// 화면 경로.
///
/// 슬라이스가 진행되면서 자리표시자가 하나씩 진짜 화면으로 바뀐다.
abstract final class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const homeNew = '/home/new';
  static const chat = '/chat';
  static const chats = '/chats';
  static const preview = '/preview';
  static const question = '/question';
  static const signature = '/signature';
  static const library = '/library';
  static const librarySearch = '/library/search';
  static const motionDetail = '/library/motion';
  static const robot = '/robot';
  static const robotActivity = '/robot/activity';
  static const robotList = '/robot/list';
  static const firmware = '/robot/firmware';
  static const signatureReset = '/robot/signature';
  static const me = '/me';
  static const meNotifications = '/me/notifications';
  static const meAccount = '/me/account';
  static const meHelp = '/me/help';
  static const meTerms = '/me/terms';
  static const notifications = '/notifications';

  /// 브리지 확인용 임시 화면. 슬라이스가 다 끝나면 지운다.
  static const debug = '/debug';

  /// 개발용 시작 화면. `--dart-define=START_ROUTE=/library` 로 지정한다.
  ///
  /// `initialRoute` 에 경로를 넣으면 Flutter 가 `/` 부터 스택을 쌓아 스플래시가
  /// 먼저 뜨고 그 타이머가 홈으로 보내 버린다. 그래서 스택을 직접 만든다.
  static const String _startRoute = String.fromEnvironment('START_ROUTE');

  static List<Route<dynamic>> initialRoutes(String _) {
    if (_startRoute.isEmpty || _startRoute == splash) {
      return [onGenerateRoute(const RouteSettings(name: splash))!];
    }
    return [
      // 뒤로가기로 돌아갈 자리를 하나 깔아 둔다.
      onGenerateRoute(const RouteSettings(name: home))!,
      if (onGenerateRoute(RouteSettings(name: _startRoute)) case final r?) r,
    ];
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case splash:
        page = const SplashScreen();
      case home:
        page = const HomeScreen();
      case homeNew:
        page = const HomeScreen(startNewChat: true);
      case chat:
        page = ChatScreen(entry: settings.arguments as ChatEntry?);
      case chats:
        page = const ChatHistoryScreen();
      case question:
        page = QuestionScreen(entry: settings.arguments! as ChatEntry);
      case preview:
        return PageRouteBuilder<void>(
          settings: settings,
          opaque: false,
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, _, _) =>
              PreviewScreen(spec: settings.arguments! as MotionSpec),
        );
      case signature:
        page = SignatureScreen(
          args: (settings.arguments as SignatureArgs?) ?? const SignatureArgs(),
        );
      case library:
        page = const LibraryScreen();
      case librarySearch:
        page = const LibrarySearchScreen();
      case motionDetail:
        page = MotionDetailScreen(motionId: settings.arguments! as String);
      case robot:
        page = const RobotScreen();
      case robotActivity:
        page = const ActivityScreen();
      case robotList:
        page = const RobotListScreen();
      case firmware:
        page = const FirmwareScreen();
      case signatureReset:
        page = const SignatureResetScreen();
      case me:
        page = const MeScreen();
      case meNotifications:
        page = const MeNotificationsScreen();
      case meAccount:
        page = const MeAccountScreen();
      case meHelp:
        page = const MeHelpScreen();
      case meTerms:
        page = const MeTermsScreen();
      case notifications:
        page = const NotificationsScreen();
      case debug:
        page = const SimDebugScreen();
      default:
        return null;
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
