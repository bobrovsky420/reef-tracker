import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/pro_features.dart';
import 'backup_exclusion.dart';
import 'database.dart';
import 'purchases.dart';
import 'settings.dart';

/// Name of the entitlement sidecar, sibling to `reeftracker.sqlite` in the app
/// documents directory. Must stay excluded from OS backup in
/// `backup_rules.xml` and `data_extraction_rules.xml` (both sections) on
/// Android, and via [excludeFromDeviceBackup] on iOS.
const String kProEntitlementFileName = '.pro_entitlement';

/// The purchased half of the entitlement, kept **device-local** (U19).
///
/// Why a file and not a settings key: "device-local" in this codebase
/// (`SettingKey.deviceLocal`, [SettingKey.deviceLocalKeys]) is an
/// *app-JSON-backup* concept — it decides what `restoreFromBackup` preserves.
/// The settings kv itself lives inside the SQLite database, and Android Auto
/// Backup and device-to-device transfer copy that database **wholesale**,
/// through a channel this app's backup code never sees. There is no way to
/// exclude a row. So a purchase stored as a settings key would follow the
/// database to another phone or another Google account, and a single paid
/// unlock would silently become a family plan.
///
/// The fix is the one #62 (`.install_id`) and #68 (`.device_secrets`) already
/// use: keep it in a file the OS is told to leave out of backup and transfer.
/// A restored or transferred install therefore arrives with no unlock and
/// **Restore purchases** — which both stores require to be reachable anyway —
/// is what puts it back, from the store account that actually paid.
///
/// Failure mode is deliberately "not entitled": an unreadable file reads as
/// false, and Restore fixes it.
abstract interface class ProEntitlementStore {
  /// Whether this device holds a Pro unlock.
  Future<bool> read();

  /// The current value followed by every later change, so a provider can watch
  /// it without polling.
  Stream<bool> watch();

  /// Records (or clears) the unlock.
  Future<void> write(bool purchased);

  void dispose();
}

/// The real one: a backup-excluded file beside the database.
///
/// A seam rather than the only implementation for a mundane reason —
/// **`testWidgets` runs in a fake-async zone where real `dart:io` futures
/// never complete**, so a widget test that touches this class hangs rather
/// than fails. Widget tests use [MemoryProEntitlementStore]; this class is
/// covered by plain `test()` cases in `test/entitlement_test.dart`, where the
/// real event loop runs.
class FileProEntitlementStore implements ProEntitlementStore {
  /// [directory] is injectable so tests can point at a temp dir instead of the
  /// platform's documents directory.
  FileProEntitlementStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool? _cache;

  @override
  Future<bool> read() async {
    final cached = _cache;
    if (cached != null) return cached;
    var value = false;
    try {
      final file = await _file();
      if (await file.exists()) {
        value = (await file.readAsString()).trim() == '1';
        try {
          // Re-applied opportunistically, like `.install_id`: heals installs
          // written before the attribute took (no-op on Android, where the
          // XML rules cover it). Best-effort — the value itself was read.
          await excludeFromDeviceBackup(file.path);
        } on Object {
          // Fails open, matching excludeFromDeviceBackup's own policy.
        }
      }
    } on Object {
      // Fail closed for THIS call — a missing documents directory, a read
      // error — but never cache the failure: one launch-time hiccup would
      // otherwise unentitle a paying user for the whole process, and
      // restoreAtStartup would skip its self-heal because "nothing is
      // cached". The next read retries the file instead.
      return false;
    }
    return _cache = value;
  }

  @override
  Stream<bool> watch() async* {
    yield await read();
    yield* _changes.stream;
  }

  @override
  Future<void> write(bool purchased) async {
    if (_cache == purchased) return;
    final file = await _file();
    // Atomic tmp + rename like `.install_id` and `.device_secrets`: a torn
    // write here reads back as "not entitled" on the next launch.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(purchased ? '1' : '0', flush: true);
    await tmp.rename(file.path);
    // After the rename, not before: the attribute lives on the file the name
    // now points at.
    await excludeFromDeviceBackup(file.path);
    _cache = purchased;
    if (!_changes.isClosed) _changes.add(purchased);
  }

  @override
  void dispose() => unawaited(_changes.close());

  Future<File> _file() async =>
      File(p.join((await _directory()).path, kProEntitlementFileName));
}

/// In-memory [ProEntitlementStore] for widget tests and the `REEF_PRO_TEST`
/// rig.
///
/// Exists because `testWidgets` runs the test body inside a fake-async zone
/// where real `dart:io` futures never complete: a widget test that lets the
/// file-backed store run doesn't fail, it **hangs**, and then fails to delete
/// its own temp directory on Windows because a write is still in flight. The
/// file store's own behaviour is covered by plain `test()` cases instead.
class MemoryProEntitlementStore implements ProEntitlementStore {
  MemoryProEntitlementStore({bool purchased = false}) : _value = purchased;

  bool _value;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  @override
  Future<bool> read() async => _value;

  @override
  Stream<bool> watch() async* {
    yield _value;
    yield* _changes.stream;
  }

  @override
  Future<void> write(bool purchased) async {
    if (_value == purchased) return;
    _value = purchased;
    if (!_changes.isClosed) _changes.add(purchased);
  }

  @override
  void dispose() => unawaited(_changes.close());
}

/// The two orthogonal facts that decide what an install may use.
///
/// Deliberately **not** a third [AppEdition] value: `AppEdition` decodes one
/// settings key, and a Founder who buys Pro is the designed upgrade path after
/// activation, not an edge case — collapsing the pair into one enum would make
/// that state unrepresentable and render it as plain "Standard".
class Entitlement {
  const Entitlement({required this.marker, required this.purchased});

  /// Early-adopter status from the `legacy_free_since` marker.
  final AppEdition marker;

  /// A Pro unlock bought on this device.
  final bool purchased;

  bool get founder => marker == AppEdition.founder;

  /// Nothing at all — the state every install lands in after activation.
  static const Entitlement none = Entitlement(
    marker: AppEdition.standard,
    purchased: false,
  );

  bool has(ProFeature feature) =>
      hasProFeature(feature, purchased: purchased, legacyFree: founder);

  /// Whether this entitlement may cross an authoritative capability boundary.
  bool allows(ProCapabilityBoundary boundary) =>
      hasProCapability(boundary, purchased: purchased, legacyFree: founder);
}

/// Whether [boundary] was held and is now lost. Startup's fail-closed default
/// is deliberately not a revocation; callers reconcile persisted automation
/// only after the entitlement stores have completed their first read.
bool lostProCapability(
  Entitlement? previous,
  Entitlement current,
  ProCapabilityBoundary boundary,
) => previous?.allows(boundary) == true && !current.allows(boundary);

/// Authorization seam for work that runs outside Riverpod/widget context.
/// Services ask about a generated boundary at the moment of the side effect,
/// rather than trusting the setting or UI action that originally enabled it.
abstract interface class ProCapabilityAuthorizer {
  Future<bool> allows(ProCapabilityBoundary boundary);
}

/// Reads both live entitlement facts for every authorization decision.
class StoredProCapabilityAuthorizer implements ProCapabilityAuthorizer {
  const StoredProCapabilityAuthorizer({
    required this.db,
    required this.entitlement,
  });

  final AppDatabase db;
  final ProEntitlementStore entitlement;

  @override
  Future<bool> allows(ProCapabilityBoundary boundary) async =>
      (await readEntitlement(db, entitlement: entitlement)).allows(boundary);
}

/// Stable authorization for domain/service tests and deterministic callers.
class EntitlementCapabilityAuthorizer implements ProCapabilityAuthorizer {
  const EntitlementCapabilityAuthorizer(this.entitlement);

  final Entitlement entitlement;

  @override
  Future<bool> allows(ProCapabilityBoundary boundary) async =>
      entitlement.allows(boundary);
}

/// Reads both entitlement facts for [db].
///
/// **One helper, because there are two call sites and they drifted.** The
/// gate used to be hardwired `purchased: false` in `app/providers.dart` *and*
/// in `cloud_sync.dart`'s `completeWelcomeRestore` — the U35 welcome
/// cloud-restore path, which runs outside Riverpod. Left as two, a paying user
/// who reinstalls and restores from the welcome screen would come out with
/// cloud sync switched off: the one feature they bought.
Future<Entitlement> readEntitlement(
  AppDatabase db, {
  required ProEntitlementStore entitlement,
}) async => Entitlement(
  marker: AppSettings.decodeEdition(await db.getSetting(kLegacyFreeSinceKey)),
  purchased: await entitlement.read(),
);

/// How a purchase or restore ended, for the paywall to render.
enum PurchaseOutcome {
  purchased,
  restored,
  nothingToRestore,
  pending,
  canceled,
  failed,
}

/// Owns the purchase lifecycle: acknowledgement, the entitlement cache, and
/// the clearing policy.
class ProEntitlementService {
  ProEntitlementService({required this.store, required this.entitlement});

  final PurchaseStore store;
  final ProEntitlementStore entitlement;
  StreamSubscription<PurchaseUpdate>? _sub;

  /// While a [buy] is in flight it owns the events for that product, so the
  /// background subscription doesn't acknowledge the same purchase twice.
  bool _buying = false;

  /// Subscribes to the store's purchase stream. Must run before any buy, and
  /// early enough at startup to catch **redelivered** purchases: the app can
  /// be killed between paying and acknowledging, and both stores re-deliver
  /// that transaction on the next launch — iOS forever, until it is finished.
  void start() {
    _sub ??= store.purchases.listen(
      (update) {
        if (_buying) return;
        unawaited(_apply(update));
      },
      // A store that errors its own stream must not take the app down.
      onError: (Object _) {},
    );
  }

  /// Runs the store's purchase flow and reports how it ended.
  ///
  /// The store answers on its stream, not from [PurchaseStore.buy], so this
  /// arms the listener *before* starting the flow — the store sheet can
  /// resolve faster than the next microtask. The timeout is generous because
  /// the user is inside the store's own UI (card entry, 3-D Secure, a parental
  /// approval); it exists only so a store that never answers doesn't leave a
  /// spinner up forever, and it reports [PurchaseOutcome.failed], never a
  /// silent grant.
  Future<PurchaseOutcome> buy(ProProduct product) async {
    final next = store.purchases
        .where((u) => u.productId == product.id)
        .first
        .timeout(const Duration(minutes: 5));
    // If `buy` below throws we return without awaiting `next`, and its later
    // timeout would surface as an unhandled async error. A second, silent
    // listener keeps it handled either way.
    unawaited(next.then((_) {}, onError: (Object _) {}));
    _buying = true;
    try {
      await store.buy(product);
      return await _apply(await next);
    } on Object {
      return PurchaseOutcome.failed;
    } finally {
      _buying = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<PurchaseOutcome> _apply(PurchaseUpdate update) async {
    // Acknowledge FIRST, for every event that asks for it — purchased,
    // restored and redelivered alike, and error too (iOS re-delivers an
    // unfinished failed transaction forever). Play auto-refunds and revokes
    // anything unacknowledged (3 days; 3 minutes for license testers) and iOS
    // refuses a re-purchase until the old transaction is finished. An
    // entitlement flipped before this call is an entitlement that can silently
    // evaporate.
    //
    // The one exception, and it is mandatory on both stores: **never
    // acknowledge a PENDING purchase.** Play requires waiting until the state
    // becomes PURCHASED, and iOS forbids finishing a deferred transaction.
    // Doing it early tells the store the goods were delivered for money that
    // has not arrived — and destroys the event that would have delivered them
    // for real. Belt and braces with the adapter contract in `purchases.dart`:
    // this must hold even if a future adapter sets the flag wrongly.
    if (update.pendingComplete && update.state != PurchaseState.pending) {
      try {
        await store.complete(update);
      } on Object {
        // Nothing useful to do here: the store will re-deliver, and refusing
        // to grant the unlock because the ack failed would punish the buyer
        // for a network blip.
      }
    }
    if (update.entitling) {
      try {
        await entitlement.write(true);
      } on Object {
        // A write that failed is an unlock that will not survive the process:
        // report failure (so the paywall doesn't celebrate) instead of
        // throwing — on the background-stream path (`start`'s unawaited
        // apply) a throw here would surface as an unhandled zone error. The
        // purchase was acknowledged above; the store's redelivery on the
        // next launch is the retry.
        return PurchaseOutcome.failed;
      }
      return update.state == PurchaseState.restored
          ? PurchaseOutcome.restored
          : PurchaseOutcome.purchased;
    }
    return switch (update.state) {
      // NOT purchased. Deferred payment methods (cash, bank transfer, carrier
      // billing) sit here for days; the unlock arrives with the later event.
      PurchaseState.pending => PurchaseOutcome.pending,
      PurchaseState.canceled => PurchaseOutcome.canceled,
      _ => PurchaseOutcome.failed,
    };
  }

  /// Re-queries the store account and reconciles the cached unlock.
  ///
  /// **The clearing policy, which is the whole point of this method.** A
  /// restore can end three ways and only one of them may clear:
  ///
  /// - owns something → grant (and acknowledge, via [_apply]).
  /// - completed, owns nothing → clear. Without this, a Play self-service
  ///   refund would leave a permanent free unlock.
  /// - threw → keep. Offline, a different store account, a transient store
  ///   error and "genuinely owns nothing" are indistinguishable to a naive
  ///   listener, and downgrading a paying user at launch because their train
  ///   went into a tunnel is the worse failure by far.
  Future<PurchaseOutcome> restore() async {
    final List<PurchaseUpdate> owned;
    try {
      owned = await store.restore();
    } on Object {
      return PurchaseOutcome.failed;
    }
    // Apply every owned update BEFORE deciding the outcome — including when
    // nothing entitles: iOS re-delivers an unfinished failed transaction
    // forever and refuses a re-purchase until it is finished, and the old
    // `entitling.isEmpty` short-circuit left exactly that transaction
    // unacknowledged. (_apply never finishes a pending one, and a
    // non-entitling update never writes the unlock.)
    for (final update in owned) {
      await _apply(update);
    }
    if (owned.every((u) => !u.entitling)) {
      await entitlement.write(false);
      return PurchaseOutcome.nothingToRestore;
    }
    return PurchaseOutcome.restored;
  }

  /// Silent startup reconciliation. Same policy as [restore], no UI.
  Future<void> restoreAtStartup() async {
    // "Could not be asked" is not "owns nothing" — a store that isn't there
    // (no Play Services, and every Phase-0 build, where the store is
    // [NoPurchaseStore]) must never clear a cached unlock.
    if (!await store.isAvailable()) return;
    if (!await entitlement.read()) {
      // Nothing cached to lose and nothing to correct: a fresh install that
      // owns a purchase finds it via the visible Restore button. Skipping the
      // query keeps every dormant launch free of store traffic.
      return;
    }
    await restore();
  }
}
