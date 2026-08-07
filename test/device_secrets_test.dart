import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reeftracker/data/device_secrets.dart';

/// Routes `getApplicationDocumentsDirectory()` to a throwaway temp folder, so
/// the default (production) constructor can be exercised under `flutter test`.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('reeftracker-secrets-');
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });
  tearDown(() async {
    if (await docsDir.exists()) await docsDir.delete(recursive: true);
  });

  DeviceSecrets newStore() => DeviceSecrets(directory: () async => docsDir);
  File secretsFile() => File(p.join(docsDir.path, kDeviceSecretsFileName));

  test('stores and returns a password per device', () async {
    final store = newStore();

    await store.write('AC5:1', 'hunter2');
    await store.write('AC5:2', 'other');

    expect(await store.read('AC5:1'), 'hunter2');
    expect(await store.read('AC5:2'), 'other');
    expect(await store.read('AC5:3'), isNull);
  });

  test('nothing stored yet reads as null, without creating a file', () async {
    expect(await newStore().read('AC5:1'), isNull);
    expect(await secretsFile().exists(), isFalse);
  });

  test('the default constructor writes .device_secrets into the documents '
      'directory — the path the OS backup rules exclude', () async {
    // Android excludes `app_flutter/.device_secrets` in backup_rules.xml and
    // both sections of data_extraction_rules.xml; those paths are only right
    // while the file is a sibling of reeftracker.sqlite.
    await DeviceSecrets().write('AC5:1', 'hunter2');

    expect(await secretsFile().exists(), isTrue);
    expect(jsonDecode(await secretsFile().readAsString()), {
      'AC5:1': 'hunter2',
    });
    // The atomic write leaves nothing behind.
    expect(
      await File('${secretsFile().path}.tmp').exists(),
      isFalse,
      reason: 'the tmp file is renamed onto the target, not left beside it',
    );
  });

  test('a later process reads what an earlier one wrote', () async {
    await newStore().write('AC5:1', 'hunter2');

    expect(await newStore().read('AC5:1'), 'hunter2');
  });

  test('writing again replaces only that password', () async {
    final store = newStore();
    await store.write('AC5:1', 'old');
    await store.write('AC5:2', 'keep');

    await store.write('AC5:1', 'new');

    expect(await store.read('AC5:1'), 'new');
    expect(await store.read('AC5:2'), 'keep');
    expect(
      await newStore().read('AC5:1'),
      'new',
      reason: 'persisted, not cached',
    );
  });

  test('removing a device drops its password and leaves the others', () async {
    final store = newStore();
    await store.write('AC5:1', 'hunter2');
    await store.write('AC5:2', 'keep');

    await store.remove('AC5:1');

    expect(await store.read('AC5:1'), isNull);
    expect(await store.read('AC5:2'), 'keep');
    expect(jsonDecode(await secretsFile().readAsString()), {'AC5:2': 'keep'});
    // Removing something that was never there is a no-op, not a crash.
    await store.remove('AC5:9');
    expect(await store.read('AC5:2'), 'keep');
  });

  test(
    'a corrupt file reads as "no passwords" and the next write repairs it',
    () async {
      await secretsFile().writeAsString('{not json');

      final store = newStore();
      expect(await store.read('AC5:1'), isNull);

      await store.write('AC5:1', 'hunter2');
      expect(await newStore().read('AC5:1'), 'hunter2');
    },
  );

  test('the queue survives a failed write — later reads and writes still '
      'run', () async {
    // _serialized keeps the chain alive with a one-line onError; dropping it
    // leaves `_queue` permanently rejected after the first failure, and every
    // later credential read/write fails until app restart.
    var fail = false;
    final store = DeviceSecrets(
      directory: () async {
        if (fail) throw const FileSystemException('disk unavailable');
        return docsDir;
      },
    );

    // Prime the cache so the failure lands in the write phase itself.
    expect(await store.read('AC5:1'), isNull);

    fail = true;
    await expectLater(
      store.write('AC5:1', 'hunter2'),
      throwsA(isA<FileSystemException>()),
    );

    // The failed write reported its error to the caller — and the queue must
    // still serve everything that comes after.
    fail = false;
    await store.write('AC5:1', 'hunter2');
    expect(await store.read('AC5:1'), 'hunter2');
    expect(await newStore().read('AC5:1'), 'hunter2');
  });

  test('concurrent writes do not lose one another', () async {
    final store = newStore();

    await Future.wait([
      store.write('AC5:1', 'one'),
      store.write('AC5:2', 'two'),
      store.write('AC5:3', 'three'),
    ]);

    expect(jsonDecode(await secretsFile().readAsString()), {
      'AC5:1': 'one',
      'AC5:2': 'two',
      'AC5:3': 'three',
    });
  });
}
