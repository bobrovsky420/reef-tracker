import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/units.dart';
import '../../domain/wall_display.dart';
import '../../domain/zones.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/sparkline.dart';
import '../../widgets/zone_visuals.dart';

/// Everything one wall value card needs to draw itself, assembled by the
/// screen ([WallScreen]) from the live snapshots, the sample cache and the
/// stored readings — the tile itself holds no state and asks no provider.
class WallTileData {
  const WallTileData({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.value,
    required this.zone,
    required this.pres,
    this.line = const [],
    this.band = const [],
    this.markers = const [],
    this.window = kWallSampleWindow,
    this.isSampleWindow = true,
    this.operatingState,
  });

  final WallCardId id;

  /// Localized parameter name.
  final String title;

  /// The reporting device's display name; null for the stored-readings card.
  final String? sourceName;

  final WallTileValue value;
  final Zone zone;
  final ParamPresentation pres;

  /// The tile graph: line points, optional min/max band (samples only) and
  /// hand-measurement markers, over [window].
  final List<SparkPoint> line;
  final List<SparkBandPoint> band;
  final List<SparkPoint> markers;
  final Duration window;

  /// True = the 24 h sample line, false = the 14-day readings fallback. Named
  /// in the footer so two neighbouring tiles are never silently on different
  /// time scales (§12m).
  final bool isSampleWindow;

  /// A live output state that qualifies the value (currently the ReefFactory
  /// Temperature Controller's heating/cooling relay). Idle stays null.
  final WallOperatingState? operatingState;
}

enum WallOperatingState { heating, cooling }

/// One value card of the wall grid (§12b): parameter name, a graph filling
/// the middle, the value as large as the tile allows, and a provenance line
/// naming the source and its age. Never blank and never a spinner.
class WallValueTile extends StatelessWidget {
  const WallValueTile({super.key, required this.data, required this.now});

  final WallTileData data;

  /// One instant for the whole rebuilt page, so ages and windows agree.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final zone = data.zone;
    final v = data.value;
    final fill = zone == Zone.unknown
        ? cs.surfaceContainerLow
        : zone.softColorOf(context);
    final valueColor = zone == Zone.unknown
        ? cs.onSurface
        : zone.colorOf(context);
    final dim = cs.onSurfaceVariant;
    final state = data.operatingState;
    final stateLabel = switch (state) {
      WallOperatingState.heating => l.reefFactoryHeating,
      WallOperatingState.cooling => l.reefFactoryCooling,
      null => null,
    };

    final provenance = switch (v.source) {
      WallValueSource.live || WallValueSource.sample =>
        '${data.sourceName ?? ''} · '
            '${relativeTimeLabel(l, v.at ?? now, now: now)}',
      WallValueSource.reading => l.wallMeasuredAgo(
        relativeTimeLabel(l, v.at ?? now, now: now),
      ),
      WallValueSource.none => l.noReadings,
    };

    final zoneLabel = switch (zone) {
      Zone.green => l.zoneOk,
      Zone.amber => l.zoneAttention,
      Zone.red => l.zoneActNow,
      Zone.unknown => l.zoneUnknown,
    };

    return Semantics(
      label: v.value == null
          ? '${data.title}: ${l.noReadings}'
          : '${data.title}: ${data.pres.format(v.value!)} '
                '${data.pres.unitLabel}, $zoneLabel'
                '${stateLabel == null ? '' : ', $stateLabel'}',
      container: true,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dim,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (stateLabel != null) ...[
                    const SizedBox(width: 8),
                    _OperatingStateBadge(state: state!, label: stateLabel),
                  ],
                ],
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 5,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: v.value == null
                            ? Text(
                                '—',
                                style: TextStyle(fontSize: 44, color: dim),
                              )
                            : Text.rich(
                                TextSpan(
                                  text: data.pres.format(v.value!),
                                  style: TextStyle(
                                    fontSize: 52,
                                    height: 1.05,
                                    fontWeight: FontWeight.w700,
                                    color: valueColor,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' ${data.pres.unitLabel}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: dim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    if (data.line.isNotEmpty || data.band.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 2),
                            child: Sparkline(
                              points: data.line,
                              band: data.band,
                              markers: data.markers,
                              window: data.window,
                              endAt: now,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      provenance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: dim),
                    ),
                  ),
                  if (data.line.isNotEmpty)
                    Text(
                      data.isSampleWindow ? l.wallWindow24h : l.wallWindow14d,
                      style: TextStyle(fontSize: 11, color: dim),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperatingStateBadge extends StatelessWidget {
  const _OperatingStateBadge({required this.state, required this.label});

  final WallOperatingState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = ReefTokens.of(context);
    final (color, fill) = switch (state) {
      WallOperatingState.heating => (tokens.caution, tokens.cautionSoft),
      WallOperatingState.cooling => (
        tokens.primary,
        tokens.primary.withValues(alpha: 0.14),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The doser tile's compact duration: precise days while under 100 (every
/// amber/red state lives there), rounded 30-day months beyond — "68 days",
/// "4 months". The smallest months value is 3, so an ambiguous "1 month"
/// can never appear.
String wallSupplementTimeLeft(AppLocalizations l, int days) =>
    days < 100 ? l.wallHeadDays(days) : l.wallHeadMonths((days / 30).round());

/// One head of the doser tile: the dosing icon tinted by how much supplement
/// is left, the supplement's label and the time the container lasts.
class WallDoseHeadData {
  const WallDoseHeadData({
    required this.label,
    this.timeLeft,
    this.tone = Zone.unknown,
  });

  /// The supplement's name as configured on the pump ("Balling light KH" —
  /// the same label the device card uses), or its abbreviation when no name
  /// is set.
  final String label;

  /// Localized "68 days" / "4 months"; null when the pump reports no stock
  /// estimate (rendered as a dash).
  final String? timeLeft;

  /// green/amber/red by stock level; [Zone.unknown] renders gray — a
  /// switched-off head.
  final Zone tone;
}

/// Everything the doser status tile needs to draw itself.
class WallDoseData {
  const WallDoseData({
    required this.title,
    required this.heads,
    this.tone = Zone.unknown,
  });

  /// The pump's display name.
  final String title;

  /// Configured heads in head order — sockets without a supplement are
  /// already skipped.
  final List<WallDoseHeadData> heads;

  /// The worst head's stock severity, tinting the card like every other wall
  /// tile; [Zone.unknown] renders neutral.
  final Zone tone;
}

/// The doser status tile (§12b): one entry per configured head — the dosing
/// icon in the head's stock color (gray when the head is off), the
/// supplement's name and how long its container lasts. Up to two entries per
/// row, so a 4-head pump forms a 2×2 grid.
class WallDoseTile extends StatelessWidget {
  const WallDoseTile({super.key, required this.data});

  final WallDoseData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final neutral = data.tone == Zone.unknown;
    final fill = neutral
        ? cs.surfaceContainerLow
        : data.tone.softColorOf(context);
    return Semantics(
      label:
          '${data.title}: '
          '${data.heads.map((h) => '${h.label} ${h.timeLeft ?? '—'}').join(', ')}',
      container: true,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < data.heads.length; i += 2)
                      Row(
                        children: [
                          Expanded(child: _HeadEntry(data: data.heads[i])),
                          const SizedBox(width: 8),
                          Expanded(
                            child: i + 1 < data.heads.length
                                ? _HeadEntry(data: data.heads[i + 1])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadEntry extends StatelessWidget {
  const _HeadEntry({required this.data});

  final WallDoseHeadData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gray = data.tone == Zone.unknown;
    final accent = gray ? cs.onSurfaceVariant : data.tone.colorOf(context);
    return Row(
      children: [
        Icon(Icons.science_outlined, size: 22, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: gray ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
              Text(
                data.timeLeft ?? '—',
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The card wash for a multi-fact status tile: the worst *alarm* tone among
/// [tones]. Only amber/red wash the card — green and unknown stay neutral, so
/// an all-healthy tile looks like the other device cards and color means
/// "look here".
Zone wallWorstAlarmTone(Iterable<Zone> tones) {
  var worst = Zone.unknown;
  for (final tone in tones) {
    if (tone == Zone.red || (tone == Zone.amber && worst != Zone.red)) {
      worst = tone;
    }
  }
  return worst;
}

/// Everything the ATO status tile needs to draw itself.
class WallAtoData {
  const WallAtoData({
    required this.title,
    required this.levelIcon,
    required this.levelText,
    this.levelTone = Zone.unknown,
    this.reservoirText,
    this.reservoirTone = Zone.unknown,
    this.tone = Zone.unknown,
  });

  /// The device's display name.
  final String title;

  /// The level row's icon — waves normally, the water-damage glyph when the
  /// leak sensor alarms.
  final IconData levelIcon;

  /// The level row's text: the water-level word ("OK"/"Low"/"High", or the
  /// raw firmware string), replaced by the leak warning when it alarms.
  final String levelText;

  /// green (level OK) / amber (low/high) / red (leak); [Zone.unknown]
  /// renders gray — an unrecognized firmware value.
  final Zone levelTone;

  /// Localized "12 days" / "4 months" via [wallSupplementTimeLeft]; null when
  /// the device reports no reservoir estimate (rendered as a dash).
  final String? reservoirText;

  /// green/amber/red by the shared stock severity; [Zone.unknown] renders
  /// gray — no estimate.
  final Zone reservoirTone;

  /// The card wash: the worst *alarm* of the two rows via
  /// [wallWorstAlarmTone] — neutral unless a row is amber or red.
  final Zone tone;
}

/// The ATO status tile (§12b): two rows of the same form — the water level
/// behind the sensor's icon, and the reservoir estimate behind a tank icon
/// with the days it lasts — each tinted by its own severity, the card washed
/// only by an amber/red row.
class WallAtoTile extends StatelessWidget {
  const WallAtoTile({super.key, required this.data});

  final WallAtoData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final neutral = data.tone == Zone.unknown;
    final fill = neutral
        ? cs.surfaceContainerLow
        : data.tone.softColorOf(context);
    return Semantics(
      label:
          '${data.title}: ${data.levelText}, '
          '${l.reefBeatAtoReservoir}: ${data.reservoirText ?? '—'}',
      container: true,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AtoRow(
                      icon: data.levelIcon,
                      text: data.levelText,
                      tone: data.levelTone,
                    ),
                    _AtoRow(
                      icon: Icons.propane_tank_outlined,
                      text: data.reservoirText ?? '—',
                      tone: data.reservoirTone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One fact row of the ATO tile, in the status tile's big-line form: the
/// 26 px icon and the 24 px text, both carrying the row's severity color.
class _AtoRow extends StatelessWidget {
  const _AtoRow({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final Zone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gray = tone == Zone.unknown;
    final accent = gray ? cs.onSurfaceVariant : tone.colorOf(context);
    return Row(
      children: [
        Icon(icon, size: 26, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: gray ? cs.onSurface : accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One status tile (§12b): the things devices report that aren't measurements
/// — skimmer cup, fleece roll. One line each, after the value cards.
class WallStatusData {
  const WallStatusData({
    required this.icon,
    required this.title,
    required this.line,
    this.extra,
    this.tone = Zone.unknown,
  });

  final IconData icon;

  /// The device's display name (or the feature's, for the RO tile).
  final String title;

  /// The headline ("Reservoir · 12 days left", "Full cup").
  final String line;

  /// Optional second line.
  final String? extra;

  /// [Zone.unknown] renders neutral; amber/red mark an alarm state.
  final Zone tone;
}

class WallStatusTile extends StatelessWidget {
  const WallStatusTile({super.key, required this.data});

  final WallStatusData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final neutral = data.tone == Zone.unknown;
    final fill = neutral
        ? cs.surfaceContainerLow
        : data.tone.softColorOf(context);
    final accent = neutral ? cs.onSurfaceVariant : data.tone.colorOf(context);
    return Semantics(
      label:
          '${data.title}: ${data.line}'
          '${data.extra == null ? '' : ', ${data.extra}'}',
      container: true,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(data.icon, size: 26, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.line,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: neutral ? cs.onSurface : accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (data.extra != null) ...[
                const SizedBox(height: 4),
                Text(
                  data.extra!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
