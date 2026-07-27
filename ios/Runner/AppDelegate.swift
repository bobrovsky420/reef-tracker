import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: route notification callbacks (foreground
    // presentation, taps) through the Flutter engine.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FileBackupExclusion") {
      FileBackupExclusion.register(with: registrar)
    }
  }
}

/// iOS half of `lib/data/backup_exclusion.dart` (#68).
///
/// Files the app keeps deliberately device-local — today the Apex controller
/// passwords in `.device_secrets` — must not ride an iCloud backup or a
/// device-to-device transfer. Android states that declaratively in
/// `backup_rules.xml` / `data_extraction_rules.xml`; iOS has no equivalent
/// manifest, only the per-file `NSURLIsExcludedFromBackupKey` resource value,
/// which nothing in Dart can set. Hence this channel: a handful of lines in
/// the app target instead of a dependency on a secure-storage plugin (TODO #68
/// records why that trade was made).
///
/// Deliberately inside AppDelegate.swift rather than its own file: a new
/// .swift file would have to be added to project.pbxproj by hand, and this
/// project's iOS target only ever builds on CI.
class FileBackupExclusion: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "cz.reeftracker/file_backup",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(FileBackupExclusion(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exclude" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String
    else {
      result(FlutterError(code: "bad_arguments", message: "exclude needs a path", details: nil))
      return
    }
    // The attribute belongs to the file the path currently points at, so the
    // Dart side re-applies it after every atomic tmp + rename write.
    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try url.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
    }
  }
}
