import Foundation
import CoreBluetooth

/// BLE Peripheral Manager
/// アドバタイズとGATTサーバーを管理
class BlePeripheralManager: NSObject {
    // MARK: - UUIDs

    // PixelDiary サービスUUID
    static let serviceUUID = CBUUID(string: "4F4D4449-5843-4841-4E47-455F53455256")

    // Write Characteristic UUID
    static let writeCharUUID = CBUUID(string: "4F4D4449-5843-4841-4E47-455F575249")

    // Read Characteristic UUID (Notify)
    static let readCharUUID = CBUUID(string: "4F4D4449-5843-4841-4E47-455F52454144")

    // Pairing Characteristic UUID
    static let pairingCharUUID = CBUUID(string: "4F4D4449-5843-4841-4E47-455F50414952")

    // アドバタイズプレフィックス
    private static let advertisePrefix = "PD_"

    // MARK: - Properties

    private var peripheralManager: CBPeripheralManager!
    private var service: CBMutableService?
    private var writeCharacteristic: CBMutableCharacteristic?
    private var readCharacteristic: CBMutableCharacteristic?
    private var pairingCharacteristic: CBMutableCharacteristic?

    private var isAdvertising = false
    private var currentNickname: String?
    private var currentArtData: String?

    // コールバック
    var onDataReceived: ((String, CBCentral) -> Void)?
    var onDeviceConnected: ((CBCentral) -> Void)?
    var onDeviceDisconnected: ((CBCentral) -> Void)?
    var onError: ((String) -> Void)?
    var onAdvertisingStarted: (() -> Void)?
    var onAdvertisingStopped: (() -> Void)?

    // 接続中のデバイス
    private var connectedCentrals = Set<CBCentral>()

    // MARK: - Initialization

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    /// アドバタイズ開始
    func startAdvertising(nickname: String, artData: String) -> Bool {
        guard peripheralManager.state == .poweredOn else {
            print("[BlePeripheralManager] Bluetooth is not powered on")
            onError?("Bluetoothがオンになっていません")
            return false
        }

        if isAdvertising {
            print("[BlePeripheralManager] Already advertising")
            return true
        }

        currentNickname = nickname
        currentArtData = artData

        // サービスセットアップ
        setupService()

        // アドバタイズデータ
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BlePeripheralManager.serviceUUID],
            CBAdvertisementDataLocalNameKey: "\(BlePeripheralManager.advertisePrefix)\(nickname)"
        ]

        // アドバタイズ開始
        peripheralManager.startAdvertising(advertisementData)
        print("[BlePeripheralManager] Advertising started with nickname: \(nickname)")

        return true
    }

    /// アドバタイズ停止
    func stopAdvertising() {
        if !isAdvertising {
            return
        }

        peripheralManager.stopAdvertising()

        // サービス削除
        if let service = service {
            peripheralManager.remove(service)
        }

        service = nil
        writeCharacteristic = nil
        readCharacteristic = nil
        pairingCharacteristic = nil
        connectedCentrals.removeAll()

        isAdvertising = false
        print("[BlePeripheralManager] Advertising stopped")

        onAdvertisingStopped?()
    }

    /// サービスセットアップ
    private func setupService() {
        // サービス作成
        let service = CBMutableService(type: BlePeripheralManager.serviceUUID, primary: true)

        // Write Characteristic
        writeCharacteristic = CBMutableCharacteristic(
            type: BlePeripheralManager.writeCharUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: .writeable
        )

        // Read Characteristic (Notify)
        readCharacteristic = CBMutableCharacteristic(
            type: BlePeripheralManager.readCharUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: .readable
        )

        // Pairing Characteristic
        pairingCharacteristic = CBMutableCharacteristic(
            type: BlePeripheralManager.pairingCharUUID,
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        // キャラクタリスティック追加
        service.characteristics = [
            writeCharacteristic!,
            readCharacteristic!,
            pairingCharacteristic!
        ]

        // サービス追加
        peripheralManager.add(service)
        self.service = service

        print("[BlePeripheralManager] Service setup completed")
    }

    /// Centralにデータ送信（Notify）
    private func sendDataToCentral(_ central: CBCentral) {
        guard let artData = currentArtData else {
            return
        }

        guard let characteristic = readCharacteristic else {
            return
        }

        guard let data = artData.data(using: .utf8) else {
            return
        }

        let success = peripheralManager.updateValue(
            data,
            for: characteristic,
            onSubscribedCentrals: [central]
        )

        if success {
            print("[BlePeripheralManager] Notified data to central: \(data.count) bytes")
        } else {
            print("[BlePeripheralManager] Failed to notify data (queue full)")
        }
    }

    /// アドバタイズ状態確認
    func getIsAdvertising() -> Bool {
        return isAdvertising
    }

    /// 接続デバイス数
    func getConnectedDeviceCount() -> Int {
        return connectedCentrals.count
    }

    /// クリーンアップ
    func cleanup() {
        stopAdvertising()
        currentNickname = nil
        currentArtData = nil
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BlePeripheralManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("[BlePeripheralManager] Bluetooth powered on")
        case .poweredOff:
            print("[BlePeripheralManager] Bluetooth powered off")
            if isAdvertising {
                isAdvertising = false
                onAdvertisingStopped?()
            }
        case .resetting:
            print("[BlePeripheralManager] Bluetooth resetting")
        case .unauthorized:
            print("[BlePeripheralManager] Bluetooth unauthorized")
            onError?("Bluetooth権限がありません")
        case .unsupported:
            print("[BlePeripheralManager] Bluetooth not supported")
            onError?("このデバイスはBluetoothをサポートしていません")
        case .unknown:
            print("[BlePeripheralManager] Bluetooth state unknown")
        @unknown default:
            print("[BlePeripheralManager] Bluetooth unknown state")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("[BlePeripheralManager] Advertising failed: \(error.localizedDescription)")
            onError?("アドバタイズ失敗: \(error.localizedDescription)")
            isAdvertising = false
        } else {
            print("[BlePeripheralManager] Advertising started successfully")
            isAdvertising = true
            onAdvertisingStarted?()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("[BlePeripheralManager] Failed to add service: \(error.localizedDescription)")
            onError?("サービス追加失敗: \(error.localizedDescription)")
        } else {
            print("[BlePeripheralManager] Service added successfully")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == BlePeripheralManager.writeCharUUID {
                // データ受信
                if let value = request.value, let receivedData = String(data: value, encoding: .utf8) {
                    print("[BlePeripheralManager] Received data: \(receivedData.prefix(50))...")

                    // 受信データをコールバック
                    onDataReceived?(receivedData, request.central)

                    // Note: データ送信はdidSubscribeToで既に実行済みのため、ここでは送信しない
                    // これにより二重送信を防ぐ
                }

                // レスポンス送信
                peripheral.respond(to: request, withResult: .success)
            } else {
                print("[BlePeripheralManager] Unknown characteristic write: \(request.characteristic.uuid)")
                peripheral.respond(to: request, withResult: .requestNotSupported)
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == BlePeripheralManager.readCharUUID {
            // 自分のデータを返す
            if let artData = currentArtData, let data = artData.data(using: .utf8) {
                if request.offset > data.count {
                    peripheral.respond(to: request, withResult: .invalidOffset)
                    return
                }

                let range = request.offset..<data.count
                request.value = data.subdata(in: range)

                print("[BlePeripheralManager] Read request, sending \(request.value?.count ?? 0) bytes")
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .unlikelyError)
            }
        } else {
            print("[BlePeripheralManager] Unknown characteristic read: \(request.characteristic.uuid)")
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[BlePeripheralManager] Central subscribed to characteristic: \(characteristic.uuid)")
        connectedCentrals.insert(central)
        onDeviceConnected?(central)
        
        // Readキャラクタリスティックに購読した時、自動的にデータを送信
        // これにより、Central側がNotify購読後すぐにデータを受信できる
        if characteristic.uuid == BlePeripheralManager.readCharUUID {
            print("[BlePeripheralManager] Central subscribed to read characteristic, sending data")
            sendDataToCentral(central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[BlePeripheralManager] Central unsubscribed from characteristic: \(characteristic.uuid)")
        connectedCentrals.remove(central)
        onDeviceDisconnected?(central)
    }
}
