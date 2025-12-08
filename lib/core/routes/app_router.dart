import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/album/album_page.dart';
import '../../presentation/pages/timeline/timeline_page.dart';
import '../../presentation/pages/bluetooth/bluetooth_page.dart';
import '../../presentation/pages/calendar/calendar_page.dart';
import '../../presentation/pages/settings/settings_page.dart';

/// ルート名
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String album = '/album';
  static const String albumDetail = '/album/:id';
  static const String timeline = '/timeline';
  static const String postDetail = '/post/:id';
  static const String bluetooth = '/bluetooth';
  static const String calendar = '/calendar';
  static const String settings = '/settings';
}

/// アプリケーションルーター
final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    // メイン画面（BottomNavigationBar付き）
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        // ホーム（ドット絵作成）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        // アルバム
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.album,
              builder: (context, state) => const AlbumPage(),
            ),
          ],
        ),
        // タイムライン
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.timeline,
              builder: (context, state) => const TimelinePage(),
            ),
          ],
        ),
        // すれ違い通信
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.bluetooth,
              builder: (context, state) => const BluetoothPage(),
            ),
          ],
        ),
        // カレンダー
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.calendar,
              builder: (context, state) => const CalendarPage(),
            ),
          ],
        ),
      ],
    ),
    // 設定（モーダル）
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);

/// メインスキャフォールド（BottomNavigationBar付き）
class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'かく',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_album),
            label: 'アルバム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'みんな',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'すれ違い',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
        ],
      ),
    );
  }
}
