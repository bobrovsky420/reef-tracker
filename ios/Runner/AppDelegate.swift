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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudBackupChannel") {
      ICloudBackupChannel.register(with: registrar)
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
/// iOS half of `lib/data/icloud_backup_store.dart` (U44): file operations on
/// the `Documents/` folder of the app's iCloud ubiquity container, which
/// `NSUbiquitousContainers` in Info.plist exposes as a "ReefTracker" folder
/// in the Files app. Nothing here talks to the network — writes land in the
/// local container and the OS daemon syncs them; reads trigger a download
/// when the item was evicted or written by another device.
///
/// Error codes the Dart side maps onto its typed store errors:
/// `unavailable` (signed out of iCloud / iCloud Drive off for the app),
/// `timeout` (a download didn't finish in time — treated as offline),
/// `too_large` (over the byte cap, #64), `not_found`, `bad_arguments`, `io`.
///
/// Deliberately inside AppDelegate.swift, like FileBackupExclusion: a new
/// .swift file would have to be added to project.pbxproj by hand, and this
/// project's iOS target only ever builds on CI.
class ICloudBackupChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "cz.reeftracker/icloud_backup",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ICloudBackupChannel(), channel: channel)
  }

  /// Background serial queue: resolving the ubiquity container and the
  /// coordinated file I/O may block (Apple explicitly says not to call
  /// `url(forUbiquityContainerIdentifier:)` on the main thread), and `read`
  /// polls for a download to finish.
  private let queue = DispatchQueue(label: "cz.reeftracker.icloud_backup")

  private struct ChannelError: Error {
    let code: String
    let message: String
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    // `list` runs an NSMetadataQuery, which needs a run-loop thread — it
    // manages its own async completion on the main queue.
    if call.method == "list" {
      guard let folder = args["folder"] as? String else {
        result(FlutterError(code: "bad_arguments", message: "list needs a folder", details: nil))
        return
      }
      list(folder: folder, result: result)
      return
    }
    queue.async {
      do {
        let outcome: Any?
        switch call.method {
        case "ensureFolder":
          outcome = try self.ensureFolder().path
        case "read":
          outcome = try self.read(args)
        case "write":
          try self.write(args)
          outcome = nil
        case "delete":
          try self.delete(args)
          outcome = nil
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(outcome) }
      } catch let e as ChannelError {
        DispatchQueue.main.async {
          result(FlutterError(code: e.code, message: e.message, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// The container's `Documents/` folder — created if missing, returned as
  /// the opaque folder id the Dart store passes back into every other call.
  private func ensureFolder() throws -> URL {
    guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      throw ChannelError(
        code: "unavailable",
        message: "iCloud container unavailable (signed out, or iCloud Drive disabled for the app)"
      )
    }
    let docs = container.appendingPathComponent("Documents", isDirectory: true)
    try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    return docs
  }

  /// Lists the folder via NSMetadataQuery — the one API that reports evicted
  /// / not-yet-downloaded items under their real names with their real sizes
  /// (a plain directory enumeration would show them as hidden
  /// `.<name>.icloud` placeholders with placeholder sizes).
  private func list(folder: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let query = NSMetadataQuery()
      query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
      query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
      var observer: NSObjectProtocol?
      var timeoutWork: DispatchWorkItem?
      var done = false
      let finish: (Any?, FlutterError?) -> Void = { items, error in
        if done { return }
        done = true
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        timeoutWork?.cancel()
        query.stop()
        if let e = error { result(e) } else { result(items) }
      }
      observer = NotificationCenter.default.addObserver(
        forName: .NSMetadataQueryDidFinishGathering,
        object: query,
        queue: .main
      ) { _ in
        query.disableUpdates()
        var entries: [[String: Any]] = []
        for case let item as NSMetadataItem in query.results {
          guard
            let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
            let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
            // Direct children of the requested folder only.
            (path as NSString).deletingLastPathComponent == folder
          else { continue }
          var entry: [String: Any] = ["path": path, "name": name]
          if let size = item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber {
            entry["sizeBytes"] = size.int64Value
          }
          if let date = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date {
            entry["modifiedMs"] = Int(date.timeIntervalSince1970 * 1000)
          }
          entries.append(entry)
        }
        finish(entries, nil)
      }
      let work = DispatchWorkItem {
        finish(nil, FlutterError(code: "timeout", message: "metadata query did not finish", details: nil))
      }
      timeoutWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
      if !query.start() {
        finish(nil, FlutterError(code: "io", message: "could not start the metadata query", details: nil))
      }
    }
  }

  /// Reads a file's bytes, downloading it first when it is not local. The
  /// byte cap is checked before the download when the promised-item size is
  /// known, and always again before the bytes are loaded (#64).
  private func read(_ args: [String: Any]) throws -> FlutterStandardTypedData {
    guard let path = args["path"] as? String else {
      throw ChannelError(code: "bad_arguments", message: "read needs a path")
    }
    let maxBytes = args["maxBytes"] as? Int ?? 64 * 1024 * 1024
    let timeoutMs = args["timeoutMs"] as? Int ?? 60_000
    let url = URL(fileURLWithPath: path)
    let fm = FileManager.default

    // Cheap pre-check on the promised item (works for evicted files); fail
    // open to the post-download check when the size isn't reported.
    if let values = try? url.promisedItemResourceValues(forKeys: [.fileSizeKey]),
      let size = values.fileSize, size > maxBytes {
      throw ChannelError(code: "too_large", message: "\(size) bytes exceeds the \(maxBytes)-byte cap")
    }

    if !fm.fileExists(atPath: path) {
      // Evicted or written by another device: ask for the download and wait
      // for the real-named file to materialize (the placeholder lives as
      // `.<name>.icloud` until then).
      do {
        try fm.startDownloadingUbiquitousItem(at: url)
      } catch {
        throw ChannelError(code: "not_found", message: error.localizedDescription)
      }
      let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
      while !fm.fileExists(atPath: path) {
        if Date() > deadline {
          throw ChannelError(code: "timeout", message: "download did not complete in time")
        }
        Thread.sleep(forTimeInterval: 0.2)
      }
    }

    var coordError: NSError?
    var data: Data?
    var oversize: Int64? = nil
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { u in
      if let attrs = try? fm.attributesOfItem(atPath: u.path),
        let size = attrs[.size] as? NSNumber, size.int64Value > Int64(maxBytes) {
        oversize = size.int64Value
        return
      }
      data = try? Data(contentsOf: u)
    }
    if let size = oversize {
      throw ChannelError(code: "too_large", message: "\(size) bytes exceeds the \(maxBytes)-byte cap")
    }
    if let e = coordError {
      throw ChannelError(code: "io", message: e.localizedDescription)
    }
    guard let bytes = data else {
      throw ChannelError(code: "not_found", message: "could not read \(path)")
    }
    return FlutterStandardTypedData(bytes: bytes)
  }

  /// Atomic coordinated write into the container — durably queued for upload
  /// the moment it returns; the OS daemon takes it from there.
  private func write(_ args: [String: Any]) throws {
    guard
      let folder = args["folder"] as? String,
      let name = args["name"] as? String,
      let bytes = args["bytes"] as? FlutterStandardTypedData
    else {
      throw ChannelError(code: "bad_arguments", message: "write needs folder, name and bytes")
    }
    let folderUrl = URL(fileURLWithPath: folder, isDirectory: true)
    try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true)
    let url = folderUrl.appendingPathComponent(name)
    var coordError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { u in
      do {
        try bytes.data.write(to: u, options: .atomic)
      } catch {
        writeError = error
      }
    }
    if let e = coordError { throw ChannelError(code: "io", message: e.localizedDescription) }
    if let e = writeError { throw ChannelError(code: "io", message: e.localizedDescription) }
  }

  /// Coordinated delete — removes the cloud copy too, on every device.
  private func delete(_ args: [String: Any]) throws {
    guard let path = args["path"] as? String else {
      throw ChannelError(code: "bad_arguments", message: "delete needs a path")
    }
    let url = URL(fileURLWithPath: path)
    var coordError: NSError?
    var deleteError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { u in
      do {
        try FileManager.default.removeItem(at: u)
      } catch {
        deleteError = error
      }
    }
    if let e = coordError { throw ChannelError(code: "io", message: e.localizedDescription) }
    if let e = deleteError { throw ChannelError(code: "io", message: e.localizedDescription) }
  }
}

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
