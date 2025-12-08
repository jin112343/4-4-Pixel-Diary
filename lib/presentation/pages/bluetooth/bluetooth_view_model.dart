import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../services/bluetooth/ble_pairing_service.dart';
import '../../../services/bluetooth/ble_service.dart';

part 'bluetooth_view_model.freezed.dart';

/// すれ違い通信モード
enum ExchangeMode {
  /// 手動モード（スキャン → 選択 → 交換）
  manual,

  /// 自動モード（バックグラウンドで自動交換）
  auto,
}

/// すれ違い履歴エントリ
@freezed
class ExchangeHistoryEntry with _$ExchangeHistoryEntry {
  const factory ExchangeHistoryEntry({
    required String id,
    required PixelArt sentArt,
    required PixelArt receivedArt,
    required DateTime exchangedAt,
    String? partnerNickname,
  }) = _ExchangeHistoryEntry;
}

/// Bluetooth画面の状態
@freezed
class BluetoothState with _$BluetoothState {
  const factory BluetoothState({
    /// Bluetoothが利用可能か
    @Default(false) bool isBluetoothAvailable,

    /// 現在の接続状態
    @Default(BleConnectionState.disconnected)
    BleConnectionState connectionState,

    /// 交換モード
    @Default(ExchangeMode.manual) ExchangeMode exchangeMode,

    /// 発見したデバイス一覧
    @Default([]) List<DiscoveredDevice> discoveredDevices,

    /// 交換に使用するドット絵
    PixelArt? artToExchange,

    /// 受信したドット絵
    PixelArt? receivedArt,

    /// 交換履歴
    @Default([]) List<ExchangeHistoryEntry> exchangeHistory,

    /// エラーメッセージ
    String? errorMessage,

    /// 成功メッセージ
    String? successMessage,

    /// 選択中のデバイスID
    String? selectedDeviceId,

    /// 権限状態
    @Default(BlePermissionStatus.unknown) BlePermissionStatus permissionStatus,

    /// 権限が拒否されているか
    @Default(false) bool isPermissionDenied,

    /// ペアリング状態
    @Default(PairingState.notPaired) PairingState pairingState,

    /// ペアリング情報
    PairingInfo? pairingInfo,

    /// ペアリングダイアログを表示するか
    @Default(false) bool showPairingDialog,
  }) = _BluetoothState;
}

/// Bluetooth画面のViewModel
class BluetoothViewModel extends StateNotifier<BluetoothState> {
  BluetoothViewModel(this._bleService) : super(const BluetoothState()) {
    _initialize();
  }

  final BleService _bleService;

  StreamSubscription<BleConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<DiscoveredDevice>>? _discoveredDevicesSubscription;
  StreamSubscription<PixelArt>? _receivedArtSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<PairingState>? _pairingStateSubscription;
  StreamSubscription<PairingInfo>? _pairingRequiredSubscription;

  /// 初期化
  Future<void> _initialize() async {
    // Bluetooth利用可能状態をチェック
    final isAvailable = await _bleService.isBluetoothAvailable();
    state = state.copyWith(isBluetoothAvailable: isAvailable);

    // ストリームを購読
    _connectionStateSubscription =
        _bleService.connectionStateStream.listen(_onConnectionStateChanged);
    _discoveredDevicesSubscription =
        _bleService.discoveredDevicesStream.listen(_onDevicesDiscovered);
    _receivedArtSubscription =
        _bleService.receivedArtStream.listen(_onArtReceived);
    _errorSubscription = _bleService.errorStream.listen(_onError);
    _pairingStateSubscription =
        _bleService.pairingStateStream.listen(_onPairingStateChanged);
    _pairingRequiredSubscription =
        _bleService.pairingRequiredStream.listen(_onPairingRequired);

    // 権限チェック
    await checkPermission();
  }

  /// 権限をチェック・リクエスト
  Future<void> checkPermission() async {
    final status = await _bleService.checkAndRequestPermission();
    state = state.copyWith(
      permissionStatus: status,
      isPermissionDenied: status == BlePermissionStatus.denied ||
          status == BlePermissionStatus.permanentlyDenied,
    );
  }

  // ========== Event Handlers ==========

  void _onConnectionStateChanged(BleConnectionState connectionState) {
    state = state.copyWith(connectionState: connectionState);
  }

  void _onDevicesDiscovered(List<DiscoveredDevice> devices) {
    state = state.copyWith(discoveredDevices: devices);
  }

  void _onArtReceived(PixelArt art) {
    state = state.copyWith(
      receivedArt: art,
      successMessage: 'ドット絵を受け取りました！',
    );

    // 履歴に追加
    if (state.artToExchange != null) {
      _addToHistory(state.artToExchange!, art);
    }
  }

  void _onError(String error) {
    state = state.copyWith(errorMessage: error);
    logger.e('Bluetooth error: $error');
  }

  void _onPairingStateChanged(PairingState pairingState) {
    state = state.copyWith(pairingState: pairingState);

    // ペアリング完了または失敗時はダイアログを閉じる
    if (pairingState == PairingState.paired ||
        pairingState == PairingState.failed) {
      state = state.copyWith(showPairingDialog: false);

      if (pairingState == PairingState.paired) {
        state = state.copyWith(successMessage: 'ペアリングが完了しました');
      } else {
        state = state.copyWith(errorMessage: 'ペアリングに失敗しました');
      }
    }
  }

  void _onPairingRequired(PairingInfo pairingInfo) {
    state = state.copyWith(
      pairingInfo: pairingInfo,
      showPairingDialog: true,
    );
  }

  // ========== Public Methods ==========

  /// Bluetooth状態を再チェック
  Future<void> checkBluetoothStatus() async {
    final isAvailable = await _bleService.isBluetoothAvailable();
    state = state.copyWith(isBluetoothAvailable: isAvailable);
  }

  /// Bluetoothをオンにするようリクエスト
  Future<void> requestBluetoothOn() async {
    await _bleService.requestBluetoothOn();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await checkBluetoothStatus();
  }

  /// 交換するドット絵を設定
  void setArtToExchange(PixelArt art) {
    state = state.copyWith(artToExchange: art);
  }

  /// 交換モードを切り替え
  void toggleExchangeMode() {
    final newMode = state.exchangeMode == ExchangeMode.manual
        ? ExchangeMode.auto
        : ExchangeMode.manual;
    state = state.copyWith(exchangeMode: newMode);
  }

  /// スキャンを開始
  Future<void> startScanning() async {
    if (state.artToExchange == null) {
      state = state.copyWith(errorMessage: '交換するドット絵を選択してください');
      return;
    }

    if (!state.isBluetoothAvailable) {
      state = state.copyWith(errorMessage: 'Bluetoothが利用できません');
      return;
    }

    clearMessages();

    try {
      await _bleService.startScanning(
        artToExchange: state.artToExchange!,
      );
    } catch (e, stackTrace) {
      logger.e('startScanning failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'スキャン開始に失敗しました');
    }
  }

  /// スキャンを停止
  Future<void> stopScanning() async {
    await _bleService.stopScanning();
  }

  /// デバイスを選択
  void selectDevice(String deviceId) {
    state = state.copyWith(selectedDeviceId: deviceId);
  }

  /// 選択したデバイスと交換
  Future<void> exchangeWithSelectedDevice() async {
    if (state.selectedDeviceId == null) {
      state = state.copyWith(errorMessage: 'デバイスを選択してください');
      return;
    }

    clearMessages();

    try {
      final receivedArt =
          await _bleService.connectAndExchange(state.selectedDeviceId!);

      if (receivedArt != null) {
        state = state.copyWith(
          receivedArt: receivedArt,
          successMessage: 'ドット絵を交換しました！',
          selectedDeviceId: null,
        );

        // 履歴に追加
        if (state.artToExchange != null) {
          _addToHistory(state.artToExchange!, receivedArt);
        }
      }
    } catch (e, stackTrace) {
      logger.e('exchangeWithSelectedDevice failed',
          error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: '交換に失敗しました');
    }
  }

  /// 特定のデバイスと交換（ワンタップ交換）
  Future<void> exchangeWithDevice(String deviceId) async {
    if (state.artToExchange == null) {
      state = state.copyWith(errorMessage: '交換するドット絵を選択してください');
      return;
    }

    clearMessages();

    try {
      final receivedArt = await _bleService.connectAndExchange(deviceId);

      if (receivedArt != null) {
        state = state.copyWith(
          receivedArt: receivedArt,
          successMessage: 'ドット絵を交換しました！',
        );

        // 履歴に追加
        _addToHistory(state.artToExchange!, receivedArt);
      }
    } catch (e, stackTrace) {
      logger.e('exchangeWithDevice failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: '交換に失敗しました');
    }
  }

  /// 履歴に追加
  void _addToHistory(PixelArt sent, PixelArt received) {
    final entry = ExchangeHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sentArt: sent,
      receivedArt: received,
      exchangedAt: DateTime.now(),
      partnerNickname: received.authorNickname,
    );

    state = state.copyWith(
      exchangeHistory: [entry, ...state.exchangeHistory],
    );
  }

  /// 受信したドット絵をクリア
  void clearReceivedArt() {
    state = state.copyWith(receivedArt: null);
  }

  /// メッセージをクリア
  void clearMessages() {
    state = state.copyWith(
      errorMessage: null,
      successMessage: null,
    );
  }

  /// エラーメッセージをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 成功メッセージをクリア
  void clearSuccess() {
    state = state.copyWith(successMessage: null);
  }

  // ========== Pairing Methods ==========

  /// ペアリングを確認（Numeric Comparison）
  Future<void> confirmPairing({required bool confirmed}) async {
    try {
      await _bleService.confirmPairing(confirmed: confirmed);
    } catch (e, stackTrace) {
      logger.e('confirmPairing failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'ペアリング確認に失敗しました');
    }
  }

  /// パスキーを入力（Passkey Entry）
  Future<void> submitPasskey(String enteredCode) async {
    try {
      final success =
          await _bleService.submitPasskey(enteredCode: enteredCode);
      if (!success) {
        state = state.copyWith(errorMessage: 'パスキーが正しくありません');
      }
    } catch (e, stackTrace) {
      logger.e('submitPasskey failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'パスキー確認に失敗しました');
    }
  }

  /// ペアリングダイアログを閉じる
  void dismissPairingDialog() {
    state = state.copyWith(showPairingDialog: false);
    _bleService.resetPairing();
  }

  /// デバイスがペアリング済みか確認
  bool isPaired(String deviceId) {
    return _bleService.isPaired(deviceId);
  }

  // ========== Getters ==========

  /// スキャン中かどうか
  bool get isScanning =>
      state.connectionState == BleConnectionState.scanning;

  /// 接続中かどうか
  bool get isConnecting =>
      state.connectionState == BleConnectionState.connecting;

  /// 交換中かどうか
  bool get isExchanging =>
      state.connectionState == BleConnectionState.exchanging;

  /// 処理中かどうか
  bool get isBusy =>
      state.connectionState != BleConnectionState.disconnected;

  // ========== Cleanup ==========

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _discoveredDevicesSubscription?.cancel();
    _receivedArtSubscription?.cancel();
    _errorSubscription?.cancel();
    _pairingStateSubscription?.cancel();
    _pairingRequiredSubscription?.cancel();
    super.dispose();
  }
}

/// BleServiceプロバイダー
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// BluetoothViewModelプロバイダー
final bluetoothViewModelProvider =
    StateNotifierProvider<BluetoothViewModel, BluetoothState>((ref) {
  return BluetoothViewModel(ref.watch(bleServiceProvider));
});
