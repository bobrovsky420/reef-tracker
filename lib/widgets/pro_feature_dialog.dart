import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../data/purchases.dart';
import '../domain/pro_features.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';

/// A capability boundary for a whole route whose contents require [boundary].
///
/// Gated buttons still use [runProCapabilityGated] so an entitled user navigates straight
/// through and a locked user sees the purchase entry point before navigation.
/// This widget is the second, security-relevant line of defence: restored
/// navigation, direct URLs and future callers cannot invoke [builder] unless
/// the entitlement is currently held. Because the provider is watched, losing
/// the entitlement while the route is open disposes the paid screen
/// immediately (including any camera/BLE resources it owns).
class ProCapabilityRoute extends ConsumerWidget {
  const ProCapabilityRoute({
    super.key,
    required this.boundary,
    required this.builder,
  });

  final ProCapabilityBoundary boundary;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feature = proCapabilityContract(boundary).feature;
    if (ref.watch(proCapabilityProvider(boundary))) return builder(context);

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.proFeatureName(feature))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  size: 48,
                  color: ReefTokens.of(context).primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l.proFeatureTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l.proFeatureBody(l.proFeatureName(feature)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: Text(
                    MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The entry point for every Pro-gated action (U19) — **and the switch that
/// decides whether a paywall exists at all on this device.**
///
/// Returns whether the caller may now go ahead: true only when the user came
/// back from the paywall with the unlock in hand, so a gated action can resume
/// instead of making the user find it again. Every call site is written to
/// respect that (P0-4).
///
/// If no product resolves — the store is absent, the console product is
/// inactive, the iOS IAP is unapproved, or (today, always) the build contains
/// no billing library at all — this shows the informational dialog and returns
/// false. That rule, not a feature flag, is what keeps a half-configured store
/// from ever showing a buy button that cannot work.
///
/// [body] replaces the generic "… is part of ReefTracker Pro." line when the
/// gate needs more context (e.g. the tank cap explains the limit).
Future<bool> requestProCapability(
  BuildContext context,
  WidgetRef ref,
  ProCapabilityBoundary boundary, {
  String? body,
}) async {
  if (ref.read(proCapabilityProvider(boundary))) return true;
  final feature = proCapabilityContract(boundary).feature;
  if (await _productResolves(context)) {
    if (!context.mounted) return false;
    await context.push<bool>('/paywall', extra: feature);
    if (!context.mounted) return false;
    // The route result is advisory. Re-read the persisted purchase because
    // the paywall can pop in the microtask before the store's watch event has
    // rebuilt `entitlementProvider`; the original intent must still resume
    // exactly once after a successful purchase/restore.
    final current = ref.read(entitlementProvider);
    final purchased = await ref.read(proEntitlementStoreProvider).read();
    return hasProCapability(
      boundary,
      purchased: purchased,
      legacyFree: current.founder,
    );
  }
  if (!context.mounted) return false;
  final l = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      // Minimal REDESIGN #25 pass: token-accented icon only — the dialog
      // surface itself inherits the #1 theme; a designed paywall is out of
      // redesign scope.
      icon: Icon(
        Icons.workspace_premium_outlined,
        color: ReefTokens.of(context).primary,
      ),
      title: Text(l.proFeatureTitle),
      content: Text(body ?? l.proFeatureBody(l.proFeatureName(feature))),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  );
  return false;
}

/// Runs [action] when this install may use [feature]; otherwise opens the Pro
/// gate first and runs it anyway if the user comes back entitled.
///
/// This is the shape every gated action had to be written in by hand — read
/// the gate, branch, and (before P0-4) silently drop the user on the floor
/// after a purchase, because the dialog reported nothing. One helper means
/// "success resumes what you were doing" is a property of the gate rather than
/// of seventeen call sites remembering to implement it.
Future<void> runProCapabilityGated(
  BuildContext context,
  WidgetRef ref,
  ProCapabilityBoundary boundary,
  FutureOr<void> Function() action, {
  String? body,
}) async {
  if (await requestProCapability(context, ref, boundary, body: body) &&
      context.mounted) {
    await action();
  }
}

/// Whether the Pro unlock can actually be bought right now. Cheap and
/// synchronous-ish in every shipped build: [NoPurchaseStore.isAvailable]
/// answers false without touching a network or a billing connection.
Future<bool> _productResolves(BuildContext context) async {
  final store = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(purchaseStoreProvider);
  try {
    if (!await store.isAvailable()) return false;
    return (await store.queryProducts({kProUnlockProductId})).isNotEmpty;
  } on Object {
    // A store that throws on being asked is a store that cannot sell.
    return false;
  }
}
