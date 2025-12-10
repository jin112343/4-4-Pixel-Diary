import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/pixel_art.dart';

/// BLE Peripheralイベント
enum BlePeripheralEventType {
  dataReceived,
  deviceConnected,
  deviceDisconnected,
  advertisingStarted,
  advertisingStopped,
}

/// BLE Peripheralイベントデータ
class BlePeripheralEvent {
  const BlePeripheralEvent({
    required this.type,
    this.data,
    this.deviceAddress,
    this.deviceName,
  });

  final BlePeripheralEventType type;
  final String? data;
  final String? deviceAddress;
  final String? deviceName;

  factory BlePeripheralEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String?;
    final type = _parseEventType(typeStr);

    return BlePeripheralEvent(
      type: type,
      data: map['data'] as String?,
      deviceAddress: map['deviceAddress'] as String?,
      deviceName: map['deviceName'] as String?,
    );
  }

  static BlePeripheralEventType _parseEventType(String? typeStr) {
    switch (typeStr) {
      case 'dataReceived':
        return BlePeripheralEventType.dataReceived;
      case 'deviceConnected':
        return BlePeripheralEventType.deviceConnected;
      case 'deviceDisconnected':
        return BlePeripheralEventType.deviceDisconnected;
      case 'advertisingStarted':
        return BlePeripheralEventType.advertisingStarted;
      case 'advertisingStopped':
        return BlePeripheralEventType.advertisingStopped;
      default:
        throw ArgumentError('Unknown event type: $typeStr');
    }
  }
}

/// BLE Peripheral Native Bridge
/// ネイティブのBluetooth Peripheral機能とFlutterを連携
class BlePeripheralNative {
  static const MethodChannel _methodChannel =
      MethodChannel('com.pixeldiary/ble_peripheral');

  static const EventChannel _eventChannel =
      EventChannel('com.pixeldiary/ble_peripheral/events');

  Stream<BlePeripheralEvent>? _eventStream;

  /// イベントストリーム
  Stream<BlePeripheralEvent> get eventStream {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is PlatformException) {
        logger.e('BLE Peripheral error', error: event);
        throw event;
      }

      if (event is Map) {
        return BlePeripheralEvent.fromMap(event);
      }

      throw ArgumentError('Invalid event type: ${event.runtimeType}');
    });

    return _eventStream!;
  }

  /// データ受信ストリーム
  Stream<PixelArt> get onDataReceived {
    return eventStream
        .where((event) => event.type == BlePeripheralEventType.dataReceived)
        .map((event) {
      try {
        final json = jsonDecode(event.data!) as Map<String, dynamic>;
        final art = PixelArt.fromJson(json);

        // ソースをbluetoothに設定
        return art.copyWith(
          source: PixelArtSource.bluetooth,
          receivedAt: DateTime.now(),
        );
      } catch (e, stackTrace) {
        logger.e(
          'Failed to parse received pixel art',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    });
  }

  /// デバイス接続ストリーム
  Stream<String> get onDeviceConnected {
    return eventStream
        .where((event) => event.type == BlePeripheralEventType.deviceConnected)
        .map((event) => event.deviceAddress ?? 'Unknown');
  }

  /// デバイス切断ストリーム
  Stream<String> get onDeviceDisconnected {
    return eventStream
        .where(
          (event) => event.type == BlePeripheralEventType.deviceDisconnected,
        )
        .map((event) => event.deviceAddress ?? 'Unknown');
  }

  /// アドバタイズ開始ストリーム
  Stream<void> get onAdvertisingStarted {
    return eventStream
        .where(
          (event) => event.type == BlePeripheralEventType.advertisingStarted,
        )
        .map((_) => null);
  }

  /// アドバタイズ停止ストリーム
  Stream<void> get onAdvertisingStopped {
    return eventStream
        .where(
          (event) => event.type == BlePeripheralEventType.advertisingStopped,
        )
        .map((_) => null);
  }

  /// アドバタイズ開始
  Future<void> startAdvertising({
    required String nickname,
    required PixelArt artToExchange,
  }) async {
    try {
      final artJson = jsonEncode(artToExchange.toJson());

      await _methodChannel.invokeMethod('startAdvertising', {
        'nickname': nickname,
        'artData': artJson,
      });

      logger.i('BLE advertising started with nickname: $nickname');
    } catch (e, stackTrace) {
      logger.e(
        'startAdvertising failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// アドバタイズ停止
  Future<void> stopAdvertising() async {
    try {
      await _methodChannel.invokeMethod('stopAdvertising');
      logger.i('BLE advertising stopped');
    } catch (e, stackTrace) {
      logger.e(
        'stopAdvertising failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// アドバタイズ状態確認
  Future<bool> isAdvertising() async {
    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isAdvertising') ?? false;
      return result;
    } catch (e, stackTrace) {
      logger.e(
        'isAdvertising failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// 接続デバイス数取得
  Future<int> getConnectedDeviceCount() async {
    try {
      final result = await _methodChannel
              .invokeMethod<int>('getConnectedDeviceCount') ??
          0;
      return result;
    } catch (e, stackTrace) {
      logger.e(
        'getConnectedDeviceCount failed',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }
}
