import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/entitlement.dart';
import '../../data/purchases.dart';
import '../../domain/pro_features.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';

/// The paywall (U19), route `/paywall`, optionally carrying the [ProFeature]
/// the user was reaching for as `extra`.
///
/// **Unreachable in every build shipped so far**, by two independent
/// properties rather than by intent: `requestProCapability` only navigates
/// here when a product actually resolves — and the only [PurchaseStore]
/// compiled in is [NoPurchaseStore], which resolves nothing — while the
/// dormancy invariant (`test/pro_features_test.dart`) keeps every registry
/// entry grandfathered, so no gate closes on anyone in the first place. This
/// screen exists now so that activating the paid tier is a small release
/// rather than a large one.
///
/// Price comes from the store, never from the app: the consoles own pricing,
/// currency and formatting, and a hardcoded figure is both wrong somewhere in
/// the world and a review finding.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.feature});

  /// What the user tapped, so the screen can say what they were after.
  final ProFeature? feature;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// Null while the store is still being asked; the empty list is the
  /// **no product resolved** state (inactive in the console, not yet approved
  /// by review, unavailable in this country, or no store at all) — a first-
  /// class state, not an error.
  List<ProProduct>? _products;
  bool _storeAvailable = true;
  bool _busy = false;
  PurchaseOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    // Redelivered purchases (killed between paying and acknowledging) arrive
    // on this stream, so the listener must be up before anything else.
    ref.read(proEntitlementServiceProvider).start();
    unawaited(_load());
  }

  Future<void> _load() async {
    final store = ref.read(purchaseStoreProvider);
    var available = false;
    var products = const <ProProduct>[];
    try {
      available = await store.isAvailable();
      if (available) {
        products = await store.queryProducts({kProUnlockProductId});
      }
    } on Object {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _storeAvailable = available;
      _products = products;
    });
  }

  Future<void> _run(Future<PurchaseOutcome> Function() action) async {
    setState(() => _busy = true);
    final outcome = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
  }

  Future<void> _buy() async {
    final products = _products;
    if (products == null || products.isEmpty) return;
    await _run(
      () => ref.read(proEntitlementServiceProvider).buy(products.first),
    );
  }

  Future<void> _restore() =>
      _run(ref.read(proEntitlementServiceProvider).restore);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final products = _products;
    final unlocked =
        _outcome == PurchaseOutcome.purchased ||
        _outcome == PurchaseOutcome.restored;

    return Scaffold(
      appBar: AppBar(title: Text(l.paywallTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 56,
            color: tokens.primary,
          ),
          const SizedBox(height: 20),
          if (widget.feature case final feature?)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.proFeatureBody(l.proFeatureName(feature)),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          Text(l.paywallIntro, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (unlocked)
            FilledButton(
              // Returns true so the gated action the user was reaching for
              // resumes — the reason `requestProCapability` returns a bool.
              onPressed: () => context.pop(true),
              child: Text(
                MaterialLocalizations.of(context).continueButtonLabel,
              ),
            )
          else ...[
            // THE NO-PRODUCT RULE: no product, no buy button. It is guaranteed
            // while the console product is inactive, normal on a device with
            // no store, and exactly what an App Review device would hit if the
            // activation release were mis-sequenced. Offering a button that
            // cannot work is worse than offering none.
            if (products != null && products.isNotEmpty)
              FilledButton(
                onPressed: _buy,
                child: Text(l.paywallBuy(products.first.price)),
              ),
            const SizedBox(height: 8),
            // Always visible, never conditional: Apple requires a restore
            // control on any screen that sells a non-consumable.
            TextButton(onPressed: _restore, child: Text(l.paywallRestore)),
          ],
          if (_message(l) case final message?)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(message, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  String? _message(AppLocalizations l) {
    if (_busy) return l.paywallWorking;
    if (!_storeAvailable) return l.paywallUnavailable;
    return switch (_outcome) {
      PurchaseOutcome.purchased => l.paywallPurchased,
      PurchaseOutcome.restored => l.paywallRestored,
      PurchaseOutcome.nothingToRestore => l.paywallNothingToRestore,
      PurchaseOutcome.pending => l.paywallPending,
      PurchaseOutcome.failed => l.paywallFailed,
      // Backing out of the store's own sheet is not a failure — say nothing.
      PurchaseOutcome.canceled => null,
      null => null,
    };
  }
}
