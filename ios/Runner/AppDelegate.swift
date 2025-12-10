import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bleMethodChannel: BleMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // BLE Peripheral用MethodChannel登録
    if let controller = window?.rootViewController as? FlutterViewController {
      bleMethodChannel = BleMethodChannel(binaryMessenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    bleMethodChannel?.cleanup()
    super.applicationWillTerminate(application)
  }
}
