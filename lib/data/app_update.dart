// Update-available check (U48): tell the user, once per new version, that a
// newer build is on their store. Direct store integration by decision
// (2026-08-01) — no self-hosted version file:
//
// - **Android**: the official Play In-App Updates API (`in_app_update`
//   plugin). The check is silent; the *notice* is Play's own consent sheet,
//   shown by starting the flexible flow — accept downloads in place, then a
//   SnackBar offers the restart that installs it.
// - **iOS**: no equivalent API exists, so the closest store-direct check is
//   the official iTunes Lookup endpoint (no auth) + a version compare; the
//   notice is a SnackBar whose action opens the App Store page.
//
// Everything here fails into "no update": store rollouts are staged/regional
// (a version can be looked up before this device can install it), sideloaded
// and emulator builds aren't Play-owned, and the device may simply be offline.
// An update notice is never worth an error surface (offline-first).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_http.dart';
import 'settings.dart';

/// Ceiling on an iTunes Lookup reply (#64/#72 hygiene): a one-app lookup is
/// tens of KB (store description, artwork URLs), so this is ample headroom.
const _kLookupMaxBytes = 512 * 1024;

/// A newer app version the store reports.
class StoreUpdate {
  const StoreUpdate({required this.marker, this.storeUri, this.downloaded = false});

  /// Identity of the offered version, for the once-per-version prompt rule —
  /// Play's `availableVersionCode`, the App Store's version string. Opaque:
  /// only ever compared for equality against the stored marker.
  final String marker;

  /// The store page to open (App Store), or null when the update installs in
  /// place instead (Play flexible flow).
  final Uri? storeUri;

  /// True when a flexible download from a previous session is already sitting
  /// on the device waiting for its restart — the flow then re-offers the
  /// restart instead of prompting again (finishing an update the user already
  /// accepted is not a new nag).
  final bool downloaded;
}

/// What the launch check needs from the platform store. A seam so tests and
/// the emulator rig can fake the store — the real implementations are
/// [PlayUpdateChecker] (Android) and [AppStoreUpdateChecker] (iOS), chosen by
/// `appUpdateCheckerProvider`.
abstract class AppUpdateChecker {
  /// The available update, or null — up to date, not a store install,
  /// offline, or any other failure (the caller can't tell and doesn't need
  /// to). Never throws.
  Future<StoreUpdate?> check();

  /// Runs the in-place download flow, returning true when a restart-ready
  /// download finished. Base: nothing installs in place (the caller offers
  /// [StoreUpdate.storeUri] instead).
  Future<bool> download(StoreUpdate update) async => false;

  /// Installs a completed [download] (Play restarts the app). No-op
  /// elsewhere. Never throws.
  Future<void> install() async {}
}

/// Android: the Play In-App Updates API via the `in_app_update` plugin.
///
/// Only the **flexible** flow is used — [download] shows Play's own consent
/// sheet and streams the download in the background. The immediate
/// (full-screen, blocking) flow is for critical updates pushed with a high
/// priority, which this app never sets, so `immediateUpdateAllowed`-only
/// results are treated as "no update" rather than interrupting the keeper.
class PlayUpdateChecker extends AppUpdateChecker {
  @override
  Future<StoreUpdate?> check() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      // A download accepted in an earlier session survives the process: Play
      // reports it as an update already in progress, downloaded. Surface the
      // restart again or the update sits on the device forever.
      if (info.installStatus == InstallStatus.downloaded) {
        return StoreUpdate(
          marker: '${info.availableVersionCode ?? 0}',
          downloaded: true,
        );
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return null;
      }
      if (!info.flexibleUpdateAllowed) return null;
      return StoreUpdate(marker: '${info.availableVersionCode ?? 0}');
    } catch (_) {
      // Sideloaded/debug builds and Play-less devices land here
      // (ERROR_APP_NOT_OWNED and friends) — by design, silently.
      return null;
    }
  }

  @override
  Future<bool> download(StoreUpdate update) async {
    try {
      // This call IS the user-facing notice on Android: Play draws its own
      // "Update ReefTracker?" sheet, and the future completes only after the
      // accepted download finishes (decline → userDeniedUpdate).
      return await InAppUpdate.startFlexibleUpdate() == AppUpdateResult.success;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> install() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (_) {
      // A failed install keeps the downloaded state; the next launch's check
      // re-offers the restart.
    }
  }
}

/// iOS: the official iTunes Lookup endpoint
/// (`itunes.apple.com/lookup?bundleId=…`) + a version compare against this
/// build. No in-place flow exists on iOS — the notice's action opens the
/// looked-up App Store page ([StoreUpdate.storeUri]).
class AppStoreUpdateChecker extends AppUpdateChecker {
  AppStoreUpdateChecker({
    this.timeout = const Duration(seconds: 10),
    HttpClient Function()? clientFactory,
    Future<PackageInfo> Function()? packageInfo,
    Uri Function(String bundleId, String? storefront)? lookupUri,
  }) : _clientFactory = clientFactory ?? HttpClient.new,
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _lookupUri = lookupUri ?? _itunesLookupUri;

  /// One bound for the whole probe (connect, headers, body). A launch-time
  /// background check earns no patience: past this it is a silent no-update.
  final Duration timeout;

  final HttpClient Function() _clientFactory;
  final Future<PackageInfo> Function() _packageInfo;
  final Uri Function(String bundleId, String? storefront) _lookupUri;

  /// The device's storefront guess: store rollouts are per-country, and the
  /// unqualified endpoint defaults to the US storefront — which would report
  /// "no results" for an app the user got from another country's store.
  static String? _deviceStorefront() =>
      PlatformDispatcher.instance.locale.countryCode;

  static Uri _itunesLookupUri(String bundleId, String? storefront) =>
      Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': bundleId,
        'country': ?storefront,
      });

  @override
  Future<StoreUpdate?> check() async {
    try {
      final info = await _packageInfo();
      final client = _clientFactory();
      try {
        final request = await client
            .getUrl(_lookupUri(info.packageName, _deviceStorefront()))
            .timeout(timeout);
        final response = await request.close().timeout(timeout);
        if (response.statusCode != HttpStatus.ok) return null;
        final text = await readBoundedText(
          response,
          _kLookupMaxBytes,
        ).timeout(timeout);
        final decoded = jsonDecode(text);
        if (decoded is! Map<String, dynamic>) return null;
        final results = decoded['results'];
        if (results is! List || results.isEmpty) return null;
        final first = results.first;
        if (first is! Map<String, dynamic>) return null;
        final storeVersion = first['version'];
        final page = first['trackViewUrl'];
        if (storeVersion is! String || page is! String) return null;
        final storeUri = Uri.tryParse(page);
        if (storeUri == null) return null;
        if (!isNewerStoreVersion(storeVersion, info.version)) return null;
        return StoreUpdate(marker: storeVersion, storeUri: storeUri);
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null; // Offline, DNS, TLS, junk JSON — all the same silence.
    }
  }
}

/// Whether the store's version string names a newer release than the one
/// running. Dotted numeric compare, missing segments read as 0 ("1.4" >
/// "1.3.2"); any non-numeric segment on either side is a conservative false —
/// better to skip one notice than to nag on a string this code misread.
bool isNewerStoreVersion(String store, String current) {
  final s = _versionSegments(store);
  final c = _versionSegments(current);
  if (s == null || c == null) return false;
  final len = s.length > c.length ? s.length : c.length;
  for (var i = 0; i < len; i++) {
    final a = i < s.length ? s[i] : 0;
    final b = i < c.length ? c[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

List<int>? _versionSegments(String v) {
  final parts = v.trim().split('.');
  final out = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    out.add(n);
  }
  return out.isEmpty ? null : out;
}

/// The launch flow: check → once-per-version gate → platform notice. Plain
/// class with injected callbacks (the `CloudRestoreFlow` shape) so the whole
/// politeness contract is unit-testable without Flutter.
///
/// The once-per-version rule is the U35 dismissed-name idiom: after one
/// prompt, whatever the user did with it, the check stays quiet until the
/// store offers an even newer version. Prompting is limited, *finishing*
/// isn't — an already-downloaded Play update re-offers its restart on every
/// launch until installed.
class AppUpdateFlow {
  AppUpdateFlow({
    required this.checker,
    required this.settings,
    required this.notifyStorePage,
    required this.notifyRestartReady,
  });

  final AppUpdateChecker checker;
  final AppSettings settings;

  /// Show the "new version available" notice whose action opens [Uri]
  /// (App Store path — Play's consent sheet needs no notice of ours).
  final void Function(Uri storeUri) notifyStorePage;

  /// Show the "downloaded — restart to install" notice whose action calls
  /// [AppUpdateChecker.install] (Play flexible path).
  final void Function() notifyRestartReady;

  Future<void> run() async {
    final update = await checker.check();
    if (update == null) return;
    if (update.downloaded) {
      notifyRestartReady();
      return;
    }
    if (await settings.readUpdatePromptedVersion() == update.marker) return;
    // Stamped before the notice, not after: a re-entrant launch task must
    // never double-prompt, and losing one notice to a crash mid-flow is the
    // cheaper failure.
    await settings.setUpdatePromptedVersion(update.marker);
    final storeUri = update.storeUri;
    if (storeUri != null) {
      notifyStorePage(storeUri);
      return;
    }
    if (await checker.download(update)) notifyRestartReady();
  }
}

/// Emulator rig (`--dart-define=REEF_UPDATE_TEST=1`): swaps a fake store into
/// `appUpdateCheckerProvider` so the notice SnackBar can be *seen* — a real
/// Play check refuses sideloaded builds and the iTunes path never runs on
/// Android. Same spelling contract as `kProTestRig`, and the same hard rule:
/// a build with this define never reaches a store.
const bool kUpdateTestRig =
    bool.fromEnvironment('REEF_UPDATE_TEST') ||
    String.fromEnvironment('REEF_UPDATE_TEST') == '1';

/// The rig's store: always offers an "update" whose action opens this app's
/// Play page, under a fresh marker each launch so the notice reappears on
/// every run (screenshot sessions restart the app repeatedly).
class FakeStoreUpdateChecker extends AppUpdateChecker {
  @override
  Future<StoreUpdate?> check() async => StoreUpdate(
    marker: 'rig-${DateTime.now().millisecondsSinceEpoch}',
    storeUri: Uri.parse(
      'https://play.google.com/store/apps/details?id=cz.reeftracker.reeftracker',
    ),
  );
}
