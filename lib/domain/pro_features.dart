/// Pro-tier feature gating (U19). Pure domain — no Flutter, no DB.
///
/// The feature list and the grandfathered set are GENERATED from
/// `pro_features.yaml` (edit the YAML, then
/// `dart run tool/gen_pro_features.dart`). Which features are paid is a
/// one-line YAML decision; this file only owns the gate rule.
///
/// Entitlement sources (see `Entitlement` in `data/entitlement.dart`, surfaced
/// by `entitlementProvider` / `proFeatureProvider` in `app/providers.dart`):
/// - `purchased` — the Pro in-app purchase, held device-locally. The store
///   integration is built but dormant: the only [PurchaseStore] compiled in
///   resolves no product, so nothing outside the test rig can set this.
/// - `legacyFree` — the early-adopter marker (`legacy_free_since`, seeded by
///   every pre-activation build): those installs keep every *grandfathered*
///   feature free forever. Features added to the registry with
///   `grandfathered: false` after the cutoff are paid for everyone.
library;

part 'pro_features.g.dart';

/// Whether an install with the given entitlements may use [feature].
bool hasProFeature(
  ProFeature feature, {
  required bool purchased,
  required bool legacyFree,
}) => purchased || (legacyFree && kGrandfatheredFeatures.contains(feature));

/// The app version whose release **activates** the paid tier — the release
/// that stops seeding the founder marker and turns the paywall live.
///
/// Null for the whole dormant period (§10 Stage A0 / P0-8), which makes
/// [markerGrantsFounder] behave exactly as before: presence of the marker
/// alone grants Founder's Edition.
///
/// Why the constant exists now, unused: once Founder status is worth money the
/// marker becomes a forgeable, transferable license key — it is one settings
/// row, it rides backups deliberately (U19 clause (b)), it is excluded from
/// `backupContentHash`, and `restoreFromBackup` accepts a backup whose
/// `checksum` key is simply absent. "Delete one line, add one row" mints a
/// Founder in a text editor. Setting this at activation blunts that to
/// "claim you were early", using data the marker already stores.
///
/// It is also what makes the rollback valve reversible. Re-enabling the seeder
/// in a patch mints more Founders and locks nobody out — but a marker minted
/// that way is otherwise indistinguishable from a genuine 0.26.0 one forever,
/// so the entire post-activation Standard population would become
/// free-forever with no path back. With this set, a rollback-minted marker
/// carries a version >= activation and is simply not honoured.
///
/// **How to actually roll back** (§10 D4; contingency, not a planned step —
/// and note neither store lets you re-publish an older version, so a rollback
/// is a *new* release that behaves like the old one): ship a patch that
/// re-enables `_seedEdition` **and raises this constant above that patch's own
/// version**. Everyone from the sale window then satisfies
/// `markerVersion < kActivationVersion` and is a Founder again on next launch
/// — including anyone who paid, so a refund cannot cost them access. Doing
/// only the first half is the trap: the markers it mints are worthless, and
/// nothing changes.
const String? kActivationVersion = null;

/// Whether a `legacy_free_since` marker stamped by [markerVersion] grants
/// Founder's Edition. Null/empty means no marker at all.
///
/// While [kActivationVersion] is null every marker counts — the dormant-period
/// behaviour, unchanged. Once it is set, only markers written by a build that
/// predates activation do, so seeding is what earns the status and forging it
/// after the fact requires claiming a version you never ran.
bool markerGrantsFounder(String? markerVersion) {
  if (markerVersion == null || markerVersion.isEmpty) return false;
  final activation = kActivationVersion;
  if (activation == null) return true;
  return compareAppVersions(markerVersion, activation) < 0;
}

/// Compares two `major.minor.patch` version names, ignoring any `+build`
/// suffix and any trailing junk on a component. Returns <0, 0 or >0 like
/// [Comparable.compareTo].
///
/// Missing components read as 0 ("1.2" == "1.2.0"), and a component that
/// isn't a number reads as 0 rather than throwing: this decides an
/// entitlement, and the only marker values that can reach it are ones the app
/// itself wrote — a garbled one should degrade to "oldest possible", never to
/// a crash on launch.
int compareAppVersions(String a, String b) {
  final left = _versionParts(a);
  final right = _versionParts(b);
  for (var i = 0; i < 3; i++) {
    final diff = left[i].compareTo(right[i]);
    if (diff != 0) return diff;
  }
  return 0;
}

List<int> _versionParts(String version) {
  final name = version.split('+').first.trim();
  final parts = name.split('.');
  return [
    for (var i = 0; i < 3; i++)
      i < parts.length ? (int.tryParse(parts[i].trim()) ?? 0) : 0,
  ];
}

/// How many aquariums a non-entitled install may hold: a display tank plus a
/// quarantine tank, so the free tier never penalizes quarantining.
const int kFreeTankLimit = 2;

/// Whether an install already holding [tankCount] live (non-deleted) aquariums
/// may create another. The cap gates only CREATION — existing tanks beyond the
/// limit (restored backup, lapsed entitlement) stay fully usable; data is
/// never locked away. [unlimitedTanks] is the caller's
/// `ProFeature.unlimitedTanks` gate result.
bool canCreateTank(int tankCount, {required bool unlimitedTanks}) =>
    unlimitedTanks || tankCount < kFreeTankLimit;
