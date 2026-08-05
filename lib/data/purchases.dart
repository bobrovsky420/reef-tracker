/// Store-purchase seam for the Pro unlock (U19, Stage A0 / P0-1).
///
/// **No plugin behind this file yet, deliberately.** The `in_app_purchase`
/// dependency pulls in `com.android.billingclient:billing`, whose AAR manifest
/// contributes the `com.android.vending.BILLING` permission, a
/// `billingclient.version` meta-data node, two `<queries>` entries and
/// `ProxyBillingActivity` — enough for a build to self-identify as a Billing
/// Library consumer, which is exactly one of Play's listing-label levers. So
/// Phase 0 ships the *shape* of the integration and nothing that can reach a
/// store: the only implementation here is [NoPurchaseStore]. Phase 1 adds one
/// plugin-backed implementation plus the manifest machinery that keeps it out
/// of dormant artifacts (§10 A1/A9).
///
/// The interface is a seam for the same reason [CloudAuth] and
/// [CloudBackupStore] are: plugin method calls throw under `flutter test`, so
/// every test and the Phase-0 rig talk to this interface only.
library;

import 'dart:async';

/// The one product id, shared verbatim by both stores (both accept the same
/// string).
///
/// **A one-time, permanent, non-consumable unlock** — decided 2026-08-05. Not
/// a subscription, and there is no second product: the paywall copy shipped in
/// all seven languages promises "one purchase, no subscription and no account".
///
/// Defining the string here costs nothing; **creating it in either console is
/// the irreversible step**, since Play product ids can never be changed or
/// reused. That burns this id's *type*, not the business model — a
/// subscription could still ship later as a separate id, and both stores allow
/// the two side by side. What actually blocks that is architectural: a
/// subscription can lapse, and this app has no receipt validation and no
/// server, so it would have no way to notice.
const String kProUnlockProductId = 'pro_unlock';

/// A purchasable product as the store describes it.
class ProProduct {
  const ProProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;

  /// The price **already formatted by the store** in the user's currency
  /// ("€4.99", "129 Kč"). Never assembled in the app: the consoles own pricing,
  /// currency and local formatting, and a hardcoded price is both a lie and a
  /// review finding waiting to happen.
  final String price;
}

/// What happened to a purchase, mirroring the states both store contracts can
/// produce.
enum PurchaseState {
  /// Paid and owned — entitles.
  purchased,

  /// Returned by a restore, or redelivered at startup because a previous run
  /// never completed it — entitles.
  restored,

  /// A **real** state, not a transitional one: deferred payment methods (cash
  /// at a counter, bank transfer, carrier billing) can sit here for days. Must
  /// never be treated as purchased.
  pending,

  /// The user backed out. Not an error — never show one.
  canceled,

  /// The store reported a failure.
  error,
}

/// One purchase event.
class PurchaseUpdate {
  const PurchaseUpdate({
    required this.productId,
    required this.state,
    this.pendingComplete = false,
    this.error,
  });

  final String productId;
  final PurchaseState state;

  /// Whether the store still expects an acknowledgement for this event.
  ///
  /// **Acknowledgement is not optional and not a formality.** Play
  /// auto-refunds and revokes an unacknowledged purchase after three days —
  /// three *minutes* for license testers, which is why an untested restore
  /// reads as "restore is broken". iOS re-delivers unfinished transactions on
  /// every launch and blocks re-purchase of the same product until they are
  /// finished. So [PurchaseStore.complete] is called for **every** event
  /// carrying this flag, including [PurchaseState.restored] and events
  /// redelivered at startup, and before the entitlement is flipped.
  final bool pendingComplete;

  /// Store-supplied failure detail for [PurchaseState.error]; diagnostic only,
  /// never shown to the user (it is unlocalized and often a raw code).
  final String? error;

  /// Whether this event should grant the entitlement.
  bool get entitling =>
      state == PurchaseState.purchased || state == PurchaseState.restored;
}

/// The store-facing half of the Pro unlock.
abstract interface class PurchaseStore {
  /// Whether in-app purchases can be used at all on this device (no Play
  /// Services, a device without a store account, a locked-down profile).
  ///
  /// On the real plugin this **opens a billing connection**, so it is never
  /// called speculatively — the paywall entry point is the only caller.
  Future<bool> isAvailable();

  /// Resolves [ids] against the store. A product the store doesn't return —
  /// inactive in the console, not yet approved by review, unavailable in the
  /// user's country — is simply absent from the result, which is a normal
  /// state and not an error (see the no-product rule in `paywall_screen.dart`).
  Future<List<ProProduct>> queryProducts(Set<String> ids);

  /// Purchase and redelivery events. Hot: events can arrive at any time,
  /// including immediately after subscribing, for a purchase completed in a
  /// previous run of the app.
  Stream<PurchaseUpdate> get purchases;

  /// Starts the store's own purchase flow. Returns as soon as the flow is
  /// handed to the store — the outcome arrives on [purchases].
  Future<void> buy(ProProduct product);

  /// Re-queries what this store account already owns.
  ///
  /// Returns the owned purchases, **empty when the account owns nothing** —
  /// and throws when the store could not be asked. Those two must stay
  /// distinguishable, because the entitlement clearing policy hangs on it: a
  /// clean empty result is the only thing that may clear a cached unlock (see
  /// [ProEntitlementService.restore]).
  ///
  /// Phase 1 note: the plugin's `restorePurchases()` returns `Future<void>`
  /// and pushes the results onto its stream instead. Bridging that into this
  /// shape — subscribe, await, collect, bounded timeout — is the adapter's
  /// job, on purpose: it keeps the awkwardness in one file instead of in the
  /// entitlement policy.
  Future<List<PurchaseUpdate>> restore();

  /// Acknowledges [purchase] with the store. See [PurchaseUpdate.pendingComplete].
  Future<void> complete(PurchaseUpdate purchase);
}

/// ## Contract for the Phase-1 plugin adapter
///
/// Everything above is a shape; these are the rules that make it *correct*.
/// The whole acknowledgement story is only as good as this mapping, and every
/// item here has a way of failing silently in production while passing a
/// three-minute manual test.
///
/// 1. **`pendingComplete` maps from `PurchaseDetails.pendingCompletePurchase`,
///    and `complete()` calls `InAppPurchase.instance.completePurchase(details)`.**
///    Inverting the flag is a one-character bug that Play punishes by
///    auto-refunding every sale after three days (three *minutes* on a
///    license-tester account, where it reads as "restore is broken").
/// 2. **Never set `pendingComplete` on a [PurchaseState.pending] event.** Play
///    requires waiting for PURCHASED; iOS forbids finishing a deferred
///    transaction. [ProEntitlementService] guards this too, but the adapter
///    must not rely on that.
/// 3. **`PurchaseStatus.error` still needs completing.** iOS re-delivers an
///    unfinished failed transaction on every launch forever. Map it to
///    [PurchaseState.error] with `pendingComplete` as the plugin reports it —
///    do not "helpfully" suppress it.
/// 4. **[restore] must distinguish empty from failed.** The plugin's
///    `restorePurchases()` returns `Future<void>` and pushes results onto its
///    stream, so the adapter has to subscribe, await, collect, and return —
///    with a bounded timeout. Returning `[]` when the query actually *failed*
///    silently downgrades a paying customer at launch, because a clean empty
///    result is the one thing allowed to clear the cached unlock.
/// 5. **Verify the plugin re-delivers unacknowledged purchases on connect**
///    without an explicit `restorePurchases()` call. [ProEntitlementService]'s
///    startup path skips the query when nothing is cached, and relies on the
///    stream for the "killed between paying and recording" case. If a given
///    plugin version does not emit on connect, that skip has to go.
/// 6. **Test the adapter against a fake plugin**, not only against a live
///    store: the states that matter most (pending, error, redelivery, a
///    failing `completePurchase`) are the ones a manual store test will not
///    produce on demand.

/// The store that isn't: no billing integration is compiled into this build.
///
/// Every method answers the way a device with no store would, so the whole
/// entitlement path above it runs — and provably grants nothing. This is what
/// ships in Phase 0.
class NoPurchaseStore implements PurchaseStore {
  const NoPurchaseStore();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<ProProduct>> queryProducts(Set<String> ids) async => const [];

  @override
  Stream<PurchaseUpdate> get purchases => const Stream.empty();

  @override
  Future<void> buy(ProProduct product) async {
    throw StateError('No purchase mechanism is compiled into this build');
  }

  /// A *clean empty* result: this build cannot own anything. Harmless for the
  /// clearing policy — the cached flag it would clear can only have been set
  /// by the P0-6 test rig.
  @override
  Future<List<PurchaseUpdate>> restore() async => const [];

  @override
  Future<void> complete(PurchaseUpdate purchase) async {}
}

/// Scriptable [PurchaseStore] for tests and the `REEF_PRO_TEST` rig.
///
/// Lives in `lib/`, not `test/`, because the rig (a real, if hidden, screen)
/// needs it too — the same reason the emulator fakes under `tool/` are
/// importable.
class FakePurchaseStore implements PurchaseStore {
  FakePurchaseStore({
    this.available = true,
    List<ProProduct>? products,
    this.owned = const [],
    this.restoreThrows = false,
  }) : products =
           products ??
           const [
             ProProduct(
               id: kProUnlockProductId,
               title: 'ReefTracker Pro',
               price: '4,99 €',
             ),
           ];

  bool available;
  List<ProProduct> products;

  /// What [restore] reports as already owned.
  List<PurchaseUpdate> owned;

  /// Makes [restore] throw — the "store could not be asked" case, which must
  /// never clear a cached entitlement.
  bool restoreThrows;

  /// Makes [complete] throw, so the acknowledgement-retry path can be tested:
  /// the unlock must still be granted, and the next startup must re-try.
  bool completeThrows = false;

  /// Every event [complete] was called for, so tests can assert the
  /// acknowledgement contract instead of trusting it.
  final List<PurchaseUpdate> completed = [];

  final StreamController<PurchaseUpdate> _controller =
      StreamController<PurchaseUpdate>.broadcast();

  /// Pushes an event as the store would.
  void emit(PurchaseUpdate update) => _controller.add(update);

  /// The common case: a successful purchase that still needs acknowledging.
  void emitPurchased() => emit(
    const PurchaseUpdate(
      productId: kProUnlockProductId,
      state: PurchaseState.purchased,
      pendingComplete: true,
    ),
  );

  void dispose() => unawaited(_controller.close());

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<ProProduct>> queryProducts(Set<String> ids) async =>
      products.where((p) => ids.contains(p.id)).toList();

  @override
  Stream<PurchaseUpdate> get purchases => _controller.stream;

  /// Buys, **and remembers the sale** the way a real store does.
  ///
  /// Without recording it, the next launch's startup reconciliation asks
  /// [restore], gets a clean empty result, and correctly applies the clearing
  /// rule — so Pro silently evaporates on restart. That is right for the
  /// entitlement code and wrong for a fake: it made the rig unusable for
  /// exactly the "does my unlock survive a restart?" check it exists to
  /// answer. Recorded as already acknowledged, since the buy path just did.
  @override
  Future<void> buy(ProProduct product) async {
    owned = [
      ...owned,
      PurchaseUpdate(
        productId: product.id,
        state: PurchaseState.restored,
        pendingComplete: false,
      ),
    ];
    emitPurchased();
  }

  @override
  Future<List<PurchaseUpdate>> restore() async {
    if (restoreThrows) throw StateError('store unreachable');
    return owned;
  }

  @override
  Future<void> complete(PurchaseUpdate purchase) async {
    if (completeThrows) throw StateError('acknowledgement failed');
    completed.add(purchase);
  }
}
