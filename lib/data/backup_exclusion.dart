import 'package:flutter/services.dart';

/// Channel to the iOS-side helper in `ios/Runner/AppDelegate.swift`.
const MethodChannel _channel = MethodChannel('cz.reeftracker/file_backup');

/// Marks a file as excluded from the platform's own backup/transfer channel
/// (#68), so an app-private file the app deliberately keeps device-local
/// cannot follow the user to another phone.
///
/// The two platforms state the same rule in different places:
///
/// - **Android** — declaratively, in `res/xml/backup_rules.xml` and both
///   sections of `res/xml/data_extraction_rules.xml`. Nothing to call at
///   runtime, so no channel handler is registered and this is a no-op.
/// - **iOS** — per file, as the `NSURLIsExcludedFromBackupKey` resource value,
///   which only native code can set. The attribute belongs to the inode, so it
///   must be re-applied after every atomic `tmp` + rename write, not once at
///   creation.
///
/// Fails open: a file whose attribute could not be set is still written. The
/// alternative — refusing to store an Apex password because a filesystem
/// attribute wouldn't take — trades a working feature for a marginal privacy
/// gain on a channel the user may not even use.
Future<void> excludeFromDeviceBackup(String path) async {
  try {
    await _channel.invokeMethod<void>('exclude', {'path': path});
  } on MissingPluginException {
    // Android and `flutter test`: no handler on the other end, by design.
  } on PlatformException {
    // The file exists but the attribute didn't take (unsupported filesystem,
    // a race with the rename). See "fails open" above.
  }
}
