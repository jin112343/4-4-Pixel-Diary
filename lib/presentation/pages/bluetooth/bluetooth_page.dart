import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/color_constants.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../services/bluetooth/ble_pairing_service.dart';
import '../../../services/bluetooth/ble_service.dart';
import '../../widgets/web_unsupported_dialog.dart';
import '../home/home_view_model.dart';
import 'bluetooth_view_model.dart';

/// すれ違い通信画面
class BluetoothPage extends ConsumerStatefulWidget {
  const BluetoothPage({super.key});

  @override
  ConsumerState<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends ConsumerState<BluetoothPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web環境では非対応ビューを表示
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('すれ違い通信'),
        ),
        body: const WebUnsupportedView(
          featureName: 'すれ違い通信',
          description: 'Bluetooth機能はスマートフォンアプリでのみ利用できます。',
          iconData: Icons.bluetooth_disabled,
        ),
      );
    }

    final state = ref.watch(bluetoothViewModelProvider);

    // メッセージ監視
    ref.listen<BluetoothState>(bluetoothViewModelProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(bluetoothViewModelProvider.notifier).clearError();
      }

      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(bluetoothViewModelProvider.notifier).clearSuccess();
      }

      // ドット絵受信時にダイアログ表示
      if (next.receivedArt != null &&
          previous?.receivedArt != next.receivedArt) {
        _showReceivedArtDialog(context, next.receivedArt!);
      }

      // ペアリングダイアログ表示
      if (next.showPairingDialog &&
          (previous == null || !previous.showPairingDialog) &&
          next.pairingInfo != null) {
        _showPairingDialog(context, next.pairingInfo!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('すれ違い通信'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'さがす', icon: Icon(Icons.search)),
            Tab(text: 'りれき', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SearchTab(state: state),
          _HistoryTab(state: state),
        ],
      ),
    );
  }

  void _showReceivedArtDialog(BuildContext context, PixelArt art) {
    showDialog<void>(
      context: context,
      builder: (context) => _ReceivedArtDialog(pixelArt: art),
    );
  }

  void _showPairingDialog(BuildContext context, PairingInfo pairingInfo) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PairingDialog(pairingInfo: pairingInfo),
    );
  }
}

/// 検索タブ
class _SearchTab extends ConsumerWidget {
  const _SearchTab({required this.state});

  final BluetoothState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 権限が拒否されている場合
    if (state.isPermissionDenied) {
      return _PermissionDeniedView(
        onRetryTap: () {
          ref.read(bluetoothViewModelProvider.notifier).checkPermission();
        },
      );
    }

    // Bluetoothが無効の場合
    if (!state.isBluetoothAvailable) {
      return _BluetoothDisabledView(
        onEnableTap: () {
          ref.read(bluetoothViewModelProvider.notifier).requestBluetoothOn();
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 交換するドット絵選択
          _ArtSelectionCard(
            artToExchange: state.artToExchange,
            onSelectTap: () => _showArtSelectionDialog(context, ref),
          ),

          const SizedBox(height: 16),

          // ニックネーム設定
          _NicknameCard(
            nickname: state.nickname,
            onNicknameChanged: (nickname) {
              ref.read(bluetoothViewModelProvider.notifier).setNickname(nickname);
            },
          ),

          const SizedBox(height: 16),

          // スキャンコントロール（Dual Mode）
          _ScanControlCard(
            state: state,
            onStartScan: () {
              // ニックネームが未設定の場合はデフォルト値を使用
              final viewModel = ref.read(bluetoothViewModelProvider.notifier);
              if (state.nickname == null || state.nickname!.isEmpty) {
                viewModel.setNickname('ゲスト');
              }
              // Dual Mode開始（Central + Peripheral同時動作）
              viewModel.startDualMode();
            },
            onStopScan: () {
              ref.read(bluetoothViewModelProvider.notifier).stopDualMode();
            },
          ),

          const SizedBox(height: 16),

          // 発見したデバイス一覧
          if (state.discoveredDevices.isNotEmpty ||
              state.connectionState == BleConnectionState.scanning)
            _DiscoveredDevicesCard(
              devices: state.discoveredDevices,
              selectedDeviceId: state.selectedDeviceId,
              connectionState: state.connectionState,
              onDeviceTap: (deviceId) {
                ref.read(bluetoothViewModelProvider.notifier).selectDevice(
                      deviceId,
                    );
              },
              onExchangeTap: () {
                ref
                    .read(bluetoothViewModelProvider.notifier)
                    .exchangeWithSelectedDevice();
              },
            ),
        ],
      ),
    );
  }

  void _showArtSelectionDialog(BuildContext context, WidgetRef ref) {
    // ホーム画面の現在のドット絵を取得
    final homeState = ref.read(homeViewModelProvider);

    if (homeState.pixels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まずホーム画面でドット絵を描いてください')),
      );
      return;
    }

    // 現在のキャンバスからPixelArtを生成
    final art = PixelArt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pixels: homeState.pixels
          .map((c) => (c.r.toInt() << 16) | (c.g.toInt() << 8) | c.b.toInt())
          .toList(),
      title: homeState.title,
      createdAt: DateTime.now(),
      gridSize: homeState.gridSize,
    );

    ref.read(bluetoothViewModelProvider.notifier).setArtToExchange(art);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('現在のドット絵を設定しました')),
    );
  }
}

/// Bluetooth無効時のビュー
class _BluetoothDisabledView extends StatelessWidget {
  const _BluetoothDisabledView({required this.onEnableTap});

  final VoidCallback onEnableTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Bluetoothがオフです',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'すれ違い通信を使うには\nBluetoothをオンにしてください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onEnableTap,
              icon: const Icon(Icons.bluetooth),
              label: const Text('Bluetoothをオンにする'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 権限拒否時のビュー
class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetryTap});

  final VoidCallback onRetryTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_cell,
              size: 80,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Bluetooth権限が必要です',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'すれ違い通信を使うには\nBluetoothへのアクセスを許可してください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '設定アプリから権限を有効にできます',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetryTap,
              icon: const Icon(Icons.refresh),
              label: const Text('再度許可をリクエスト'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ニックネーム設定カード
class _NicknameCard extends StatefulWidget {
  const _NicknameCard({
    required this.nickname,
    required this.onNicknameChanged,
  });

  final String? nickname;
  final void Function(String) onNicknameChanged;

  @override
  State<_NicknameCard> createState() => _NicknameCardState();
}

class _NicknameCardState extends State<_NicknameCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nickname ?? 'ゲスト');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                Text(
                  'ニックネーム',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 5,
              decoration: InputDecoration(
                hintText: 'ゲスト',
                border: const OutlineInputBorder(),
                counterText: '${_controller.text.length}/5文字',
                helperText: 'すれ違い時に表示される名前（5文字以内）',
              ),
              onChanged: (value) {
                if (value.length <= 5) {
                  widget.onNicknameChanged(value);
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ドット絵選択カード
class _ArtSelectionCard extends StatelessWidget {
  const _ArtSelectionCard({
    required this.artToExchange,
    required this.onSelectTap,
  });

  final PixelArt? artToExchange;
  final VoidCallback onSelectTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brush, size: 20),
                const SizedBox(width: 8),
                Text(
                  'こうかんするドット絵',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (artToExchange == null)
              InkWell(
                onTap: onSelectTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 32, color: Colors.grey[400]),
                        const SizedBox(height: 4),
                        Text(
                          'タップして設定',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  // プレビュー
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: ColorConstants.gridLineColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: artToExchange!.gridSize,
                      ),
                      itemCount: artToExchange!.pixels.length,
                      itemBuilder: (context, index) {
                        return Container(
                          color:
                              Color(artToExchange!.pixels[index] | 0xFF000000),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (artToExchange!.title.isNotEmpty)
                          Text(
                            artToExchange!.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        Text(
                          '${artToExchange!.gridSize}×${artToExchange!.gridSize}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onSelectTap,
                    tooltip: '変更',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// スキャンコントロールカード
class _ScanControlCard extends ConsumerWidget {
  const _ScanControlCard({
    required this.state,
    required this.onStartScan,
    required this.onStopScan,
  });

  final BluetoothState state;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = state.isDualMode || state.connectionState == BleConnectionState.scanning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ステータス表示
            _buildStatusRow(context),

            const SizedBox(height: 16),

            // スキャンボタン（Dual Mode）
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: state.artToExchange == null
                    ? null
                    : (isActive ? onStopScan : onStartScan),
                icon: isActive
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(isActive ? 'すれ違い中...' : 'すれ違いを開始'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.orange : null,
                ),
              ),
            ),

            if (state.artToExchange == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'まずこうかんするドット絵を設定してください',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    // Dual Mode動作中の場合
    if (state.isDualMode) {
      if (state.connectionState == BleConnectionState.connecting ||
          state.connectionState == BleConnectionState.exchanging) {
        return 'こうかん中...';
      }
      return 'すれ違い中...';
    }

    // 通常モード
    switch (state.connectionState) {
      case BleConnectionState.disconnected:
        return 'スタンバイ';
      case BleConnectionState.scanning:
        return 'スキャン中...';
      case BleConnectionState.connecting:
        return '接続中...';
      case BleConnectionState.connected:
        return '接続済み';
      case BleConnectionState.exchanging:
        return 'こうかん中...';
    }
  }

  Color _getStatusColor() {
    // Dual Mode動作中の場合
    if (state.isDualMode) {
      if (state.connectionState == BleConnectionState.connecting ||
          state.connectionState == BleConnectionState.exchanging) {
        return Colors.purple;
      }
      return Colors.green;
    }

    // 通常モード
    switch (state.connectionState) {
      case BleConnectionState.disconnected:
        return Colors.grey;
      case BleConnectionState.scanning:
        return Colors.blue;
      case BleConnectionState.connecting:
        return Colors.orange;
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.exchanging:
        return Colors.purple;
    }
  }
}

/// 発見したデバイス一覧カード
class _DiscoveredDevicesCard extends StatelessWidget {
  const _DiscoveredDevicesCard({
    required this.devices,
    required this.selectedDeviceId,
    required this.connectionState,
    required this.onDeviceTap,
    required this.onExchangeTap,
  });

  final List<DiscoveredDevice> devices;
  final String? selectedDeviceId;
  final BleConnectionState connectionState;
  final void Function(String) onDeviceTap;
  final VoidCallback onExchangeTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, size: 20),
                const SizedBox(width: 8),
                Text(
                  'みつかったユーザー',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${devices.length}人',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (devices.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '近くのユーザーをさがしています...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isSelected = device.deviceId == selectedDeviceId;

                  return ListTile(
                    onTap: () => onDeviceTap(device.deviceId),
                    leading: CircleAvatar(
                      backgroundColor:
                          isSelected ? Colors.blue : Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      device.nickname ?? '名前なし',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '電波: ${_getRssiLabel(device.rssi)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : const Icon(Icons.chevron_right),
                  );
                },
              ),

            if (selectedDeviceId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: connectionState == BleConnectionState.scanning
                      ? onExchangeTap
                      : null,
                  icon: connectionState == BleConnectionState.connecting ||
                          connectionState == BleConnectionState.exchanging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.swap_horiz),
                  label: const Text('こうかんする'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRssiLabel(int rssi) {
    if (rssi >= -50) return '強い';
    if (rssi >= -70) return '普通';
    if (rssi >= -85) return '弱い';
    return 'とても弱い';
  }
}

/// 履歴タブ
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.state});

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    if (state.exchangeHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'まだ履歴がありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'すれ違い通信でこうかんすると\nここに記録されます',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: state.exchangeHistory.length,
      itemBuilder: (context, index) {
        final entry = state.exchangeHistory[index];
        return _HistoryItem(entry: entry);
      },
    );
  }
}

/// 履歴アイテム
class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});

  final ExchangeHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 送信したアート
            _buildArtPreview(entry.sentArt, '送信'),
            const SizedBox(width: 8),

            // 矢印
            const Icon(Icons.swap_horiz, color: Colors.blue),
            const SizedBox(width: 8),

            // 受信したアート
            _buildArtPreview(entry.receivedArt, '受信'),

            const SizedBox(width: 12),

            // 情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.partnerNickname ?? '名前なし',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatDate(entry.exchangedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtPreview(PixelArt art, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: ColorConstants.gridLineColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: art.gridSize,
            ),
            itemCount: art.pixels.length,
            itemBuilder: (context, index) {
              return Container(
                color: Color(art.pixels[index] | 0xFF000000),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 受信アート表示ダイアログ
class _ReceivedArtDialog extends ConsumerWidget {
  const _ReceivedArtDialog({required this.pixelArt});

  final PixelArt pixelArt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration,
              size: 48,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),

            Text(
              'ドット絵を受け取りました！',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 24),

            // ピクセルアート表示
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: ColorConstants.gridLineColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: pixelArt.gridSize,
                ),
                itemCount: pixelArt.pixels.length,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Color(pixelArt.pixels[index] | 0xFF000000),
                      border: Border.all(
                        color: ColorConstants.gridLineColor,
                        width: 0.5,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            if (pixelArt.title.isNotEmpty)
              Text(
                pixelArt.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),

            if (pixelArt.authorNickname != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '作者: ${pixelArt.authorNickname}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref
                      .read(bluetoothViewModelProvider.notifier)
                      .clearReceivedArt();
                  Navigator.of(context).pop();
                },
                child: const Text('とじる'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ペアリングダイアログ
class _PairingDialog extends ConsumerStatefulWidget {
  const _PairingDialog({required this.pairingInfo});

  final PairingInfo pairingInfo;

  @override
  ConsumerState<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends ConsumerState<_PairingDialog> {
  final TextEditingController _passkeyController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _passkeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bluetoothViewModelProvider);
    final isNumericComparison =
        widget.pairingInfo.method == PairingMethod.numericComparison;

    // ペアリング状態の変化を監視
    ref.listen<BluetoothState>(bluetoothViewModelProvider, (previous, next) {
      if (next.pairingState == PairingState.paired ||
          next.pairingState == PairingState.failed) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Icon(
              Icons.bluetooth_connected,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),

            Text(
              'ペアリング認証',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            Text(
              isNumericComparison
                  ? '相手のデバイスに同じ番号が\n表示されていることを確認してください'
                  : '相手のデバイスに表示されている\n番号を入力してください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // ペアリングコード表示（Numeric Comparison）
            if (isNumericComparison) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  _formatPairingCode(widget.pairingInfo.pairingCode),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '有効期限: ${_formatTimeRemaining()}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],

            // パスキー入力（Passkey Entry）
            if (!isNumericComparison) ...[
              TextField(
                controller: _passkeyController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 32,
                    letterSpacing: 8,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ボタン
            if (state.pairingState == PairingState.verifying || _isVerifying)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('確認中...'),
                ],
              )
            else if (isNumericComparison)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleConfirmation(false),
                      child: const Text('ちがう'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleConfirmation(true),
                      child: const Text('おなじ'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _passkeyController.text.length == 6
                      ? _handlePasskeySubmit
                      : null,
                  child: const Text('確認'),
                ),
              ),

            const SizedBox(height: 16),

            // キャンセルボタン
            TextButton(
              onPressed: () {
                ref
                    .read(bluetoothViewModelProvider.notifier)
                    .dismissPairingDialog();
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPairingCode(String code) {
    // 3桁ずつスペースで区切る (例: "123 456")
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    return code;
  }

  String _formatTimeRemaining() {
    final remaining =
        widget.pairingInfo.expiresAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      return '期限切れ';
    }
    return '残り${remaining}秒';
  }

  Future<void> _handleConfirmation(bool confirmed) async {
    setState(() {
      _isVerifying = true;
    });

    await ref
        .read(bluetoothViewModelProvider.notifier)
        .confirmPairing(confirmed: confirmed);

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _handlePasskeySubmit() async {
    setState(() {
      _isVerifying = true;
    });

    await ref
        .read(bluetoothViewModelProvider.notifier)
        .submitPasskey(_passkeyController.text);

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
    }
  }
}
