import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';

/// Guards a sync-state fixture against the enum-derived key sets growing past
/// it (#74/#116c): asserts every key in [keys] — by default the full
/// `sync_gdrive_*` + `sync_icloud_*` union — holds a value in [db].
///
/// Call it right after a fixture that claims to populate "every sync key" and
/// before the code under test clears them. Without this, adding an 8th key to
/// a provider's set makes any "every key is null afterwards" loop pass
/// vacuously: the fixture never set the new key, so its null proves nothing.
Future<void> expectEverySyncKeySet(
  AppDatabase db, {
  Iterable<SettingKey>? keys,
  String fixture = 'the fixture',
}) async {
  final checked =
      keys ?? SettingKey.gdriveSyncKeys.followedBy(SettingKey.icloudSyncKeys);
  for (final key in checked) {
    expect(
      await db.getSetting(key.storageKey),
      isNotNull,
      reason: '$fixture does not populate ${key.storageKey}',
    );
  }
}
