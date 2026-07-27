import 'package:reeftracker/data/device_secrets.dart';

/// In-memory [DeviceSecrets] for widget tests. The real one is a file store,
/// and `flutter test`'s fake-async zone never lets real `dart:io` futures
/// complete while a `testWidgets` body is pumping (the same reason the fakes
/// exist for the device links) — so a widget test that needed the file store
/// would simply hang on an unresolved password read.
///
/// The file store itself is covered directly in `device_secrets_test.dart`,
/// which is a plain `test` and can await real I/O.
class FakeDeviceSecrets implements DeviceSecrets {
  FakeDeviceSecrets([Map<String, String>? seed]) : secrets = {...?seed};

  /// identifier → password, readable by tests asserting what was stored.
  final Map<String, String> secrets;

  @override
  Future<String?> read(String identifier) async => secrets[identifier];

  @override
  Future<void> write(String identifier, String secret) async =>
      secrets[identifier] = secret;

  @override
  Future<void> remove(String identifier) async => secrets.remove(identifier);
}
