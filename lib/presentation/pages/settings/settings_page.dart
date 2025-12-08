import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme_provider.dart';
import '../../../services/bluetooth/ble_privacy_service.dart';
import 'settings_view_model.dart';

/// 設定画面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // テーマモードの同期
    final settingsThemeMode = ref
        .read(settingsViewModelProvider.notifier)
        .getThemeMode();
    final currentThemeMode = ref.watch(themeModeProvider);
    if (state.user != null && settingsThemeMode != currentThemeMode) {
      Future.microtask(() {
        ref.read(themeModeProvider.notifier).setThemeMode(settingsThemeMode);
      });
    }

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
                  subtitle: Text(_themeModeToString(currentThemeMode)),
                  onTap: () => _showThemeDialog(context, ref, currentThemeMode),
                ),
                const Divider(),

                // 通知設定
                SwitchListTile(
                  secondary: const Icon(Icons.notifications),
                  title: const Text('通知'),
                  subtitle: const Text('交換完了時に通知'),
                  value: state.user?.settings.notificationsEnabled ?? true,
                  onChanged: (value) {
                    ref
                        .read(settingsViewModelProvider.notifier)
                        .toggleNotifications(value);
                  },
                ),
                const Divider(),

                // Bluetooth設定
                SwitchListTile(
                  secondary: const Icon(Icons.bluetooth),
                  title: const Text('すれ違い通信'),
                  subtitle: const Text('バックグラウンドで有効'),
                  value: state.user?.settings.bluetoothEnabled ?? false,
                  onChanged: (value) {
                    ref
                        .read(settingsViewModelProvider.notifier)
                        .toggleBluetooth(value);
                  },
                ),

                // BLEプライバシー設定
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('BLEプライバシー設定'),
                  subtitle: const Text('MACアドレスランダム化'),
                  onTap: () => _showBlePrivacyDialog(context, ref),
                ),
                const Divider(),

                // アプリ情報
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('アプリについて'),
                  subtitle: const Text('バージョン 1.0.0'),
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
    );
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
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('バージョン 1.0.0'),
              SizedBox(height: 16),
              Text(
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

  void _showBlePrivacyDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return const _BlePrivacyDialog();
      },
    );
  }
}

/// BLEプライバシー設定ダイアログ
class _BlePrivacyDialog extends StatefulWidget {
  const _BlePrivacyDialog();

  @override
  State<_BlePrivacyDialog> createState() => _BlePrivacyDialogState();
}

class _BlePrivacyDialogState extends State<_BlePrivacyDialog> {
  late BlePrivacyMode _selectedMode;
  late int _randomizeInterval;
  BlePrivacyInfo? _privacyInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await BlePrivacyService.instance.initialize();
    final info = BlePrivacyService.instance.getPrivacyInfo();

    setState(() {
      _selectedMode = info.mode;
      _randomizeInterval = info.randomizeInterval;
      _privacyInfo = info;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security),
          SizedBox(width: 8),
          Text('BLEプライバシー設定'),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // プライバシーモード選択
                  const Text(
                    'プライバシーモード',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<BlePrivacyMode>(
                    title: const Text('標準'),
                    subtitle: const Text('システムデフォルトの設定'),
                    value: BlePrivacyMode.standard,
                    groupValue: _selectedMode,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMode = value);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  RadioListTile<BlePrivacyMode>(
                    title: const Text('強化'),
                    subtitle: const Text('最大限のプライバシー保護'),
                    value: BlePrivacyMode.enhanced,
                    groupValue: _selectedMode,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMode = value);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ランダム化間隔
                  const Text(
                    'アドレス更新間隔',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _randomizeInterval.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          label: '$_randomizeInterval分',
                          onChanged: (value) {
                            setState(() {
                              _randomizeInterval = value.round();
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$_randomizeInterval分',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // プラットフォーム情報
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'プラットフォーム情報',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _privacyInfo?.platformInfo ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        if (_privacyInfo?.isSystemManaged ?? false) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'MACアドレスランダム化: 有効',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSettings,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    await BlePrivacyService.instance.setPrivacyMode(_selectedMode);
    await BlePrivacyService.instance.setRandomizeInterval(_randomizeInterval);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('BLEプライバシー設定を保存しました'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
