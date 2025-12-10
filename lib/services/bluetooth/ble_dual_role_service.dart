import 'dart:async';

import '../../core/utils/logger.dart';
import '../../domain/entities/pixel_art.dart';
import 'ble_peripheral_native.dart';
import 'ble_service.dart';

/// BLE Dual Role Service
/// Central（スキャン）とPeripheral（アドバタイズ）を同時に動作させる
class BleDualRoleService {
  BleDualRoleService({
    required BleService centralService,
    required BlePeripheralNative peripheralNative,
  })  : _centralService = centralService,
        _peripheralNative = peripheralNative;

  final BleService _centralService;
  final BlePeripheralNative _peripheralNative;

  final _receivedArtController = StreamController<PixelArt>.broadcast();

  /// 受信したドット絵ストリーム（Central + Peripheral両方）
  Stream<PixelArt> get receivedArtStream => _receivedArtController.stream;

  StreamSubscription<PixelArt>? _centralSubscription;
  StreamSubscription<PixelArt>? _peripheralSubscription;

  bool _isDualMode = false;

  /// Dual Modeが動作中か
  bool get isDualMode => _isDualMode;

  /// すれ違い交換モード開始（Central + Peripheral同時動作）
  Future<void> startDualMode({
    required String nickname,
    required PixelArt artToExchange,
  }) async {
    if (_isDualMode) {
      logger.w('Dual mode already running');
      return;
    }

    try {
      logger.i('Starting dual mode (Central + Peripheral)');

      // 1. Peripheral開始（自分をアドバタイズ）
      await _peripheralNative.startAdvertising(
        nickname: nickname,
        artToExchange: artToExchange,
      );

      // 2. Central開始（相手をスキャン）
      await _centralService.startScanning(
        artToExchange: artToExchange,
      );

      // 3. データ受信を統合
      _setupReceivedArtListeners();

      _isDualMode = true;

      logger.i('Dual mode started successfully');
    } catch (e, stackTrace) {
      logger.e(
        'Failed to start dual mode',
        error: e,
        stackTrace: stackTrace,
      );
      // 失敗時はクリーンアップ
      await _stopWithoutLogging();
      rethrow;
    }
  }

  /// すれ違い交換モード停止
  Future<void> stopDualMode() async {
    if (!_isDualMode) {
      return;
    }

    logger.i('Stopping dual mode');
    await _stopWithoutLogging();
    logger.i('Dual mode stopped');
  }

  /// 内部停止処理（ロギングなし）
  Future<void> _stopWithoutLogging() async {
    try {
      // Central停止
      await _centralService.stopScanning();

      // Peripheral停止
      await _peripheralNative.stopAdvertising();

      // サブスクリプションキャンセル
      await _centralSubscription?.cancel();
      await _peripheralSubscription?.cancel();
      _centralSubscription = null;
      _peripheralSubscription = null;

      _isDualMode = false;
    } catch (e, stackTrace) {
      logger.e(
        'Error stopping dual mode',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 受信データリスナー設定
  void _setupReceivedArtListeners() {
    // Centralからの受信
    _centralSubscription = _centralService.receivedArtStream.listen(
      (art) {
        logger.d('Received art via Central: ${art.id}');
        _receivedArtController.add(art);
      },
      onError: (error, stackTrace) {
        logger.e(
          'Central received art error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    // Peripheralからの受信
    _peripheralSubscription = _peripheralNative.onDataReceived.listen(
      (art) {
        logger.d('Received art via Peripheral: ${art.id}');
        _receivedArtController.add(art);
      },
      onError: (error, stackTrace) {
        logger.e(
          'Peripheral received art error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Central状態
  BleConnectionState get centralState => _centralService.currentState;

  /// Peripheralアドバタイズ中か
  Future<bool> get peripheralAdvertising => _peripheralNative.isAdvertising();

  /// 接続デバイス数（Peripheral）
  Future<int> get peripheralConnectedCount =>
      _peripheralNative.getConnectedDeviceCount();

  /// 発見したデバイス一覧（Central）
  List<DiscoveredDevice> get discoveredDevices =>
      _centralService.discoveredDevices;

  /// リソース解放
  Future<void> dispose() async {
    await stopDualMode();
    await _receivedArtController.close();
  }
}
