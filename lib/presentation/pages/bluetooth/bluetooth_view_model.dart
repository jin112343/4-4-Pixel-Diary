import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../providers/app_providers.dart';
import '../../../services/bluetooth/ble_dual_role_service.dart';
import '../../../services/bluetooth/ble_pairing_service.dart';
import '../../../services/bluetooth/ble_peripheral_native.dart';
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

    // ========== Peripheral関連（Dual Role追加） ==========

    /// Dual Mode（Central + Peripheral）が動作中か
    @Default(false) bool isDualMode,

    /// Peripheralアドバタイズ中か
    @Default(false) bool isAdvertising,

    /// Peripheral側の接続デバイス数
    @Default(0) int peripheralConnectedCount,

    /// アドバタイズに使用するニックネーム
    String? nickname,
  }) = _BluetoothState;
}

/// Bluetooth画面のViewModel
class BluetoothViewModel extends StateNotifier<BluetoothState> {
  BluetoothViewModel(
    this._bleService,
    this._dualRoleService,
    this._localStorage,
  ) : super(const BluetoothState()) {
    _initialize();
  }

  final BleService _bleService;
  final BleDualRoleService _dualRoleService;
  final LocalStorage _localStorage;

  StreamSubscription<BleConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<DiscoveredDevice>>? _discoveredDevicesSubscription;
  StreamSubscription<PixelArt>? _receivedArtSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<PairingState>? _pairingStateSubscription;
  StreamSubscription<PairingInfo>? _pairingRequiredSubscription;

  // Dual Role用のサブスクリプション
  StreamSubscription<PixelArt>? _dualRoleReceivedArtSubscription;

  /// 初期化
  Future<void> _initialize() async {
    try {
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
    } catch (e, stackTrace) {
      logger.e(
        'BluetoothViewModel initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
      // 初期化エラーでも画面は表示できるように、デフォルト状態のまま継続
      state = state.copyWith(
        isBluetoothAvailable: false,
        errorMessage: 'Bluetooth初期化に失敗しました',
      );
    }
  }

  /// 権限をチェック・リクエスト
  Future<void> checkPermission() async {
    try {
      final status = await _bleService.checkAndRequestPermission();
      state = state.copyWith(
        permissionStatus: status,
        isPermissionDenied: status == BlePermissionStatus.denied ||
            status == BlePermissionStatus.permanentlyDenied,
      );
    } catch (e, stackTrace) {
      logger.e(
        'checkPermission failed',
        error: e,
        stackTrace: stackTrace,
      );
      // 権限チェックに失敗しても画面は表示できるように
      state = state.copyWith(
        permissionStatus: BlePermissionStatus.unknown,
        isPermissionDenied: false,
      );
    }
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

    // アルバムに保存
    _saveToAlbum(art);

    // 履歴に追加
    if (state.artToExchange != null) {
      _addToHistory(state.artToExchange!, art);
    }
  }

  /// 受信したドット絵をアルバムに保存
  Future<void> _saveToAlbum(PixelArt art) async {
    try {
      await _localStorage.addToAlbum(art);
      logger.i('Saved received art to album: ${art.id}');
    } catch (e, stackTrace) {
      logger.e('Failed to save to album', error: e, stackTrace: stackTrace);
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

  /// ニックネームを設定
  void setNickname(String nickname) {
    state = state.copyWith(nickname: nickname);
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

  // ========== Dual Role Methods ==========

  /// Dual Mode（Central + Peripheral）を開始
  Future<void> startDualMode() async {
    if (state.artToExchange == null) {
      state = state.copyWith(errorMessage: '交換するドット絵を選択してください');
      return;
    }

    if (!state.isBluetoothAvailable) {
      state = state.copyWith(errorMessage: 'Bluetoothが利用できません');
      return;
    }

    final nickname = state.nickname ?? 'ゲスト';

    clearMessages();

    try {
      // Dual Role Serviceを使用してCentral + Peripheral同時起動
      await _dualRoleService.startDualMode(
        nickname: nickname,
        artToExchange: state.artToExchange!,
      );

      // Dual Role受信データを監視
      _dualRoleReceivedArtSubscription =
          _dualRoleService.receivedArtStream.listen(_onArtReceived);

      // 状態を更新
      state = state.copyWith(
        isDualMode: true,
        connectionState: BleConnectionState.scanning,
      );

      // Peripheral状態を定期的にポーリング
      _startPeripheralStatePolling();

      logger.i('Dual mode started');
    } catch (e, stackTrace) {
      logger.e('startDualMode failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'Dual Mode開始に失敗しました');
    }
  }

  /// Dual Modeを停止
  Future<void> stopDualMode() async {
    try {
      await _dualRoleService.stopDualMode();
      await _dualRoleReceivedArtSubscription?.cancel();
      _dualRoleReceivedArtSubscription = null;

      _stopPeripheralStatePolling();

      state = state.copyWith(
        isDualMode: false,
        isAdvertising: false,
        peripheralConnectedCount: 0,
        connectionState: BleConnectionState.disconnected,
      );

      logger.i('Dual mode stopped');
    } catch (e, stackTrace) {
      logger.e('stopDualMode failed', error: e, stackTrace: stackTrace);
      state = state.copyWith(errorMessage: 'Dual Mode停止に失敗しました');
    }
  }

  Timer? _peripheralStatePollingTimer;

  /// Peripheral状態の定期ポーリング開始
  void _startPeripheralStatePolling() {
    _peripheralStatePollingTimer?.cancel();
    _peripheralStatePollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updatePeripheralState(),
    );
  }

  /// Peripheral状態の定期ポーリング停止
  void _stopPeripheralStatePolling() {
    _peripheralStatePollingTimer?.cancel();
    _peripheralStatePollingTimer = null;
  }

  /// Peripheral状態を更新
  Future<void> _updatePeripheralState() async {
    if (!state.isDualMode) return;

    try {
      final isAdvertising = await _dualRoleService.peripheralAdvertising;
      final connectedCount = await _dualRoleService.peripheralConnectedCount;

      state = state.copyWith(
        isAdvertising: isAdvertising,
        peripheralConnectedCount: connectedCount,
      );
    } catch (e) {
      // ポーリング中のエラーは無視
      logger.d('Peripheral state update error: $e');
    }
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

        // アルバムに保存
        _saveToAlbum(receivedArt);

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

        // アルバムに保存
        _saveToAlbum(receivedArt);

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
    _dualRoleReceivedArtSubscription?.cancel();
    _peripheralStatePollingTimer?.cancel();
    super.dispose();
  }
}

/// BleServiceプロバイダー（ローカル用、app_providersのappBleServiceProviderと重複）
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// BluetoothViewModelプロバイダー
final bluetoothViewModelProvider =
    StateNotifierProvider<BluetoothViewModel, BluetoothState>((ref) {
  // app_providersから取得
  final bleService = ref.watch(bleServiceProvider);
  final localStorage = ref.watch(localStorageProvider);

  // BleDualRoleServiceを手動で構築（app_providersにもあるが、依存関係を明示）
  // 注: 本来はapp_providersのbleDualRoleServiceProviderを使用すべきだが、
  // bluetooth_view_model.dart内で完結させるためにここで構築
  final dualRoleService = BleDualRoleService(
    centralService: bleService,
    peripheralNative: BlePeripheralNative(),
  );

  // ViewModelの破棄時にDual Roleサービスも破棄
  ref.onDispose(() => dualRoleService.dispose());

  return BluetoothViewModel(bleService, dualRoleService, localStorage);
});
