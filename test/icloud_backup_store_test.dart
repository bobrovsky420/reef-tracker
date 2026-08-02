import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/data/cloud_backup_store.dart';
import 'package:reeftracker/data/icloud_backup_store.dart';

/// Dart half of the iCloud store (U44) against a scripted method channel —
/// the argument shapes, result mapping and error typing the Swift side in
/// `ios/Runner/AppDelegate.swift` is written against. The Swift half itself
/// can only be compiled on CI (no macOS here); these tests pin the contract
/// it must meet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cz.reeftracker/icloud_backup');
  final calls = <MethodCall>[];
  Object? Function(MethodCall call)? script;

  setUp(() {
    calls.clear();
    script = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return script!(call);
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  ICloudBackupStore store({int? maxBytes}) =>
      ICloudBackupStore(maxResponseBytes: maxBytes ?? kCloudBackupMaxBytes);

  test('ensureFolder returns the container Documents path', () async {
    script = (call) => '/container/Documents';
    expect(await store().ensureFolder(), '/container/Documents');
    expect(calls.single.method, 'ensureFolder');
  });

  test('list maps entries and tolerates missing size/date (an undownloaded '
      'placeholder)', () async {
    script = (call) => [
      {
        'path': '/container/Documents/reeftracker-auto-a.json',
        'name': 'reeftracker-auto-a.json',
        'sizeBytes': 123,
        'modifiedMs': DateTime(2026, 7, 1).millisecondsSinceEpoch,
      },
      {
        'path': '/container/Documents/reeftracker-auto-b.json',
        'name': 'reeftracker-auto-b.json',
        // No size/date: the metadata query couldn't report them.
      },
      {'garbage': true}, // Malformed entries are skipped, never thrown on.
    ];
    final files = await store().list('/container/Documents');
    expect(files, hasLength(2));
    expect(files.first.id, '/container/Documents/reeftracker-auto-a.json');
    expect(files.first.sizeBytes, 123);
    expect(files.first.modifiedAt, DateTime(2026, 7, 1));
    expect(files.last.sizeBytes, isNull);
    expect(files.last.modifiedAt, isNull);
    // No appProperties analog: the metadata map is always empty (U44).
    expect(files.first.metadata, isEmpty);
    expect(calls.single.arguments, {'folder': '/container/Documents'});
  });

  test('read passes the cap and timeout down and returns the bytes', () async {
    script = (call) => Uint8List.fromList([1, 2, 3]);
    final bytes = await store().read('/container/Documents/f.json');
    expect(bytes, [1, 2, 3]);
    final args = calls.single.arguments as Map;
    expect(args['path'], '/container/Documents/f.json');
    expect(args['maxBytes'], kCloudBackupMaxBytes);
    expect(args['timeoutMs'], greaterThan(0));
  });

  test('read re-checks the cap on the Dart side (defense in depth)', () async {
    script = (call) => Uint8List.fromList(List.filled(32, 0));
    await expectLater(
      store(maxBytes: 16).read('/f.json'),
      throwsA(
        isA<CloudApiException>().having((e) => e.statusCode, 'status', 413),
      ),
    );
  });

  test(
    'write sends the bytes and silently drops the advisory metadata',
    () async {
      script = (call) => null;
      await store().write(
        '/container/Documents',
        'f.json',
        [9, 8],
        metadata: {'device': 'Phone', 'contentHash': 'abc'},
      );
      final args = calls.single.arguments as Map;
      expect(args['folder'], '/container/Documents');
      expect(args['name'], 'f.json');
      expect(args['bytes'], isA<Uint8List>());
      expect(args.containsKey('metadata'), isFalse);
    },
  );

  test('delete sends the path', () async {
    script = (call) => null;
    await store().delete('/container/Documents/f.json');
    expect(calls.single.method, 'delete');
    expect(calls.single.arguments, {'path': '/container/Documents/f.json'});
  });

  group('error mapping', () {
    Future<void> expectMapped(String code, Matcher matcher) async {
      script = (call) => throw PlatformException(code: code, message: 'x');
      await expectLater(store().ensureFolder(), throwsA(matcher));
    }

    test(
      'unavailable → CloudAuthRequiredException (sign in to iCloud)',
      () => expectMapped('unavailable', isA<CloudAuthRequiredException>()),
    );

    test(
      'timeout → SocketException, riding the engine offline branch',
      () => expectMapped('timeout', isA<SocketException>()),
    );

    test(
      'too_large → CloudApiException 413 (#64)',
      () => expectMapped(
        'too_large',
        isA<CloudApiException>().having((e) => e.statusCode, 'status', 413),
      ),
    );

    test(
      'not_found → CloudApiException 404 (folder recreate path)',
      () => expectMapped(
        'not_found',
        isA<CloudApiException>().having((e) => e.statusCode, 'status', 404),
      ),
    );

    test(
      'anything else → CloudApiException 500 (error stamp, not an untyped '
      'escape)',
      () => expectMapped(
        'weird',
        isA<CloudApiException>().having((e) => e.statusCode, 'status', 500),
      ),
    );

    test('missing handler (a wiring bug) → CloudApiException, so the engine '
        'stamps a failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(
        store().ensureFolder(),
        throwsA(isA<CloudApiException>()),
      );
    });
  });
}
