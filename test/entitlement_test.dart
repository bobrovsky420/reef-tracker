import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/providers.dart';
import 'package:reeftracker/data/database.dart';
import 'package:reeftracker/data/entitlement.dart';
import 'package:reeftracker/data/purchases.dart';
import 'package:reeftracker/data/settings.dart';
import 'package:reeftracker/domain/pro_features.dart';

/// Delegates to a [MemoryProEntitlementStore] but can be told to fail writes —
/// the disk-full / IO-error shape the service's grant paths must contain.
class _WriteFailingStore implements ProEntitlementStore {
  final MemoryProEntitlementStore _inner = MemoryProEntitlementStore();
  bool writeThrows = false;

  @override
  Future<bool> read() => _inner.read();

  @override
  Stream<bool> watch() => _inner.watch();

  @override
  Future<void> write(bool purchased) {
    if (writeThrows) throw const FileSystemException('disk full');
    return _inner.write(purchased);
  }

  @override
  void dispose() => _inner.dispose();
}

/// The Pro entitlement (U19 Stage A0): where the purchase is stored, when it
/// is acknowledged, and — the part with real money behind it — when a cached
/// unlock may be cleared.
void main() {
  // The file store re-applies the iOS backup-exclusion attribute through a
  // MethodChannel, and reaching a channel at all needs a binding — without
  // this the write path throws before it writes (same reason cloud_sync_test
  // initializes it).
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  /// The store under test in most groups. In-memory on purpose: the service's
  /// rules are about *ordering* (acknowledge, then grant; clear only on a
  /// clean empty restore), and running them against real disk I/O only adds a
  /// race between the write completing and the assertion reading it back. The
  /// file store's own behaviour is the first group's job.
  late ProEntitlementStore entitlement;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('reeftracker-entitlement-');
    entitlement = MemoryProEntitlementStore();
  });
  tearDown(() async {
    entitlement.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('FileProEntitlementStore — the on-disk half', () {
    late FileProEntitlementStore entitlement;
    setUp(
      () => entitlement = FileProEntitlementStore(directory: () async => dir),
    );
    tearDown(() => entitlement.dispose());

    test('a fresh install holds no unlock', () async {
      expect(await entitlement.read(), isFalse);
      expect(
        await File('${dir.path}/$kProEntitlementFileName').exists(),
        isFalse,
        reason: 'nothing written until there is something to record',
      );
    });

    test('the unlock round-trips through a new instance', () async {
      await entitlement.write(true);
      final reread = FileProEntitlementStore(directory: () async => dir);
      addTearDown(reread.dispose);
      expect(await reread.read(), isTrue);
    });

    test('watch emits the current value, then every change', () async {
      final seen = <bool>[];
      final sub = entitlement.watch().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await entitlement.write(true);
      await pumpEventQueue();
      await entitlement.write(false);
      await pumpEventQueue();
      expect(seen, [false, true, false]);
    });

    test('a garbled file reads as not entitled, never as a crash', () async {
      await File('${dir.path}/$kProEntitlementFileName').writeAsString('yes');
      expect(await entitlement.read(), isFalse);
    });

    test('a failed read is not cached — the next read retries', () async {
      // The unlock is on disk, but the first read hits a documents-dir
      // hiccup. It must fail closed for THAT call only: caching the false
      // would unentitle a paying user for the whole process, and make
      // restoreAtStartup skip its self-heal because "nothing is cached".
      var fail = true;
      final store = FileProEntitlementStore(
        directory: () async {
          if (fail) throw const FileSystemException('documents unavailable');
          return dir;
        },
      );
      addTearDown(store.dispose);
      await File('${dir.path}/$kProEntitlementFileName').writeAsString('1');

      expect(await store.read(), isFalse, reason: 'fails closed per call');
      fail = false;
      expect(await store.read(), isTrue, reason: 'the hiccup was not cached');
    });

    test('successful reads are cached — including "no file yet"', () async {
      // The counterpart guard: a genuine answer (file present or absent) IS
      // cached, so the dashboard's gate doesn't re-read the disk per frame.
      var directoryCalls = 0;
      final store = FileProEntitlementStore(
        directory: () async {
          directoryCalls++;
          return dir;
        },
      );
      addTearDown(store.dispose);
      expect(await store.read(), isFalse);
      expect(await store.read(), isFalse);
      expect(directoryCalls, 1);
    });

    test('the iOS backup-exclusion attribute lands on the final path, '
        'never the .tmp', () async {
      // The attribute belongs to the inode: applied to the .tmp before the
      // rename it would evaporate with it, and the one thing keeping a paid
      // unlock from riding an iCloud restore onto every device on the
      // account would silently not be set.
      final excluded = <String>[];
      const channel = MethodChannel('cz.reeftracker/file_backup');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'exclude') {
          excluded.add((call.arguments as Map)['path'] as String);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await entitlement.write(true);
      expect(excluded, isNotEmpty);
      expect(excluded, everyElement(endsWith(kProEntitlementFileName)));
      expect(excluded, everyElement(isNot(endsWith('.tmp'))));
    });
  });

  group('readEntitlement', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    test('combines the marker and the purchase', () async {
      expect(
        (await readEntitlement(
          db,
          entitlement: entitlement,
        )).has(ProFeature.icpImport),
        isFalse,
        reason: 'no marker, no purchase',
      );

      await db.setSetting(kLegacyFreeSinceKey, '0.26.0');
      final founder = await readEntitlement(db, entitlement: entitlement);
      expect(founder.founder, isTrue);
      expect(founder.has(ProFeature.icpImport), isTrue);

      await entitlement.write(true);
      final both = await readEntitlement(db, entitlement: entitlement);
      expect(both.founder, isTrue);
      expect(both.purchased, isTrue);
    });

    test('a purchase alone entitles everything', () async {
      await entitlement.write(true);
      final e = await readEntitlement(db, entitlement: entitlement);
      expect(e.founder, isFalse);
      for (final f in ProFeature.values) {
        expect(e.has(f), isTrue, reason: '$f must be unlocked by a purchase');
      }
    });
  });

  group('entitlementProvider — the gate while its sources load', () {
    // Both of the gate's inputs are async, and both are read through a
    // `?? <default>`. `main()` awaits `settingsMapProvider` before `runApp`,
    // but that wait is bounded by a 3 s timeout (flutter#72872), so on a
    // wedged device the app really does build with the map still loading —
    // and the purchase stream has no pre-warm at all. Whatever the gate
    // answers in that window must be the LOCKED answer: the provider used to
    // default the marker to `founder`, which is a free unlock for every
    // Standard install the moment the paid tier is real.
    late StreamController<Map<String, String?>> settingsMap;
    late MemoryProEntitlementStore purchases;
    late ProviderContainer container;

    /// Riverpod 3 disposes an unlistened provider the moment the `read`
    /// returns, which would re-subscribe (and re-load) both source streams on
    /// every assertion. The app holds these through widgets; the listener
    /// below is the test's stand-in for that.
    void keepAlive(ProviderContainer c) {
      final sub = c.listen(entitlementProvider, (_, _) {});
      addTearDown(sub.close);
    }

    void build({bool purchased = false}) {
      settingsMap = StreamController<Map<String, String?>>();
      purchases = MemoryProEntitlementStore(purchased: purchased);
      container = ProviderContainer(
        overrides: [
          settingsMapProvider.overrideWith((ref) => settingsMap.stream),
          proEntitlementStoreProvider.overrideWithValue(purchases),
        ],
      );
      addTearDown(() async {
        container.dispose();
        purchases.dispose();
        await settingsMap.close();
      });
      keepAlive(container);
    }

    test('a founder install reads as Standard until the settings map '
        'arrives, then upgrades', () async {
      build();
      expect(
        container.read(settingsMapProvider).isLoading,
        isTrue,
        reason: 'the window under test must actually be open',
      );

      final loading = container.read(entitlementProvider);
      expect(loading.founder, isFalse);
      expect(loading.purchased, isFalse);
      for (final feature in ProFeature.values) {
        expect(
          container.read(proFeatureProvider(feature)),
          isFalse,
          reason: '$feature must stay locked while entitlement is unknown',
        );
      }

      // The marker lands: the very same install is now a Founder, and every
      // grandfathered feature opens.
      settingsMap.add({kLegacyFreeSinceKey: '0.26.0'});
      await pumpEventQueue();
      expect(container.read(entitlementProvider).founder, isTrue);
      for (final feature in kGrandfatheredFeatures) {
        expect(container.read(proFeatureProvider(feature)), isTrue);
      }
    });

    test('an install with no marker at all stays Standard once the map '
        'arrives', () async {
      build();
      settingsMap.add(const {});
      await pumpEventQueue();
      final e = container.read(entitlementProvider);
      expect(e.founder, isFalse);
      expect(e.purchased, isFalse);
      expect(container.read(proFeatureProvider(ProFeature.cloudSync)), isFalse);
    });

    test('a held purchase is not granted before the purchase stream '
        'delivers it', () async {
      // The other half of the same rule: `purchased` also fails closed. A
      // paying user sees the lock for one microtask, which is the correct
      // trade against every Standard install seeing an unlock.
      build(purchased: true);
      settingsMap.add(const {});
      await pumpEventQueue();
      // Force the not-yet-delivered state: the map has landed, the purchase
      // stream is what the gate is still waiting on.
      expect(container.read(proPurchasedProvider).hasValue, isTrue);
      expect(container.read(entitlementProvider).purchased, isTrue);

      // And in a container where nothing has been pumped yet, the same store
      // reads closed.
      final fresh = ProviderContainer(
        overrides: [
          settingsMapProvider.overrideWith(
            (ref) => Stream.value(const <String, String?>{}),
          ),
          proEntitlementStoreProvider.overrideWithValue(purchases),
        ],
      );
      addTearDown(fresh.dispose);
      keepAlive(fresh);
      expect(fresh.read(proPurchasedProvider).isLoading, isTrue);
      expect(fresh.read(entitlementProvider).purchased, isFalse);
      await pumpEventQueue();
      expect(fresh.read(entitlementProvider).purchased, isTrue);
    });
  });

  group('ProEntitlementService — acknowledgement', () {
    late FakePurchaseStore store;
    late ProEntitlementService service;

    setUp(() {
      store = FakePurchaseStore();
      service = ProEntitlementService(store: store, entitlement: entitlement);
      service.start();
    });
    tearDown(() async {
      await service.dispose();
      store.dispose();
    });

    test('a purchase is acknowledged and grants the unlock', () async {
      store.emitPurchased();
      await pumpEventQueue();
      expect(store.completed, hasLength(1));
      expect(store.completed.single.state, PurchaseState.purchased);
      expect(await entitlement.read(), isTrue);
    });

    test('a RESTORED event is acknowledged too — Play revokes anything '
        'unacknowledged, restores included', () async {
      store.emit(
        const PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.restored,
          pendingComplete: true,
        ),
      );
      await pumpEventQueue();
      expect(store.completed, hasLength(1));
      expect(await entitlement.read(), isTrue);
    });

    test('a purchase REDELIVERED at startup is acknowledged — the app can be '
        'killed between paying and acknowledging', () async {
      // The event arrives on the stream with no buy() call in this process.
      store.emitPurchased();
      await pumpEventQueue();
      expect(store.completed, hasLength(1));
      expect(await entitlement.read(), isTrue);
    });

    test('PENDING is not a purchase', () async {
      store.emit(
        const PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.pending,
        ),
      );
      await pumpEventQueue();
      expect(await entitlement.read(), isFalse);
    });

    test('a PENDING purchase is never acknowledged, even if the adapter '
        'wrongly flags it', () async {
      // Both stores forbid this: Play requires waiting for PURCHASED, iOS
      // forbids finishing a deferred transaction. Acknowledging early tells
      // the store the goods were delivered for money that has not arrived,
      // and destroys the event that would have delivered them for real. The
      // flag is set here deliberately — the guard must not depend on the
      // adapter getting it right.
      store.emit(
        const PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.pending,
          pendingComplete: true,
        ),
      );
      await pumpEventQueue();
      expect(store.completed, isEmpty);
      expect(await entitlement.read(), isFalse);
    });

    test('an acknowledgement failure still grants the unlock, and the next '
        'startup retries it', () async {
      // Refusing the unlock because the ack call failed would punish the buyer
      // for a network blip. The purchase stays unacknowledged, so the store
      // hands it back — that redelivery is the retry, and it must land.
      store.completeThrows = true;
      store.emitPurchased();
      await pumpEventQueue();
      expect(await entitlement.read(), isTrue, reason: 'buyer is not punished');
      expect(store.completed, isEmpty);

      // Next launch: the store still reports it owned and still unacknowledged.
      store.completeThrows = false;
      store.owned = const [
        PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.restored,
          pendingComplete: true,
        ),
      ];
      await service.restoreAtStartup();
      expect(
        store.completed,
        hasLength(1),
        reason: 'or Play refunds it after 3 days and the unlock evaporates',
      );
      expect(await entitlement.read(), isTrue);
    });

    test('canceled and error do not entitle', () async {
      for (final state in [PurchaseState.canceled, PurchaseState.error]) {
        store.emit(
          PurchaseUpdate(productId: kProUnlockProductId, state: state),
        );
      }
      await pumpEventQueue();
      expect(await entitlement.read(), isFalse);
    });

    test('buy reports the outcome and acknowledges exactly once', () async {
      final outcome = await service.buy(store.products.single);
      expect(outcome, PurchaseOutcome.purchased);
      expect(await entitlement.read(), isTrue);
      expect(
        store.completed,
        hasLength(1),
        reason: 'the background listener must not acknowledge it a second time',
      );
    });
  });

  group('ProEntitlementService — a failing entitlement write', () {
    late FakePurchaseStore store;
    late _WriteFailingStore failing;
    late ProEntitlementService service;

    setUp(() {
      store = FakePurchaseStore();
      failing = _WriteFailingStore();
      service = ProEntitlementService(store: store, entitlement: failing);
      service.start();
    });
    tearDown(() async {
      await service.dispose();
      store.dispose();
      failing.dispose();
    });

    test('buy reports failed, never a silent grant', () async {
      failing.writeThrows = true;
      expect(await service.buy(store.products.single), PurchaseOutcome.failed);
      expect(await failing.read(), isFalse);
      // Acknowledge-first still held: the purchase was completed before the
      // write was attempted, so the store's redelivery is the retry.
      expect(store.completed, hasLength(1));
    });

    test('on the background stream it is contained, not thrown into the '
        'zone — and the redelivery lands', () async {
      // `start()`'s listener applies updates via an unawaited future: a
      // throwing entitlement write there used to surface as an unhandled
      // async error (which is exactly what this test would fail with).
      failing.writeThrows = true;
      store.emitPurchased();
      await pumpEventQueue();
      expect(await failing.read(), isFalse);

      // The purchase stays owned by the account; the next delivery grants.
      failing.writeThrows = false;
      store.emitPurchased();
      await pumpEventQueue();
      expect(await failing.read(), isTrue);
    });
  });

  group('ProEntitlementService — a store that fails mid-flight', () {
    late FakePurchaseStore store;
    late ProEntitlementService service;

    setUp(() {
      store = FakePurchaseStore();
      service = ProEntitlementService(store: store, entitlement: entitlement);
      service.start();
    });
    tearDown(() async {
      await service.dispose();
      store.dispose();
    });

    test('a rejected buy reports failed, grants nothing, and leaves the '
        'background listener armed', () async {
      // `_buying` makes the listener drop every event while a buy is in
      // flight. If a throwing buy left it stuck true, the app would stop
      // acknowledging purchases for the rest of the process — and Play
      // auto-refunds anything unacknowledged after three days.
      store.buyThrows = true;
      expect(await service.buy(store.products.single), PurchaseOutcome.failed);
      expect(await entitlement.read(), isFalse, reason: 'nothing was bought');
      expect(store.completed, isEmpty);

      // The redelivery/retry that follows must be seen by the listener again.
      store.buyThrows = false;
      store.emitPurchased();
      await pumpEventQueue();
      expect(
        store.completed,
        hasLength(1),
        reason: 'the listener was left deaf by the failed buy',
      );
      expect(await entitlement.read(), isTrue);
    });

    test(
      'an error on the purchase stream does not deafen the listener',
      () async {
        // `cancelOnError` defaults to false, so the subscription survives — but
        // only because `start()` supplies an onError at all: without one the
        // error becomes an unhandled zone error at launch (which is how this
        // test would fail).
        store.emitError(StateError('billing connection lost'));
        await pumpEventQueue();
        expect(await entitlement.read(), isFalse);

        store.emitPurchased();
        await pumpEventQueue();
        expect(
          store.completed,
          hasLength(1),
          reason: 'the stream error unsubscribed the background listener',
        );
        expect(await entitlement.read(), isTrue);

        // Still alive after a second error, and a later restore is unaffected.
        store.emitError(StateError('again'));
        await pumpEventQueue();
        store.owned = const [];
        expect(await service.restore(), PurchaseOutcome.nothingToRestore);
      },
    );
  });

  group('ProEntitlementService — the clearing policy', () {
    late FakePurchaseStore store;
    late ProEntitlementService service;

    setUp(() {
      store = FakePurchaseStore();
      service = ProEntitlementService(store: store, entitlement: entitlement);
    });
    tearDown(() async {
      await service.dispose();
      store.dispose();
    });

    test(
      'a restore that finds a purchase grants and acknowledges it',
      () async {
        store.owned = const [
          PurchaseUpdate(
            productId: kProUnlockProductId,
            state: PurchaseState.restored,
            pendingComplete: true,
          ),
        ];
        expect(await service.restore(), PurchaseOutcome.restored);
        expect(await entitlement.read(), isTrue);
        expect(store.completed, hasLength(1));
      },
    );

    test('a CLEAN EMPTY restore clears the cached unlock — otherwise a '
        'self-service refund is a permanent free unlock', () async {
      await entitlement.write(true);
      expect(await service.restore(), PurchaseOutcome.nothingToRestore);
      expect(await entitlement.read(), isFalse);
    });

    test('an empty restore still finishes unfinished non-entitling '
        'transactions', () async {
      // iOS re-delivers an unfinished failed transaction forever and refuses
      // a re-purchase until it is finished. restore() used to short-circuit
      // on "nothing entitles" and never finish it — the exact state a user
      // whose payment failed is stuck in when they try to buy again.
      store.owned = const [
        PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.error,
          pendingComplete: true,
        ),
        // A deferred payment must still never be finished (both stores
        // forbid it), even on this path.
        PurchaseUpdate(
          productId: kProUnlockProductId,
          state: PurchaseState.pending,
          pendingComplete: true,
        ),
      ];
      expect(await service.restore(), PurchaseOutcome.nothingToRestore);
      expect(store.completed, hasLength(1));
      expect(store.completed.single.state, PurchaseState.error);
      expect(await entitlement.read(), isFalse, reason: 'nothing entitles');
    });

    test('a THROWN restore keeps the cached unlock — offline, wrong store '
        'account and a store blip must not downgrade a paying user', () async {
      await entitlement.write(true);
      store.restoreThrows = true;
      expect(await service.restore(), PurchaseOutcome.failed);
      expect(
        await entitlement.read(),
        isTrue,
        reason: 'the two failure shapes are NOT interchangeable',
      );
    });

    test(
      'startup reconciliation never asks a store that is not there',
      () async {
        await entitlement.write(true);
        store.available = false;
        store.restoreThrows = true; // would clear if it were consulted
        await service.restoreAtStartup();
        expect(await entitlement.read(), isTrue);
      },
    );

    test(
      'startup reconciliation skips the query when nothing is cached',
      () async {
        store.owned = const [];
        await service.restoreAtStartup();
        expect(await entitlement.read(), isFalse);
      },
    );
  });

  group('NoPurchaseStore — what every shipped build contains', () {
    const store = NoPurchaseStore();

    test('is never available and resolves no product', () async {
      expect(await store.isAvailable(), isFalse);
      expect(await store.queryProducts({kProUnlockProductId}), isEmpty);
    });

    test('cannot buy', () async {
      expect(
        () => store.buy(
          const ProProduct(id: kProUnlockProductId, title: 'x', price: 'y'),
        ),
        throwsStateError,
      );
    });
  });
}
