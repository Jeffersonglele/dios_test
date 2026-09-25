import Flutter
import UIKit
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var navChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "app.navbar/navigate",
      binaryMessenger: messenger
    )
    navChannel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getIOSVersion":
        result(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
      case "updateIndex":
        let index = call.arguments as? Int ?? 0
        NotificationCenter.default.post(
          name: NSNotification.Name("UpdateNavBarIndex"),
          object: nil,
          userInfo: ["index": index]
        )
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    if #available(iOS 18.0, *) {
      let factory = NavBarFactory(channel: channel)
      engineBridge.pluginRegistry
        .registrar(forPlugin: "DiosNavBarPlugin")?
        .register(factory, withId: "liquid_glass_navbar")
    }
  }
}
