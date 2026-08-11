import 'package:flutter/material.dart';

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
}

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
                '${data.pres.unitLabel}, $zoneLabel',
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
              Text(
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
                  Icon(zone.icon, size: 14, color: valueColor),
                  const SizedBox(width: 5),
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

/// One status tile (§12b): the things devices report that aren't measurements
/// — reservoir level, skimmer cup, doses today, RO stage due. One line each,
/// after the value cards.
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
