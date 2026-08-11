/// Wall display mode (U49) — the pure, testable core: the night-dim window,
/// the per-device poll schedule (error + no-change backoff over a per-kind
/// floor), the sample bucketing rule, the card set (one card per device *and*
/// parameter, §12q) and per-tile value resolution. No Flutter, no DB — the
/// screen (`features/wall/wall_screen.dart`) and the settings subpage are thin
/// shells over this file, which is what the unit tests pin.
library;

import 'package:meta/meta.dart';

part 'wall_parameters.g.dart';

// --- Configuration constants -------------------------------------------------

/// The refresh intervals the settings subpage offers, in seconds. The value is
/// stored as its second count so an unknown stored value (a removed choice)
/// can fall back rather than crash a dropdown.
const List<int> kWallRefreshChoicesSeconds = [30, 60, 300, 900];

/// Default display refresh: 5 min. Deliberately not 1 min — a wall tablet
/// polls all day, every day, and 5 min is fresh enough for water chemistry.
const int kWallDefaultRefreshSeconds = 300;

/// Ceiling for both backoff mechanisms: a device that dropped off the LAN is
/// retried at most every 30 min, all night, instead of being hammered.
const Duration kWallBackoffCeiling = Duration(minutes: 30);

/// Consecutive polls with an unchanged payload before the change-based backoff
/// starts doubling a device's own interval (§12n item 3).
const int kWallUnchangedPollsBeforeBackoff = 6;

/// Sample-table bucket width: at most one row per (device, parameter) per
/// bucket, whatever the poll interval, carrying last/min/max (§12m).
const Duration kWallSampleBucket = Duration(minutes: 5);

/// How long sample rows are kept — 48 h rather than 24 so the 24 h window is
/// always full at its far edge.
const Duration kWallSampleRetention = Duration(hours: 48);

/// The tile graph's time window over `DeviceSamples`.
const Duration kWallSampleWindow = Duration(hours: 24);

/// Fallback tile-graph window over stored `Readings` when fewer than
/// [kWallMinSamplePoints] samples exist — the dashboard card's 14-day line.
const Duration kWallReadingsWindow = Duration(days: 14);

/// Minimum in-window sample points before the 24 h line is drawn; below it the
/// tile falls back to the 14-day readings sparkline (an empty/one-point graph
/// on half the grid would look broken, §12m).
const int kWallMinSamplePoints = 2;

/// Prune cadence: the delete-by-age sweep runs on every Nth poll cycle (plus
/// once at mode start) rather than on every write.
const int kWallPruneEveryCycles = 12;

/// Night-dim defaults: 22:00–07:00, as minutes since midnight.
const int kWallDefaultNightFromMinutes = 22 * 60;
const int kWallDefaultNightToMinutes = 7 * 60;

/// How long a tap lifts the night dim.
const Duration kWallNightLift = Duration(seconds: 60);

/// Page auto-rotation choices and default, in seconds (§12c).
const List<int> kWallPageSecondsChoices = [10, 15, 30, 60];
const int kWallDefaultPageSeconds = 15;

/// How long the exit long-press must be held (§12f).
const Duration kWallExitHold = Duration(milliseconds: 1500);

/// How often the whole grid shifts a few pixels against burn-in (§12e).
const Duration kWallBurnInShiftEvery = Duration(minutes: 10);

/// The burn-in shift lattice, in logical pixels — a slow orbit of small
/// offsets the content cycles through.
const List<(double dx, double dy)> kWallBurnInOffsets = [
  (0, 0),
  (3, 2),
  (0, 4),
  (-3, 2),
  (-3, -2),
  (0, -4),
  (3, -2),
];

/// Below this logical shortest-side (dp) the settings subpage shows the
/// phone-class advisory. Physical inches are not knowable from Flutter, so the
/// standard 600 dp tablet threshold is the honest proxy. Informational only —
/// nothing about the mode is gated by screen size (§12c: the grid adapts).
const double kWallPhoneClassShortestSide = 600;

/// The `deviceIdentifier` value of the no-device cards (a tracked parameter no
/// device reports, fed by the last stored reading). An empty string, not null:
/// SQLite treats NULLs as distinct in a unique index, so a nullable key column
/// would silently admit duplicate rows for the same parameter (§12q).
const String kWallNoDevice = '';

// --- Night window ------------------------------------------------------------

/// Whether [minutesOfDay] (0–1439) falls inside the night-dim window
/// `[from, to)`, both as minutes since midnight. Handles a window crossing
/// midnight (22:00–07:00). A degenerate window (`from == to`) never dims —
/// the honest reading of "from 9:00 to 9:00".
bool inNightWindow(int minutesOfDay, {required int from, required int to}) {
  if (from == to) return false;
  if (from < to) return minutesOfDay >= from && minutesOfDay < to;
  return minutesOfDay >= from || minutesOfDay < to;
}

// --- Sample bucketing --------------------------------------------------------

/// The start of the [kWallSampleBucket]-wide bucket containing [t]. Floored on
/// the epoch millisecond axis, so the rule is timezone-independent and two
/// polls 30 s apart land in the same row.
DateTime bucketStartFor(DateTime t, {Duration bucket = kWallSampleBucket}) {
  final ms = bucket.inMilliseconds;
  return DateTime.fromMillisecondsSinceEpoch(
    (t.millisecondsSinceEpoch ~/ ms) * ms,
  );
}

// --- Poll schedule -----------------------------------------------------------

/// The effective interval before a device's next poll, from the display
/// interval [base] and the device's current backoff state.
///
/// - [floor] is the per-kind minimum ([minPollIntervalOf]) — a batch device
///   is never read faster than it can produce a new number, whatever the
///   user picked.
/// - [failures] doubles the interval per consecutive failed poll (§12d).
/// - [unchangedPolls] doubles it once per consecutive unchanged payload
///   *beyond* [kWallUnchangedPollsBeforeBackoff] (§12n item 3).
///
/// Both triggers share one mechanism and one [kWallBackoffCeiling]; the first
/// success (or the first changed payload) resets its counter and the interval
/// snaps back to [base].
Duration wallPollInterval({
  required Duration base,
  Duration? floor,
  int failures = 0,
  int unchangedPolls = 0,
}) {
  var interval = (floor != null && floor > base) ? floor : base;
  final doublings =
      failures +
      (unchangedPolls > kWallUnchangedPollsBeforeBackoff
          ? unchangedPolls - kWallUnchangedPollsBeforeBackoff
          : 0);
  for (var i = 0; i < doublings; i++) {
    interval *= 2;
    if (interval >= kWallBackoffCeiling) return kWallBackoffCeiling;
  }
  return interval > kWallBackoffCeiling ? kWallBackoffCeiling : interval;
}

/// Per-device poll bookkeeping for the wall's single ticker: each device
/// carries a `nextDue` stamp and is read when it comes up (§12n). Mutable by
/// design — the screen owns one per device identifier.
class WallPollSchedule {
  WallPollSchedule({this.floor});

  /// Per-kind minimum interval, or null for continuous probes.
  final Duration? floor;

  /// When the device should next be read. Epoch = due immediately (mode
  /// start).
  DateTime nextDue = DateTime.fromMillisecondsSinceEpoch(0);

  /// Consecutive failed polls (reset by the first success).
  int failures = 0;

  /// Consecutive polls whose payload signature was unchanged (reset by the
  /// first change — and by a failure, which is itself a change of state).
  int unchangedPolls = 0;

  /// Signature of the last successful payload ([wallPayloadSignature]).
  String? lastSignature;

  bool isDue(DateTime now) => !now.isBefore(nextDue);

  /// Records a successful read of a payload with [signature] and schedules
  /// the next one.
  void onSuccess(DateTime now, Duration base, String signature) {
    failures = 0;
    if (signature == lastSignature) {
      unchangedPolls++;
    } else {
      unchangedPolls = 0;
    }
    lastSignature = signature;
    nextDue = now.add(
      wallPollInterval(
        base: base,
        floor: floor,
        unchangedPolls: unchangedPolls,
      ),
    );
  }

  /// Records a failed read and backs off (§12d): the tile keeps its last
  /// value and ages it visibly; this only decides when to knock again.
  void onFailure(DateTime now, Duration base) {
    failures++;
    unchangedPolls = 0;
    nextDue = now.add(
      wallPollInterval(base: base, floor: floor, failures: failures),
    );
  }
}

/// A stable signature of a device's reported values, for the change-based
/// backoff. Order-independent so a reordered readings list doesn't read as a
/// change.
String wallPayloadSignature(
  Iterable<({String paramKey, double value})> values,
) {
  final parts = [for (final v in values) '${v.paramKey}=${v.value}']..sort();
  return parts.join(';');
}

// --- Card model (§12q) -------------------------------------------------------

/// One wall card: a (device, parameter) pair, [kWallNoDevice] for the
/// stored-readings card of a parameter no device reports.
typedef WallCardId = ({String deviceIdentifier, String paramKey});

/// A decoded `wall_tile_settings` row (the sparse side table, §12o/§12q).
/// [displayOrder] null = never explicitly ordered (default order applies, and
/// the card appends after all explicitly ordered ones).
@immutable
class WallTileConfig {
  const WallTileConfig({
    required this.deviceIdentifier,
    required this.paramKey,
    this.displayOrder,
    this.visible = true,
  });

  final String deviceIdentifier;
  final String paramKey;
  final int? displayOrder;
  final bool visible;

  WallCardId get id => (deviceIdentifier: deviceIdentifier, paramKey: paramKey);
}

/// One resolved wall card: identity plus effective visibility.
@immutable
class WallCard {
  const WallCard({required this.id, required this.visible});

  final WallCardId id;
  final bool visible;
}

/// Whether a device is **muted**: it has at least one stored card row and
/// every row it has is hidden. New cards from a muted device default to
/// hidden, so a firmware update that grows a third reading cannot quietly
/// return a deliberately silenced device to the poll rotation (§12q);
/// un-hiding any card clears the mute by construction.
bool isWallDeviceMuted(String identifier, List<WallTileConfig> rows) {
  var any = false;
  for (final r in rows) {
    if (r.deviceIdentifier != identifier) continue;
    if (r.visible) return false;
    any = true;
  }
  return any;
}

/// Builds the full wall card list — visible and hidden — from what is known:
///
/// - [trackedKeys]: the tank's enabled tracked parameters, in dashboard
///   order. Each yields a no-device card *unless* some device reports it.
/// - [reportedByDevice]: device identifier → the parameter keys it reports,
///   with the map's iteration order being the Devices-page order (vendor
///   order, then card order). Union of live snapshots and remembered rows —
///   the caller decides what it knows.
/// - [rows]: the stored `wall_tile_settings` rows for this tank.
///
/// Keys outside [kWallParameterKeys] (`wall_parameters.yaml`) — notably the
/// ICP microelements — never become cards, whatever a tank tracks or a
/// device claims to report.
///
/// Ordering: cards with a stored [WallTileConfig.displayOrder] first,
/// ascending; everything else follows in the default order — grouped by
/// parameter in tracked order (unknown parameters after, in first-seen order),
/// with the competing device cards for one parameter consecutive (§12q:
/// adjacency makes deduplication a couple of taps). New cards therefore
/// append after an explicit arrangement instead of interleaving into it.
List<WallCard> buildWallCards({
  required List<String> trackedKeys,
  required Map<String, List<String>> reportedByDevice,
  required List<WallTileConfig> rows,
}) {
  // The catalogue gate: keys outside wall_parameters.yaml are dropped before
  // anything else happens, so an excluded key never gets a card, a stored
  // row, or a sample.
  final tracked = [
    for (final k in trackedKeys)
      if (kWallParameterKeys.contains(k)) k,
  ];
  final byDevice = <String, List<String>>{
    for (final e in reportedByDevice.entries)
      e.key: [
        for (final p in e.value)
          if (kWallParameterKeys.contains(p)) p,
      ],
  };

  final rowById = <WallCardId, WallTileConfig>{for (final r in rows) r.id: r};

  // Every parameter any device reports, and the card ids in default order.
  final reportedParams = <String>{};
  for (final params in byDevice.values) {
    reportedParams.addAll(params);
  }

  // Default parameter order: tracked order first, then unknown-but-reported
  // parameters in first-seen device order.
  final paramOrder = <String>[...tracked];
  for (final params in byDevice.values) {
    for (final p in params) {
      if (!paramOrder.contains(p)) paramOrder.add(p);
    }
  }

  final defaultOrder = <WallCardId>[
    for (final param in paramOrder) ...[
      // Device cards for this parameter, adjacent, in device page order.
      for (final e in byDevice.entries)
        if (e.value.contains(param)) (deviceIdentifier: e.key, paramKey: param),
      // The stored-readings card, only while no device covers the parameter.
      if (tracked.contains(param) && !reportedParams.contains(param))
        (deviceIdentifier: kWallNoDevice, paramKey: param),
    ],
  ];

  final ordered =
      <WallCardId>[
        for (final id in defaultOrder)
          if (rowById[id]?.displayOrder != null) id,
      ]..sort(
        (a, b) =>
            rowById[a]!.displayOrder!.compareTo(rowById[b]!.displayOrder!),
      );
  final unordered = [
    for (final id in defaultOrder)
      if (rowById[id]?.displayOrder == null) id,
  ];

  WallCard resolve(WallCardId id) {
    final row = rowById[id];
    final visible =
        row?.visible ??
        // No row: visible by default — unless the device is muted (§12q).
        !isWallDeviceMuted(id.deviceIdentifier, rows);
    return WallCard(id: id, visible: visible);
  }

  return [
    for (final id in [...ordered, ...unordered]) resolve(id),
  ];
}

/// The devices the wall's poll rotation contacts, given the card list: a
/// device with at least one visible card — or one whose cards are entirely
/// unknown yet (it must be read once to discover them). A device whose known
/// cards are all hidden leaves the rotation entirely, which is the real
/// traffic saving of hiding (§12q).
Set<String> wallPolledDevices(
  Iterable<String> deviceIdentifiers,
  List<WallCard> cards,
) {
  final known = <String>{};
  final visible = <String>{};
  for (final c in cards) {
    if (c.id.deviceIdentifier == kWallNoDevice) continue;
    known.add(c.id.deviceIdentifier);
    if (c.visible) visible.add(c.id.deviceIdentifier);
  }
  return {
    for (final id in deviceIdentifiers)
      if (!known.contains(id) || visible.contains(id)) id,
  };
}

// --- Tile value resolution ---------------------------------------------------

/// Where a tile's number comes from — the provenance line names it (§12b).
enum WallValueSource {
  /// This session's live poll result.
  live,

  /// The newest persisted `DeviceSamples` bucket (mode restarted; the poll
  /// hasn't landed yet, or keeps failing) — still the device's own value,
  /// aged honestly.
  sample,

  /// The last stored measurement (`Readings`) — the no-device card's truth.
  reading,

  /// Tracked, never measured. The tile says "no reading" — it is never blank
  /// and never a spinner.
  none,
}

/// A resolved tile value: what to print, how old it is, and where it came
/// from.
@immutable
class WallTileValue {
  const WallTileValue({this.value, this.at, required this.source});

  final double? value;
  final DateTime? at;
  final WallValueSource source;
}

/// Resolves one tile's number (§12b, amended by §12q): a device card shows
/// its own device's live value, falling back to that device's newest persisted
/// sample after a restart; the no-device card shows the last stored reading.
/// There is no cross-device fallback — what is on the wall is what the keeper
/// chose, and an aged value with an honest provenance line beats a value that
/// changes source under their feet.
WallTileValue resolveWallTileValue({
  required bool deviceCard,
  double? liveValue,
  DateTime? liveAt,
  double? sampleValue,
  DateTime? sampleAt,
  double? readingValue,
  DateTime? readingAt,
}) {
  if (deviceCard) {
    if (liveValue != null) {
      return WallTileValue(
        value: liveValue,
        at: liveAt,
        source: WallValueSource.live,
      );
    }
    if (sampleValue != null) {
      return WallTileValue(
        value: sampleValue,
        at: sampleAt,
        source: WallValueSource.sample,
      );
    }
    return const WallTileValue(source: WallValueSource.none);
  }
  if (readingValue != null) {
    return WallTileValue(
      value: readingValue,
      at: readingAt,
      source: WallValueSource.reading,
    );
  }
  return const WallTileValue(source: WallValueSource.none);
}
