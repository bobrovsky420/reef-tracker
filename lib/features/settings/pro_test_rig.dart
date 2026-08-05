import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/entitlement.dart';
import '../../data/purchases.dart';
import '../../widgets/reef_settings.dart';
import '../../widgets/section_header.dart';

/// Whether this build carries the U19 entitlement test rig.
///
/// **Not `kDebugMode`, deliberately.** Play internal testing and TestFlight
/// artifacts are *release* builds, so a debug-only rig would be compiled out of
/// exactly the builds that can transact with a real store — which is where the
/// purchase matrix has to be run (§10 P5/S4). A `--dart-define` is the one
/// switch that can be turned on for a release build without turning it on for
/// a store submission.
///
/// Hard rule that comes with it: an artifact built with this define goes to
/// the internal / TestFlight tracks and **never** to a store submission.
///
/// Accepts `=true` **and** `=1`, because `bool.fromEnvironment` recognises
/// only the exact string `true` — `--dart-define=REEF_PRO_TEST=1` silently
/// evaluates to false, and the only symptom is that the section below never
/// appears, which reads as "the rig is broken" rather than "the flag spelling
/// is wrong". Both spellings are const-folded, so a build without the define
/// still tree-shakes this file's UI away.
const bool kProTestRig =
    bool.fromEnvironment('REEF_PRO_TEST') ||
    String.fromEnvironment('REEF_PRO_TEST') == '1';

/// The store the rig talks to: a [FakePurchaseStore] with a resolvable
/// product, so the paywall's buy path can be exercised without a live console
/// product. Wired in `main.dart` and only when [kProTestRig].
final proTestPurchaseStore = FakePurchaseStore();

/// Teaches the fake store what this device already owns, from the persisted
/// entitlement, before the startup reconciliation runs.
///
/// A real store account remembers a purchase across restarts; a fresh
/// [FakePurchaseStore] does not. Without this, the rig's own edition radio —
/// which writes the entitlement directly rather than going through a buy —
/// would be undone on the next launch: `restoreAtStartup` asks the store, gets
/// a clean empty answer, and correctly applies the clearing rule. Correct
/// behaviour, useless rig. Only ever called from a [kProTestRig] build.
Future<void> seedProTestStoreFromDisk(ProEntitlementStore entitlement) async {
  if (!await entitlement.read()) return;
  proTestPurchaseStore.owned = const [
    PurchaseUpdate(
      productId: kProUnlockProductId,
      state: PurchaseState.restored,
      pendingComplete: false,
    ),
  ];
}

/// Settings section for driving the entitlement states on a real device
/// (U19 Stage A0 / P0-6), replacing the "temp-disable `_seedEdition` and push
/// a marker-less seed database" ritual.
///
/// It sets the **real** state rather than an override: the marker row and the
/// entitlement file are what every reader consults, including
/// `completeWelcomeRestore`, which runs outside Riverpod and would quietly
/// miss an override layer. Nothing to plumb, nothing to drift.
///
/// Strings are hardcoded English on purpose — this section cannot appear in
/// any shipped build, and seven translations of "Seeder off" would be waste.
class ProTestRigSection extends ConsumerWidget {
  const ProTestRigSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider);
    final seederOffAsync = ref.watch(proSeederOffProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Pro test rig (REEF_PRO_TEST)'),
        for (final (label, founder, pro) in const [
          ('Standard', false, false),
          ("Founder's Edition", true, false),
          ('Pro', false, true),
          ("Founder's Edition + Pro", true, true),
        ])
          ReefSettingsRow(
            icon: entitlement.founder == founder && entitlement.purchased == pro
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            title: label,
            onTap: () => unawaited(_apply(ref, founder: founder, pro: pro)),
          ),
        ReefSettingsRow(
          icon: Icons.hourglass_disabled_outlined,
          title: 'Founder seeder off',
          description: (seederOffAsync.value ?? false)
              ? 'Launch will NOT re-mint the marker'
              : 'Launch re-mints the marker (production behaviour)',
          onTap: () => unawaited(
            ref
                .read(settingsProvider)
                .setProSeederOff(!(seederOffAsync.value ?? false)),
          ),
        ),
        ReefSettingsRow(
          icon: Icons.workspace_premium_outlined,
          title: 'Open paywall directly',
          description: 'Bypasses the no-product rule',
          onTap: () => unawaited(context.push<bool>('/paywall')),
        ),
        ReefSettingsRow(
          icon: Icons.storefront_outlined,
          title: proTestPurchaseStore.available
              ? 'Fake store: available'
              : 'Fake store: unavailable',
          description: 'Toggles what isAvailable()/queryProducts() answer',
          onTap: () {
            proTestPurchaseStore.available = !proTestPurchaseStore.available;
            // No provider holds this flag — nudge the row to repaint.
            ref.invalidate(entitlementProvider);
          },
        ),
      ],
    );
  }

  /// Puts the device into the requested state for real: the marker row and the
  /// backup-excluded entitlement file. Selecting a marker-less state also
  /// switches the seeder off, or the next launch would undo it.
  Future<void> _apply(
    WidgetRef ref, {
    required bool founder,
    required bool pro,
  }) async {
    final settings = ref.read(settingsProvider);
    if (founder) {
      // Version name only, no `+build` — the same string `_seedEdition` writes.
      await settings.seedLegacyFreeSince(
        (await ref.read(appVersionProvider.future)).split('+').first,
      );
    } else {
      await settings.clearLegacyFreeSince();
    }
    await settings.setProSeederOff(!founder);
    await ref.read(proEntitlementStoreProvider).write(pro);
  }
}
