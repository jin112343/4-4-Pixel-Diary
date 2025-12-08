import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/pixel_art.dart';
import 'ble_constants.dart';
import 'ble_crypto.dart';
import 'ble_pairing_service.dart';

/// Bluetooth権限の状態
enum BlePermissionStatus {
  /// 許可済み
  granted,

  /// 拒否
  denied,

  /// 永続的に拒否（設定から変更が必要）
  permanentlyDenied,

  /// 不明
  unknown,
}

/// BLE接続状態
enum BleConnectionState {
  /// 未接続
  disconnected,

  /// スキャン中
  scanning,

  /// 接続中
  connecting,

  /// 接続済み
  connected,

  /// データ交換中
  exchanging,
}

/// すれ違いで発見したデバイス情報
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.deviceId,
    this.nickname,
    required this.discoveredAt,
    required this.rssi,
  });

  final String deviceId;
  final String? nickname;
  final DateTime discoveredAt;
  final int rssi;
}

/// BLEサービス
/// すれ違い通信によるドット絵交換を実現
class BleService {
  BleService({
    BleCrypto? crypto,
    BlePairingService? pairingService,
  })  : _crypto = crypto ?? BleCrypto(),
        _pairingService = pairingService ?? BlePairingService();

  final BleCrypto _crypto;
  final BlePairingService _pairingService;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final _discoveredDevicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();
  final _receivedArtController = StreamController<PixelArt>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _pairingRequiredController =
      StreamController<PairingInfo>.broadcast();

  BleConnectionState _currentState = BleConnectionState.disconnected;
  final Map<String, DiscoveredDevice> _discoveredDevices = {};

  BluetoothDevice? _connectedDevice;
  PixelArt? _artToExchange;

  // ========== Streams ==========

  /// 接続状態ストリーム
  Stream<BleConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// 発見したデバイス一覧ストリーム
  Stream<List<DiscoveredDevice>> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  /// 受信したドット絵ストリーム
  Stream<PixelArt> get receivedArtStream => _receivedArtController.stream;

  /// エラーストリーム
  Stream<String> get errorStream => _errorController.stream;

  /// ペアリング要求ストリーム
  Stream<PairingInfo> get pairingRequiredStream =>
      _pairingRequiredController.stream;

  /// ペアリング状態ストリーム
  Stream<PairingState> get pairingStateStream =>
      _pairingService.pairingStateStream;

  /// 現在の接続状態
  BleConnectionState get currentState => _currentState;

  /// 現在のペアリング状態
  PairingState get currentPairingState => _pairingService.currentState;

  /// 現在のペアリング情報
  PairingInfo? get currentPairingInfo => _pairingService.currentPairingInfo;

  /// ペアリングサービスへのアクセス
  BlePairingService get pairingService => _pairingService;

  /// 発見したデバイス一覧
  List<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevices.values.toList();

  // ========== Initialization ==========

  /// Bluetoothが利用可能かチェック
  Future<bool> isBluetoothAvailable() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        logger.w('Bluetooth is not supported on this device');
        return false;
      }

      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e, stackTrace) {
      logger.e(
        'isBluetoothAvailable failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Bluetooth権限をチェック・リクエスト
  /// flutter_blue_plusが内部で権限リクエストを処理するため、
  /// スキャン開始時のエラーで権限状態を判断
  Future<BlePermissionStatus> checkAndRequestPermission() async {
    try {
      // Bluetoothがサポートされているか確認
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        return BlePermissionStatus.denied;
      }

      // Bluetoothがオンかどうか確認
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // Bluetoothがオフの場合は権限チェックをスキップ
        return BlePermissionStatus.granted;
      }

      // 短いスキャンを試みて権限状態を確認
      // flutter_blue_plusは必要に応じて自動で権限ダイアログを表示
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 1));
        await FlutterBluePlus.stopScan();
        return BlePermissionStatus.granted;
      } on FlutterBluePlusException catch (e) {
        logger.w('Permission check failed: ${e.code} - ${e.description}');
        // ユーザーが権限を拒否した場合
        if (e.code == FbpErrorCode.userRejected.index) {
          return BlePermissionStatus.denied;
        }
        return BlePermissionStatus.unknown;
      }
    } catch (e, stackTrace) {
      logger.e(
        'checkAndRequestPermission failed',
        error: e,
        stackTrace: stackTrace,
      );
      // 権限関連のエラーの場合は拒否扱い
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || errorStr.contains('denied')) {
        return BlePermissionStatus.denied;
      }
      return BlePermissionStatus.unknown;
    }
  }

  /// 設定アプリを開く（権限を手動で有効化するため）
  Future<void> openAppSettings() async {
    try {
      if (Platform.isAndroid) {
        // Androidの場合、アプリ設定を開く
        await FlutterBluePlus.turnOn();
      }
      // iOSの場合、システムが自動で設定に誘導
    } catch (e, stackTrace) {
      logger.e('openAppSettings failed', error: e, stackTrace: stackTrace);
    }
  }

  /// Bluetoothをオンにするようリクエスト（Android only）
  Future<void> requestBluetoothOn() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e, stackTrace) {
      logger.e(
        'requestBluetoothOn failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ========== Scanning ==========

  /// 周辺デバイスのスキャンを開始
  Future<void> startScanning({
    required PixelArt artToExchange,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_currentState != BleConnectionState.disconnected) {
      logger.w('Already scanning or connected');
      return;
    }

    _artToExchange = artToExchange;
    _discoveredDevices.clear();
    _updateState(BleConnectionState.scanning);

    try {
      // スキャン開始
      await FlutterBluePlus.startScan(
        withServices: [BleConstants.serviceUuid],
        timeout: timeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResults,
        onError: _onScanError,
      );

      logger.i('BLE scanning started');
    } catch (e, stackTrace) {
      logger.e('startScanning failed', error: e, stackTrace: stackTrace);
      _updateState(BleConnectionState.disconnected);
      _errorController.add('スキャン開始に失敗しました');
    }
  }

  /// スキャン停止
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _updateState(BleConnectionState.disconnected);
      logger.i('BLE scanning stopped');
    } catch (e, stackTrace) {
      logger.e('stopScanning failed', error: e, stackTrace: stackTrace);
    }
  }

  void _onScanResults(List<ScanResult> results) {
    for (final result in results) {
      // サービスUUIDでフィルタリング
      final hasService = result.advertisementData.serviceUuids
          .contains(BleConstants.serviceUuid);

      if (!hasService) continue;

      final deviceId = result.device.remoteId.str;
      final nickname = _extractNickname(result.advertisementData);

      final discovered = DiscoveredDevice(
        deviceId: deviceId,
        nickname: nickname,
        discoveredAt: DateTime.now(),
        rssi: result.rssi,
      );

      _discoveredDevices[deviceId] = discovered;
      _discoveredDevicesController.add(discoveredDevices);

      logger.d('Discovered device: $deviceId (rssi: ${result.rssi})');
    }
  }

  String? _extractNickname(AdvertisementData advertisementData) {
    // Local nameからニックネームを取得
    final localName = advertisementData.advName;
    if (localName.startsWith(BleConstants.advertisePrefix)) {
      return localName.substring(BleConstants.advertisePrefix.length);
    }
    return null;
  }

  void _onScanError(Object error) {
    logger.e('Scan error', error: error);
    _errorController.add('スキャン中にエラーが発生しました');
    stopScanning();
  }

  // ========== Connection ==========

  /// デバイスに接続してドット絵を交換
  Future<PixelArt?> connectAndExchange(
    String deviceId, {
    bool skipPairing = false,
  }) async {
    if (_artToExchange == null) {
      logger.e('No art to exchange');
      _errorController.add('交換するドット絵がありません');
      return null;
    }

    final device = _discoveredDevices[deviceId];
    if (device == null) {
      logger.e('Device not found: $deviceId');
      _errorController.add('デバイスが見つかりません');
      return null;
    }

    await stopScanning();
    _updateState(BleConnectionState.connecting);

    try {
      BluetoothDevice? targetDevice;

      // スキャン結果から検索
      await FlutterBluePlus.startScan(
        withServices: [BleConstants.serviceUuid],
        timeout: const Duration(seconds: 5),
      );

      await for (final results in FlutterBluePlus.scanResults) {
        for (final result in results) {
          if (result.device.remoteId.str == deviceId) {
            targetDevice = result.device;
            break;
          }
        }
        if (targetDevice != null) break;
      }

      await FlutterBluePlus.stopScan();

      if (targetDevice == null) {
        throw Exception('Device not found');
      }

      // 接続
      await targetDevice.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = targetDevice;
      _updateState(BleConnectionState.connected);

      // 接続状態の監視
      _connectionSubscription = targetDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      logger.i('Connected to $deviceId');

      // ペアリングチェック（オプション）
      if (BleConstants.requirePairing &&
          !skipPairing &&
          !_pairingService.isPaired(deviceId)) {
        logger.i('Pairing required for device: $deviceId');

        // サービスを検索してペアリングを開始
        final services = await targetDevice.discoverServices();
        BluetoothCharacteristic? pairingChar;

        for (final service in services) {
          if (service.uuid == BleConstants.serviceUuid) {
            for (final char in service.characteristics) {
              if (char.uuid == BleConstants.pairingCharUuid) {
                pairingChar = char;
                break;
              }
            }
          }
        }

        if (pairingChar != null) {
          // ペアリング開始
          final pairingInfo = await _pairingService.initiatePairing(
            device: targetDevice,
            writeChar: pairingChar,
          );

          // ペアリングUIを表示するよう通知
          _pairingRequiredController.add(pairingInfo);

          // ペアリング完了を待つ
          final pairingCompleted = await _waitForPairingCompletion();

          if (!pairingCompleted) {
            logger.w('Pairing failed or rejected');
            _errorController.add('ペアリングに失敗しました');
            await _disconnect();
            return null;
          }

          logger.i('Pairing successful');
        }
      }

      // データ交換
      _updateState(BleConnectionState.exchanging);
      final receivedArt = await _exchangeData(targetDevice);

      // 切断
      await _disconnect();

      if (receivedArt != null) {
        _receivedArtController.add(receivedArt);
      }

      return receivedArt;
    } catch (e, stackTrace) {
      logger.e(
        'connectAndExchange failed',
        error: e,
        stackTrace: stackTrace,
      );
      _errorController.add('接続に失敗しました');
      await _disconnect();
      return null;
    }
  }

  /// ペアリング完了を待つ
  Future<bool> _waitForPairingCompletion() async {
    final completer = Completer<bool>();

    StreamSubscription<PairingState>? subscription;
    subscription = _pairingService.pairingStateStream.listen((state) {
      if (state == PairingState.paired) {
        completer.complete(true);
        subscription?.cancel();
      } else if (state == PairingState.failed) {
        completer.complete(false);
        subscription?.cancel();
      }
    });

    // タイムアウト
    return completer.future.timeout(
      Duration(seconds: BleConstants.pairingConfirmTimeout),
      onTimeout: () {
        subscription?.cancel();
        logger.w('Pairing timed out');
        return false;
      },
    );
  }

  /// ペアリングを確認（UIからコールバック）
  Future<bool> confirmPairing({
    required bool confirmed,
    BluetoothCharacteristic? pairingChar,
  }) async {
    if (pairingChar == null && _connectedDevice != null) {
      // キャラクタリスティックを検索
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid == BleConstants.serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == BleConstants.pairingCharUuid) {
              pairingChar = char;
              break;
            }
          }
        }
      }
    }

    if (pairingChar == null) {
      logger.e('Pairing characteristic not found');
      return false;
    }

    return _pairingService.confirmPairing(
      writeChar: pairingChar,
      confirmed: confirmed,
    );
  }

  /// パスキーを入力して確認
  Future<bool> submitPasskey({
    required String enteredCode,
    BluetoothCharacteristic? pairingChar,
  }) async {
    if (pairingChar == null && _connectedDevice != null) {
      // キャラクタリスティックを検索
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid == BleConstants.serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == BleConstants.pairingCharUuid) {
              pairingChar = char;
              break;
            }
          }
        }
      }
    }

    if (pairingChar == null) {
      logger.e('Pairing characteristic not found');
      return false;
    }

    return _pairingService.submitPasskey(
      writeChar: pairingChar,
      enteredCode: enteredCode,
    );
  }

  /// ペアリングをリセット
  void resetPairing() {
    _pairingService.resetPairing();
  }

  /// デバイスがペアリング済みか確認
  bool isPaired(String deviceId) {
    return _pairingService.isPaired(deviceId);
  }

  Future<PixelArt?> _exchangeData(BluetoothDevice device) async {
    try {
      // サービスを検索
      final services = await device.discoverServices();
      BluetoothService? targetService;

      for (final service in services) {
        if (service.uuid == BleConstants.serviceUuid) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception('Service not found');
      }

      // キャラクタリスティックを取得
      BluetoothCharacteristic? writeChar;
      BluetoothCharacteristic? readChar;

      for (final char in targetService.characteristics) {
        if (char.uuid == BleConstants.writeCharUuid) {
          writeChar = char;
        } else if (char.uuid == BleConstants.readCharUuid) {
          readChar = char;
        }
      }

      if (writeChar == null || readChar == null) {
        throw Exception('Characteristics not found');
      }

      // 自分のデータを送信
      await _sendPixelArt(writeChar);

      // 相手のデータを受信
      final receivedArt = await _receivePixelArt(readChar);

      return receivedArt;
    } catch (e, stackTrace) {
      logger.e('_exchangeData failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _sendPixelArt(BluetoothCharacteristic characteristic) async {
    if (_artToExchange == null) return;

    try {
      // JSONに変換
      final json = _artToExchange!.toJson();
      final jsonString = jsonEncode(json);

      // 暗号化
      final encrypted = _crypto.encrypt(jsonString);

      // 送信
      await characteristic.write(
        Uint8List.fromList(utf8.encode(encrypted)),
        withoutResponse: false,
      );

      logger.d('Pixel art sent');
    } catch (e, stackTrace) {
      logger.e('_sendPixelArt failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<PixelArt?> _receivePixelArt(
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      // Notifyを有効化
      await characteristic.setNotifyValue(true);

      // データを受信（タイムアウト付き）
      final completer = Completer<List<int>>();
      StreamSubscription<List<int>>? subscription;

      subscription = characteristic.lastValueStream.listen((value) {
        if (value.isNotEmpty && !completer.isCompleted) {
          completer.complete(value);
          subscription?.cancel();
        }
      });

      // タイムアウト
      final value = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          subscription?.cancel();
          throw TimeoutException('Receive timeout');
        },
      );

      // 復号化
      final encrypted = utf8.decode(value);
      final decrypted = _crypto.decrypt(encrypted);

      if (decrypted == null) {
        throw Exception('Decryption failed');
      }

      // JSONからPixelArtに変換
      final json = jsonDecode(decrypted) as Map<String, dynamic>;
      final art = PixelArt.fromJson(json);

      // ソースをbluetoothに設定
      final receivedArt = art.copyWith(
        source: PixelArtSource.bluetooth,
        receivedAt: DateTime.now(),
      );

      logger.d('Pixel art received');
      return receivedArt;
    } catch (e, stackTrace) {
      logger.e('_receivePixelArt failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }

      _updateState(BleConnectionState.disconnected);
      logger.i('Disconnected');
    } catch (e, stackTrace) {
      logger.e('_disconnect failed', error: e, stackTrace: stackTrace);
    }
  }

  void _onDisconnected() {
    _connectedDevice = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _updateState(BleConnectionState.disconnected);
    logger.i('Device disconnected');
  }

  // ========== State Management ==========

  void _updateState(BleConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  // ========== Cleanup ==========

  /// リソースを解放
  Future<void> dispose() async {
    await stopScanning();
    await _disconnect();

    await _connectionStateController.close();
    await _discoveredDevicesController.close();
    await _receivedArtController.close();
    await _errorController.close();
    await _pairingRequiredController.close();
    await _pairingService.dispose();
  }
}
