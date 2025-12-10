import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../providers/theme_provider.dart';
import '../../widgets/web_unsupported_dialog.dart';
import '../feedback/feedback_page.dart';
import 'settings_view_model.dart';

/// 設定画面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsViewModelProvider);

    // メッセージ監視
    ref.listen<SettingsState>(settingsViewModelProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(settingsViewModelProvider.notifier).clearError();
      }
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(settingsViewModelProvider.notifier).clearSuccess();
      }
    });

    // テーマモードの同期（ユーザー情報が読み込まれた時のみ実行）
    ref.listen<SettingsState>(settingsViewModelProvider, (previous, next) {
      if (previous?.user == null && next.user != null) {
        final settingsThemeMode = ref
            .read(settingsViewModelProvider.notifier)
            .getThemeMode();
        final currentThemeMode = ref.read(themeModeProvider);
        if (settingsThemeMode != currentThemeMode) {
          ref.read(themeModeProvider.notifier).setThemeMode(settingsThemeMode);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: state.isLoading && state.user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ニックネーム設定
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('ニックネーム'),
                  subtitle: Text(
                    state.user?.nickname ?? '未設定',
                    style: TextStyle(
                      color: state.user?.nickname == null
                          ? Colors.grey
                          : null,
                    ),
                  ),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _showNicknameDialog(context, ref, state),
                ),
                const Divider(),

                // テーマ設定
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('テーマ'),
                  subtitle: Text(_themeModeToString(ref.watch(themeModeProvider))),
                  onTap: () => _showThemeDialog(context, ref, ref.read(themeModeProvider)),
                ),
                const Divider(),

                // 通知設定
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications,
                    color: kIsWeb ? Colors.grey : null,
                  ),
                  title: Text(
                    '通知',
                    style: kIsWeb
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                  subtitle: Text(
                    kIsWeb ? 'Webでは利用できません' : '交換完了時に通知',
                    style: kIsWeb
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                  value: kIsWeb
                      ? false
                      : (state.user?.settings.notificationsEnabled ?? true),
                  onChanged: kIsWeb
                      ? (value) {
                          WebUnsupportedDialog.show(
                            context,
                            featureName: 'プッシュ通知',
                            description: '通知機能はスマートフォンアプリでのみ利用できます。',
                            iconData: Icons.notifications_off,
                          );
                        }
                      : (value) {
                          ref
                              .read(settingsViewModelProvider.notifier)
                              .toggleNotifications(value);
                        },
                ),
                const Divider(),

                // Bluetooth設定
                SwitchListTile(
                  secondary: Icon(
                    Icons.bluetooth,
                    color: kIsWeb ? Colors.grey : null,
                  ),
                  title: Text(
                    'すれ違い通信',
                    style: kIsWeb
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                  subtitle: Text(
                    kIsWeb ? 'Webでは利用できません' : 'バックグラウンドで有効',
                    style: kIsWeb
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                  value: kIsWeb
                      ? false
                      : (state.user?.settings.bluetoothEnabled ?? false),
                  onChanged: kIsWeb
                      ? (value) {
                          WebUnsupportedDialog.show(
                            context,
                            featureName: 'すれ違い通信',
                            description: 'Bluetooth機能はスマートフォンアプリでのみ利用できます。',
                            iconData: Icons.bluetooth_disabled,
                          );
                        }
                      : (value) {
                          ref
                              .read(settingsViewModelProvider.notifier)
                              .toggleBluetooth(value);
                        },
                ),

                const Divider(),

                // アプリ情報
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('アプリについて'),
                  subtitle: Text('バージョン $_appVersion'),
                  onTap: () => _showAboutDialog(context),
                ),
                const Divider(),

                // 利用規約
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('利用規約'),
                  onTap: () => _showTermsDialog(context),
                ),

                // プライバシーポリシー
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('プライバシーポリシー'),
                  onTap: () => _showPrivacyDialog(context),
                ),

                // お問い合わせ・改善意見
                ListTile(
                  leading: const Icon(Icons.feedback),
                  title: const Text('お問い合わせ・改善意見'),
                  onTap: () => _navigateToFeedback(context),
                ),
                const Divider(),

                // データ削除
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'すべてのデータを削除',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text('アルバムと設定がすべて削除されます'),
                  onTap: () => _showDeleteConfirmDialog(context, ref),
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

  void _navigateToFeedback(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const FeedbackPage(),
      ),
    );
  }

  void _showNicknameDialog(
    BuildContext context,
    WidgetRef ref,
    SettingsState state,
  ) {
    final controller = TextEditingController(text: state.user?.nickname ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ニックネーム'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              maxLength: 5,
              decoration: const InputDecoration(
                hintText: '5文字以内',
                counterText: '',
              ),
              validator: (value) {
                if (value != null && value.length > 5) {
                  return '5文字以内で入力してください';
                }
                return null;
              },
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  ref
                      .read(settingsViewModelProvider.notifier)
                      .updateNickname(controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('テーマを選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              return ListTile(
                leading: Radio<ThemeMode>(
                  value: mode,
                  groupValue: currentMode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                      ref
                          .read(settingsViewModelProvider.notifier)
                          .updateThemeMode(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Text(_themeModeToString(mode)),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  ref
                      .read(settingsViewModelProvider.notifier)
                      .updateThemeMode(mode);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('4×4 Pixel Diary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('バージョン $_appVersion'),
              const SizedBox(height: 16),
              const Text(
                '4×4のドット絵を作成して、\n'
                '匿名で他のユーザーと交換できる\n'
                '「交換日記」アプリです。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('利用規約'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本アプリをご利用いただくにあたり、'
                  '以下の規約に同意いただいたものとみなします。\n\n'
                  '1. 禁止事項\n'
                  '・他者を誹謗中傷するコンテンツの投稿\n'
                  '・わいせつなコンテンツの投稿\n'
                  '・法律に違反するコンテンツの投稿\n\n'
                  '2. 免責事項\n'
                  '・本アプリの利用により生じた損害について、'
                  '開発者は一切の責任を負いません。\n\n'
                  '3. サービスの変更・終了\n'
                  '・予告なくサービスを変更・終了する場合があります。',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プライバシーポリシー'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本アプリは、ユーザーのプライバシーを尊重し、'
                  '個人情報の保護に努めます。\n\n'
                  '【収集しない情報】\n'
                  '・メールアドレス\n'
                  '・電話番号\n'
                  '・SNSアカウント\n'
                  '・位置情報\n'
                  '・広告ID\n\n'
                  '【収集する情報】\n'
                  '・デバイス固有のランダムUUID（匿名識別用）\n'
                  '・任意で設定したニックネーム（5文字以内）\n'
                  '・作成したドット絵データ\n\n'
                  '【データの保存】\n'
                  '・すべてのデータはお使いの端末内に保存されます。\n'
                  '・サーバーには匿名IDとドット絵データのみ送信されます。',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('データの削除'),
          content: const Text(
            'すべてのデータを削除しますか？\n\n'
            '・アルバムのすべてのドット絵\n'
            '・設定情報\n\n'
            'この操作は取り消せません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(settingsViewModelProvider.notifier).deleteAllData();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );
  }
}
