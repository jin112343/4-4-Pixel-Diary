package com.example.pixeldiary.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.nio.charset.StandardCharsets
import java.util.UUID

/// BLE Peripheral Manager
/// アドバタイズとGATTサーバーを管理
class BlePeripheralManager(private val context: Context) {
    companion object {
        private const val TAG = "BlePeripheralManager"

        // PixelDiary サービスUUID
        val SERVICE_UUID: UUID = UUID.fromString("4f4d4449-5843-4841-4e47-455f53455256")

        // Write Characteristic UUID
        val WRITE_CHAR_UUID: UUID = UUID.fromString("4f4d4449-5843-4841-4e47-455f575249")

        // Read Characteristic UUID (Notify)
        val READ_CHAR_UUID: UUID = UUID.fromString("4f4d4449-5843-4841-4e47-455f52454144")

        // Pairing Characteristic UUID
        val PAIRING_CHAR_UUID: UUID = UUID.fromString("4f4d4449-5843-4841-4e47-455f50414952")

        // アドバタイズプレフィックス
        private const val ADVERTISE_PREFIX = "PD_"

        // Client Characteristic Configuration Descriptor
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val bluetoothManager: BluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager

    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val advertiser: BluetoothLeAdvertiser? = bluetoothAdapter?.bluetoothLeAdvertiser

    private var gattServer: BluetoothGattServer? = null
    private var isAdvertising = false
    private var currentNickname: String? = null
    private var currentArtData: String? = null

    // コールバック
    var onDataReceived: ((data: String, device: BluetoothDevice) -> Unit)? = null
    var onDeviceConnected: ((device: BluetoothDevice) -> Unit)? = null
    var onDeviceDisconnected: ((device: BluetoothDevice) -> Unit)? = null
    var onError: ((message: String) -> Unit)? = null

    // 接続中のデバイス
    private val connectedDevices = mutableSetOf<BluetoothDevice>()

    /// アドバタイズ開始
    fun startAdvertising(nickname: String, artData: String): Boolean {
        if (advertiser == null) {
            Log.e(TAG, "Bluetooth LE Advertiser not available")
            onError?.invoke("アドバタイズ機能が利用できません")
            return false
        }

        if (isAdvertising) {
            Log.w(TAG, "Already advertising")
            return true
        }

        currentNickname = nickname
        currentArtData = artData

        // GATTサーバーをセットアップ
        if (!setupGattServer()) {
            return false
        }

        // アドバタイズ設定
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0) // 無期限
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        // Bluetoothアダプタのローカル名を設定（アドバタイズに含めるため）
        val localName = "$ADVERTISE_PREFIX$nickname"
        try {
            bluetoothAdapter?.name = localName
            Log.d(TAG, "Bluetooth local name set to: $localName")
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot set Bluetooth name due to missing permission", e)
        }

        // アドバタイズデータ（サービスUUID）
        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .build()

        // スキャンレスポンスデータ（ニックネームをローカル名として含める）
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)  // ローカル名を含める
            .setIncludeTxPowerLevel(false)
            .build()

        // アドバタイズ開始
        try {
            advertiser.startAdvertising(settings, data, scanResponse, advertiseCallback)
            Log.i(TAG, "Advertising started with nickname: $nickname")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start advertising", e)
            onError?.invoke("アドバタイズ開始に失敗しました: ${e.message}")
            return false
        }
    }

    /// アドバタイズ停止
    fun stopAdvertising() {
        if (!isAdvertising) {
            return
        }

        try {
            advertiser?.stopAdvertising(advertiseCallback)
            isAdvertising = false
            Log.i(TAG, "Advertising stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop advertising", e)
        }

        // GATTサーバークローズ
        closeGattServer()
    }

    /// GATTサーバーセットアップ
    private fun setupGattServer(): Boolean {
        try {
            gattServer = bluetoothManager.openGattServer(context, gattServerCallback)

            if (gattServer == null) {
                Log.e(TAG, "Failed to open GATT server")
                onError?.invoke("GATTサーバー起動に失敗しました")
                return false
            }

            // サービス作成
            val service = BluetoothGattService(
                SERVICE_UUID,
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )

            // Write Characteristic
            val writeChar = BluetoothGattCharacteristic(
                WRITE_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            service.addCharacteristic(writeChar)

            // Read Characteristic (Notify)
            val readChar = BluetoothGattCharacteristic(
                READ_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_READ or
                        BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_READ
            )

            // CCCD Descriptor（Notify有効化用）
            val cccdDescriptor = BluetoothGattDescriptor(
                CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or
                        BluetoothGattDescriptor.PERMISSION_WRITE
            )
            readChar.addDescriptor(cccdDescriptor)
            service.addCharacteristic(readChar)

            // Pairing Characteristic（将来の拡張用）
            val pairingChar = BluetoothGattCharacteristic(
                PAIRING_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or
                        BluetoothGattCharacteristic.PROPERTY_READ,
                BluetoothGattCharacteristic.PERMISSION_WRITE or
                        BluetoothGattCharacteristic.PERMISSION_READ
            )
            service.addCharacteristic(pairingChar)

            // サービス追加
            gattServer?.addService(service)

            Log.i(TAG, "GATT server setup completed")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup GATT server", e)
            onError?.invoke("GATTサーバーセットアップに失敗しました: ${e.message}")
            return false
        }
    }

    /// GATTサーバークローズ
    private fun closeGattServer() {
        try {
            // 接続中のデバイスを切断
            connectedDevices.forEach { device ->
                gattServer?.cancelConnection(device)
            }
            connectedDevices.clear()

            gattServer?.close()
            gattServer = null
            Log.i(TAG, "GATT server closed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close GATT server", e)
        }
    }

    /// アドバタイズコールバック
    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            isAdvertising = true
            Log.i(TAG, "Advertise started successfully")
        }

        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
            val message = when (errorCode) {
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "データサイズが大きすぎます"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "アドバタイザーが多すぎます"
                ADVERTISE_FAILED_ALREADY_STARTED -> "既にアドバタイズ中です"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "内部エラーが発生しました"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "機能がサポートされていません"
                else -> "不明なエラー: $errorCode"
            }
            Log.e(TAG, "Advertise failed: $message")
            onError?.invoke("アドバタイズ失敗: $message")
        }
    }

    /// GATTサーバーコールバック
    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(
            device: BluetoothDevice,
            status: Int,
            newState: Int
        ) {
            when (newState) {
                BluetoothGatt.STATE_CONNECTED -> {
                    connectedDevices.add(device)
                    Log.i(TAG, "Device connected: ${device.address}")
                    onDeviceConnected?.invoke(device)
                }
                BluetoothGatt.STATE_DISCONNECTED -> {
                    connectedDevices.remove(device)
                    Log.i(TAG, "Device disconnected: ${device.address}")
                    onDeviceDisconnected?.invoke(device)
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            when (characteristic.uuid) {
                WRITE_CHAR_UUID -> {
                    // データ受信
                    val receivedData = String(value, StandardCharsets.UTF_8)
                    Log.d(TAG, "Received data from ${device.address}: ${receivedData.take(50)}...")

                    // 受信データをコールバック
                    onDataReceived?.invoke(receivedData, device)

                    // 自分のデータを送信
                    sendDataToDevice(device)

                    // レスポンス送信
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_SUCCESS,
                            offset,
                            value
                        )
                    }
                }
                else -> {
                    Log.w(TAG, "Unknown characteristic write: ${characteristic.uuid}")
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_FAILURE,
                            offset,
                            null
                        )
                    }
                }
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            when (characteristic.uuid) {
                READ_CHAR_UUID -> {
                    // 自分のデータを返す
                    val data = currentArtData?.toByteArray(StandardCharsets.UTF_8) ?: byteArrayOf()
                    Log.d(TAG, "Read request from ${device.address}, sending ${data.size} bytes")

                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        data.copyOfRange(offset, data.size)
                    )
                }
                else -> {
                    Log.w(TAG, "Unknown characteristic read: ${characteristic.uuid}")
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_FAILURE,
                        offset,
                        null
                    )
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (descriptor.uuid == CCCD_UUID) {
                // Notify有効化
                Log.d(TAG, "CCCD write request from ${device.address}")

                if (responseNeeded) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        offset,
                        value
                    )
                }
            } else {
                Log.w(TAG, "Unknown descriptor write: ${descriptor.uuid}")
                if (responseNeeded) {
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_FAILURE,
                        offset,
                        null
                    )
                }
            }
        }
    }

    /// デバイスにデータ送信（Notify）
    private fun sendDataToDevice(device: BluetoothDevice) {
        val data = currentArtData?.toByteArray(StandardCharsets.UTF_8) ?: return

        val service = gattServer?.getService(SERVICE_UUID) ?: return
        val characteristic = service.getCharacteristic(READ_CHAR_UUID) ?: return

        characteristic.value = data

        try {
            gattServer?.notifyCharacteristicChanged(device, characteristic, false)
            Log.d(TAG, "Notified data to ${device.address}: ${data.size} bytes")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify data", e)
        }
    }

    /// クリーンアップ
    fun cleanup() {
        stopAdvertising()
        closeGattServer()
        connectedDevices.clear()
        currentNickname = null
        currentArtData = null
    }

    /// 状態確認
    fun isAdvertising(): Boolean = isAdvertising

    /// 接続デバイス数
    fun getConnectedDeviceCount(): Int = connectedDevices.size
}
