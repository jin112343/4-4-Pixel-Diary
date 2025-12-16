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
                  // ignore: prefer_const_constructors - kIsWebによる動的な色指定のため
                  secondary: Icon(
                    Icons.notifications,
                    color: kIsWeb ? Colors.grey : null,
                  ),
                  // ignore: prefer_const_constructors - kIsWebによる動的なスタイル指定のため
                  title: Text(
                    '通知',
                    style: kIsWeb
                        ? const TextStyle(color: Colors.grey)
                        : null,
                  ),
                  // ignore: prefer_const_constructors - kIsWebによる動的なスタイル指定のため
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
    showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _NicknameDialog(
          initialNickname: state.user?.nickname ?? '',
        );
      },
    ).then((nickname) {
      if (nickname != null) {
        ref.read(settingsViewModelProvider.notifier).updateNickname(nickname);
      }
    });
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showDialog<ThemeMode>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('テーマを選択'),
          children: ThemeMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return SimpleDialogOption(
              onPressed: () {
                ref.read(themeModeProvider.notifier).setThemeMode(mode);
                ref
                    .read(settingsViewModelProvider.notifier)
                    .updateThemeMode(mode);
                Navigator.of(context).pop(mode);
              },
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _themeModeToString(mode),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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

}

/// ニックネーム編集ダイアログ
class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.initialNickname});

  final String initialNickname;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ニックネーム'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
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
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
