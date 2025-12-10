package com.example.pixeldiary.ble

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// BLE Peripheral用MethodChannel
/// FlutterとネイティブのBluetooth Peripheral機能を連携
class BleMethodChannel(
    private val context: Context,
    methodChannel: MethodChannel,
    eventChannel: EventChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "BleMethodChannel"
    }

    private val peripheralManager = BlePeripheralManager(context)
    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "Event channel listener attached")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "Event channel listener detached")
            }
        })

        // BlePeripheralManagerのコールバック設定
        setupCallbacks()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAdvertising" -> startAdvertising(call, result)
            "stopAdvertising" -> stopAdvertising(result)
            "isAdvertising" -> isAdvertising(result)
            "getConnectedDeviceCount" -> getConnectedDeviceCount(result)
            else -> result.notImplemented()
        }
    }

    /// アドバタイズ開始
    private fun startAdvertising(call: MethodCall, result: MethodChannel.Result) {
        try {
            val nickname = call.argument<String>("nickname")
            val artData = call.argument<String>("artData")

            if (nickname == null || artData == null) {
                result.error("INVALID_ARGUMENTS", "nickname and artData are required", null)
                return
            }

            Log.d(TAG, "Starting advertising with nickname: $nickname")

            val success = peripheralManager.startAdvertising(nickname, artData)

            if (success) {
                result.success(true)
            } else {
                result.error("START_FAILED", "Failed to start advertising", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting advertising", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    /// アドバタイズ停止
    private fun stopAdvertising(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Stopping advertising")
            peripheralManager.stopAdvertising()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping advertising", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    /// アドバタイズ状態確認
    private fun isAdvertising(result: MethodChannel.Result) {
        try {
            val advertising = peripheralManager.isAdvertising()
            result.success(advertising)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking advertising status", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    /// 接続デバイス数取得
    private fun getConnectedDeviceCount(result: MethodChannel.Result) {
        try {
            val count = peripheralManager.getConnectedDeviceCount()
            result.success(count)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting connected device count", e)
            result.error("EXCEPTION", e.message, null)
        }
    }

    /// コールバック設定
    private fun setupCallbacks() {
        // データ受信時
        peripheralManager.onDataReceived = { data, device ->
            Log.d(TAG, "Data received from ${device.address}")
            eventSink?.success(
                mapOf(
                    "type" to "dataReceived",
                    "data" to data,
                    "deviceAddress" to device.address,
                    "deviceName" to (device.name ?: "Unknown")
                )
            )
        }

        // デバイス接続時
        peripheralManager.onDeviceConnected = { device ->
            Log.d(TAG, "Device connected: ${device.address}")
            eventSink?.success(
                mapOf(
                    "type" to "deviceConnected",
                    "deviceAddress" to device.address,
                    "deviceName" to (device.name ?: "Unknown")
                )
            )
        }

        // デバイス切断時
        peripheralManager.onDeviceDisconnected = { device ->
            Log.d(TAG, "Device disconnected: ${device.address}")
            eventSink?.success(
                mapOf(
                    "type" to "deviceDisconnected",
                    "deviceAddress" to device.address,
                    "deviceName" to (device.name ?: "Unknown")
                )
            )
        }

        // エラー時
        peripheralManager.onError = { message ->
            Log.e(TAG, "Peripheral error: $message")
            eventSink?.error("BLE_ERROR", message, null)
        }
    }

    /// クリーンアップ
    fun cleanup() {
        peripheralManager.cleanup()
        eventSink = null
    }
}
