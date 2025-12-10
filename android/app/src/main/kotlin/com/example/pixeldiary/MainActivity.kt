package com.example.pixeldiary

import android.os.Bundle
import com.example.pixeldiary.ble.BleMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bleMethodChannel: BleMethodChannel? = null

    companion object {
        private const val METHOD_CHANNEL_NAME = "com.pixeldiary/ble_peripheral"
        private const val EVENT_CHANNEL_NAME = "com.pixeldiary/ble_peripheral/events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // BLE Peripheral用MethodChannel登録
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME
        )

        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_NAME
        )

        bleMethodChannel = BleMethodChannel(this, methodChannel, eventChannel)
    }

    override fun onDestroy() {
        bleMethodChannel?.cleanup()
        super.onDestroy()
    }
}
