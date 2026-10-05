import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
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
  static const signature = '/signature';
  static const library = '/library';
  static const robot = '/robot';
  static const robotActivity = '/robot/activity';
  static const me = '/me';
  static const notifications = '/notifications';

  /// 브리지 확인용 임시 화면. 슬라이스가 다 끝나면 지운다.
  static const debug = '/debug';

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
        page = const PlaceholderScreen(title: 'Chat', slice: '슬라이스 ②');
      case chats:
        page = const PlaceholderScreen(title: 'Recent chats', slice: '슬라이스 ②');
      case signature:
        page = const PlaceholderScreen(title: 'Motion signature', slice: '슬라이스 ④');
      case library:
        page = const PlaceholderScreen(title: 'Library', slice: '슬라이스 ⑤');
      case robot:
        page = const PlaceholderScreen(title: 'Robot', slice: '슬라이스 ⑥');
      case robotActivity:
        page = const PlaceholderScreen(title: 'Activity history', slice: '슬라이스 ⑥');
      case me:
        page = const PlaceholderScreen(title: 'Me', slice: '슬라이스 ⑥');
      case notifications:
        page = const PlaceholderScreen(title: 'Notifications', slice: '슬라이스 ⑥');
      case debug:
        page = const SimDebugScreen();
      default:
        return null;
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
