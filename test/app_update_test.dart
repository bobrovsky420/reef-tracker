// Update-available check (U48): the version compare, the iTunes-lookup
// checker against a real local HTTP server (the transport-against-fake rule),
// and the launch flow's politeness contract (once-per-version prompt,
// restart re-offer for an already-downloaded Play update).

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reeftracker/data/app_update.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/settings.dart';

PackageInfo _info(String version) => PackageInfo(
  appName: 'ReefTracker',
  packageName: 'cz.reeftracker.reeftracker',
  version: version,
  buildNumber: '152',
);

/// A canned single-result iTunes Lookup reply.
String _lookupBody({
  String version = '9.9.9',
  String trackViewUrl = 'https://apps.apple.com/app/reeftracker/id123456789',
}) =>
    '{"resultCount":1,"results":[{"version":"$version",'
    '"trackViewUrl":"$trackViewUrl","trackId":123456789}]}';

class _FakeChecker extends AppUpdateChecker {
  _FakeChecker({this.update, this.downloadResult = false});

  StoreUpdate? update;
  bool downloadResult;
  int downloadCalls = 0;
  int installCalls = 0;

  @override
  Future<StoreUpdate?> check() async => update;

  @override
  Future<bool> download(StoreUpdate update) async {
    downloadCalls++;
    return downloadResult;
  }

  @override
  Future<void> install() async {
    installCalls++;
  }
}

void main() {
  group('isNewerStoreVersion', () {
    test('strictly newer dotted versions win', () {
      expect(isNewerStoreVersion('1.4.0', '1.3.0'), isTrue);
      expect(isNewerStoreVersion('1.3.1', '1.3.0'), isTrue);
      expect(isNewerStoreVersion('2.0.0', '1.9.9'), isTrue);
      // Numeric compare, not lexicographic.
      expect(isNewerStoreVersion('1.10.0', '1.9.0'), isTrue);
    });

    test('equal or older is not an update', () {
      expect(isNewerStoreVersion('1.3.0', '1.3.0'), isFalse);
      expect(isNewerStoreVersion('1.2.9', '1.3.0'), isFalse);
      expect(isNewerStoreVersion('0.9.0', '1.0.0'), isFalse);
    });

    test('missing segments read as zero', () {
      expect(isNewerStoreVersion('1.4', '1.3.2'), isTrue);
      expect(isNewerStoreVersion('1.3', '1.3.0'), isFalse);
      expect(isNewerStoreVersion('1.3.0.1', '1.3.0'), isTrue);
    });

    test('unparseable versions are conservatively not-newer', () {
      expect(isNewerStoreVersion('1.4.0-rc.1', '1.3.0'), isFalse);
      expect(isNewerStoreVersion('1.4.0', 'garbage'), isFalse);
      expect(isNewerStoreVersion('', '1.3.0'), isFalse);
      expect(isNewerStoreVersion('1.4.0', ''), isFalse);
    });
  });

  group('AppStoreUpdateChecker', () {
    /// Serves [body]/[status] from a real loopback server and runs one check
    /// against it. [onRequest] sees the request for assertions.
    Future<StoreUpdate?> lookup({
      String currentVersion = '1.3.0',
      int status = HttpStatus.ok,
      String body = '',
      void Function(HttpRequest request)? onRequest,
    }) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        onRequest?.call(request);
        request.response.statusCode = status;
        request.response.write(body);
        await request.response.close();
      });
      final checker = AppStoreUpdateChecker(
        packageInfo: () async => _info(currentVersion),
        lookupUri: (bundleId, storefront) => Uri.parse(
          'http://127.0.0.1:${server.port}/lookup?bundleId=$bundleId',
        ),
      );
      return checker.check();
    }

    test('newer store version yields an update with the store page', () async {
      Uri? requested;
      final update = await lookup(
        body: _lookupBody(version: '1.4.0'),
        onRequest: (r) => requested = r.uri,
      );
      expect(update, isNotNull);
      expect(update!.marker, '1.4.0');
      expect(
        update.storeUri,
        Uri.parse('https://apps.apple.com/app/reeftracker/id123456789'),
      );
      expect(update.downloaded, isFalse);
      // The lookup asks about this build's own bundle id.
      expect(requested?.queryParameters['bundleId'], 'cz.reeftracker.reeftracker');
    });

    test('same or older store version is silent', () async {
      expect(await lookup(body: _lookupBody(version: '1.3.0')), isNull);
      expect(await lookup(body: _lookupBody(version: '1.2.5')), isNull);
    });

    test('unknown bundle id (zero results) is silent', () async {
      expect(await lookup(body: '{"resultCount":0,"results":[]}'), isNull);
    });

    test('malformed reply is silent', () async {
      expect(await lookup(body: 'not json at all'), isNull);
      expect(await lookup(body: '{"results":"nope"}'), isNull);
      expect(
        await lookup(body: '{"resultCount":1,"results":[{"version":42}]}'),
        isNull,
      );
    });

    test('HTTP error is silent', () async {
      expect(
        await lookup(status: HttpStatus.internalServerError, body: 'oops'),
        isNull,
      );
    });

    test('unreachable host is silent (offline no-op)', () async {
      // Bind then immediately close, so the port is known-dead.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close(force: true);
      final checker = AppStoreUpdateChecker(
        packageInfo: () async => _info('1.3.0'),
        lookupUri: (bundleId, storefront) =>
            Uri.parse('http://127.0.0.1:$port/lookup'),
      );
      expect(await checker.check(), isNull);
    });
  });

  group('AppUpdateFlow', () {
    late AppDatabase db;
    late AppSettings settings;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settings = AppSettings(db);
    });

    tearDown(() => db.close());

    (AppUpdateFlow, List<Uri>, List<String>) flowFor(_FakeChecker checker) {
      final storePages = <Uri>[];
      final restarts = <String>[];
      final flow = AppUpdateFlow(
        checker: checker,
        settings: settings,
        notifyStorePage: storePages.add,
        notifyRestartReady: () => restarts.add('restart'),
      );
      return (flow, storePages, restarts);
    }

    test('store-page update notifies once, then stays quiet', () async {
      final uri = Uri.parse('https://apps.apple.com/app/id1');
      final checker = _FakeChecker(
        update: StoreUpdate(marker: '1.4.0', storeUri: uri),
      );
      final (flow, storePages, restarts) = flowFor(checker);

      await flow.run();
      expect(storePages, [uri]);
      expect(restarts, isEmpty);
      expect(await settings.readUpdatePromptedVersion(), '1.4.0');

      // Same version on the next launch: no second nag.
      await flow.run();
      expect(storePages, [uri]);
    });

    test('a yet-newer version prompts again', () async {
      await settings.setUpdatePromptedVersion('1.4.0');
      final checker = _FakeChecker(
        update: StoreUpdate(
          marker: '1.5.0',
          storeUri: Uri.parse('https://apps.apple.com/app/id1'),
        ),
      );
      final (flow, storePages, _) = flowFor(checker);
      await flow.run();
      expect(storePages, hasLength(1));
      expect(await settings.readUpdatePromptedVersion(), '1.5.0');
    });

    test('no update means no notice and no marker', () async {
      final (flow, storePages, restarts) = flowFor(_FakeChecker());
      await flow.run();
      expect(storePages, isEmpty);
      expect(restarts, isEmpty);
      expect(await settings.readUpdatePromptedVersion(), isNull);
    });

    test('in-place update downloads, then offers the restart', () async {
      final checker = _FakeChecker(
        update: const StoreUpdate(marker: '153'),
        downloadResult: true,
      );
      final (flow, _, restarts) = flowFor(checker);
      await flow.run();
      expect(checker.downloadCalls, 1);
      expect(restarts, ['restart']);
      expect(await settings.readUpdatePromptedVersion(), '153');
    });

    test('declined or failed download stays quiet, marker kept', () async {
      final checker = _FakeChecker(update: const StoreUpdate(marker: '153'));
      final (flow, _, restarts) = flowFor(checker);
      await flow.run();
      expect(checker.downloadCalls, 1);
      expect(restarts, isEmpty);
      // Play's own sheet was the prompt — don't re-show it next launch.
      expect(await settings.readUpdatePromptedVersion(), '153');

      await flow.run();
      expect(checker.downloadCalls, 1);
    });

    test('already-downloaded update re-offers the restart past the marker',
        () async {
      await settings.setUpdatePromptedVersion('153');
      final checker = _FakeChecker(
        update: const StoreUpdate(marker: '153', downloaded: true),
      );
      final (flow, storePages, restarts) = flowFor(checker);
      await flow.run();
      expect(restarts, ['restart']);
      expect(storePages, isEmpty);
      expect(checker.downloadCalls, 0, reason: 'nothing left to download');
    });
  });
}
