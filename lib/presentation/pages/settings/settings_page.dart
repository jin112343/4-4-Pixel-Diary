import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme_provider.dart';

/// 設定画面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // ニックネーム設定
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('ニックネーム'),
            subtitle: const Text('未設定'),
            onTap: () {
              // TODO: ニックネーム設定ダイアログ
            },
          ),
          const Divider(),

          // テーマ設定
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('テーマ'),
            subtitle: Text(_themeModeToString(themeMode)),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
          const Divider(),

          // 通知設定
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('通知'),
            subtitle: const Text('交換完了時に通知'),
            value: true,
            onChanged: (value) {
              // TODO: 通知設定
            },
          ),
          const Divider(),

          // Bluetooth設定
          SwitchListTile(
            secondary: const Icon(Icons.bluetooth),
            title: const Text('すれ違い通信'),
            subtitle: const Text('バックグラウンドで有効'),
            value: false,
            onChanged: (value) {
              // TODO: Bluetooth設定
            },
          ),
          const Divider(),

          // アプリ情報
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('アプリについて'),
            subtitle: const Text('バージョン 1.0.0'),
            onTap: () {
              // TODO: アプリ情報画面
            },
          ),
          const Divider(),

          // 利用規約
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('利用規約'),
            onTap: () {
              // TODO: 利用規約画面
            },
          ),

          // プライバシーポリシー
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            onTap: () {
              // TODO: プライバシーポリシー画面
            },
          ),
        ],
      ),
    );
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'システム設定に従う';
      case ThemeMode.light:
        return 'ライト';
      case ThemeMode.dark:
        return 'ダーク';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('テーマを選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              return RadioListTile<ThemeMode>(
                title: Text(_themeModeToString(mode)),
                value: mode,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
