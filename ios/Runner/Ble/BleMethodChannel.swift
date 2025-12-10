import Foundation
import Flutter
import CoreBluetooth

/// BLE Peripheral用MethodChannel
/// FlutterとネイティブのBluetooth Peripheral機能を連携
class BleMethodChannel: NSObject {
    private static let methodChannelName = "com.pixeldiary/ble_peripheral"
    private static let eventChannelName = "com.pixeldiary/ble_peripheral/events"

    private let peripheralManager: BlePeripheralManager
    private var eventSink: FlutterEventSink?

    init(binaryMessenger: FlutterBinaryMessenger) {
        self.peripheralManager = BlePeripheralManager()
        super.init()

        // MethodChannel設定
        let methodChannel = FlutterMethodChannel(
            name: BleMethodChannel.methodChannelName,
            binaryMessenger: binaryMessenger
        )
        methodChannel.setMethodCallHandler(handleMethodCall)

        // EventChannel設定
        let eventChannel = FlutterEventChannel(
            name: BleMethodChannel.eventChannelName,
            binaryMessenger: binaryMessenger
        )
        eventChannel.setStreamHandler(self)

        // コールバック設定
        setupCallbacks()
    }

    // MARK: - Method Call Handler

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            startAdvertising(call, result: result)
        case "stopAdvertising":
            stopAdvertising(result: result)
        case "isAdvertising":
            isAdvertising(result: result)
        case "getConnectedDeviceCount":
            getConnectedDeviceCount(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Implementations

    /// アドバタイズ開始
    private func startAdvertising(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let nickname = args["nickname"] as? String,
              let artData = args["artData"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "nickname and artData are required",
                details: nil
            ))
            return
        }

        print("[BleMethodChannel] Starting advertising with nickname: \(nickname)")

        let success = peripheralManager.startAdvertising(nickname: nickname, artData: artData)

        if success {
            result(true)
        } else {
            result(FlutterError(
                code: "START_FAILED",
                message: "Failed to start advertising",
                details: nil
            ))
        }
    }

    /// アドバタイズ停止
    private func stopAdvertising(result: @escaping FlutterResult) {
        print("[BleMethodChannel] Stopping advertising")
        peripheralManager.stopAdvertising()
        result(true)
    }

    /// アドバタイズ状態確認
    private func isAdvertising(result: @escaping FlutterResult) {
        let advertising = peripheralManager.getIsAdvertising()
        result(advertising)
    }

    /// 接続デバイス数取得
    private func getConnectedDeviceCount(result: @escaping FlutterResult) {
        let count = peripheralManager.getConnectedDeviceCount()
        result(count)
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        // データ受信時
        peripheralManager.onDataReceived = { [weak self] data, central in
            print("[BleMethodChannel] Data received from central")
            self?.eventSink?([
                "type": "dataReceived",
                "data": data,
                "deviceAddress": central.identifier.uuidString,
                "deviceName": "Unknown"
            ])
        }

        // デバイス接続時
        peripheralManager.onDeviceConnected = { [weak self] central in
            print("[BleMethodChannel] Device connected")
            self?.eventSink?([
                "type": "deviceConnected",
                "deviceAddress": central.identifier.uuidString,
                "deviceName": "Unknown"
            ])
        }

        // デバイス切断時
        peripheralManager.onDeviceDisconnected = { [weak self] central in
            print("[BleMethodChannel] Device disconnected")
            self?.eventSink?([
                "type": "deviceDisconnected",
                "deviceAddress": central.identifier.uuidString,
                "deviceName": "Unknown"
            ])
        }

        // エラー時
        peripheralManager.onError = { [weak self] message in
            print("[BleMethodChannel] Peripheral error: \(message)")
            self?.eventSink?(FlutterError(
                code: "BLE_ERROR",
                message: message,
                details: nil
            ))
        }

        // アドバタイズ開始時
        peripheralManager.onAdvertisingStarted = { [weak self] in
            print("[BleMethodChannel] Advertising started")
            self?.eventSink?([
                "type": "advertisingStarted"
            ])
        }

        // アドバタイズ停止時
        peripheralManager.onAdvertisingStopped = { [weak self] in
            print("[BleMethodChannel] Advertising stopped")
            self?.eventSink?([
                "type": "advertisingStopped"
            ])
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        peripheralManager.cleanup()
        eventSink = nil
    }
}

// MARK: - FlutterStreamHandler

extension BleMethodChannel: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        print("[BleMethodChannel] Event channel listener attached")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        print("[BleMethodChannel] Event channel listener detached")
        return nil
    }
}
