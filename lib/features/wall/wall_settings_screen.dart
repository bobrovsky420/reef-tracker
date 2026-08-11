import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../domain/device_vendors.dart';
import '../../domain/pro_features.dart';
import '../../domain/wall_display.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../widgets/pro_feature_dialog.dart';
import '../../widgets/reef_settings.dart';

/// Settings → Wall display (U49 §12f/§12q): the mode's options, its "Start
/// now" entry point, and the wall-card list — a reorderable list with a
/// visibility toggle per row, following the Manage-parameters conventions
/// (#48 drag handles). Deliberately **not** an edit mode on the wall itself:
/// a long-press there is the exit gesture, and dragging tiles on a
/// wall-mounted panel is the wrong ergonomics.
class WallSettingsScreen extends ConsumerWidget {
  const WallSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsProvider);
    final entitled = ref.watch(proFeatureProvider(ProFeature.wallDisplay));
    final autoStart = ref.watch(wallAutoStartProvider).value ?? false;
    final interval =
        ref.watch(wallRefreshIntervalProvider).value ??
        const Duration(seconds: kWallDefaultRefreshSeconds);
    final pageSeconds =
        ref.watch(wallPageSecondsProvider).value ?? kWallDefaultPageSeconds;
    final nightEnabled = ref.watch(wallNightEnabledProvider).value ?? true;
    final nightFrom =
        ref.watch(wallNightFromProvider).value ?? kWallDefaultNightFromMinutes;
    final nightTo =
        ref.watch(wallNightToProvider).value ?? kWallDefaultNightToMinutes;

    String intervalLabel(int seconds) => seconds < 60
        ? l.wallSecondsLabel(seconds)
        : l.wallMinutesLabel(seconds ~/ 60);

    return Scaffold(
      appBar: AppBar(title: Text(l.wallDisplayTitle)),
      body: ReefSettingsList(
        sections: [
          ReefSettingsSection(
            children: [
              ReefSettingsRow(
                icon: Icons.play_circle_outline,
                title: l.wallStartNow,
                description: l.wallStartNowSubtitle,
                trailing: const ReefSettingsValue(),
                onTap: () => unawaited(
                  runProGated(
                    context,
                    ref,
                    ProFeature.wallDisplay,
                    () => context.push('/wall'),
                  ),
                ),
              ),
              ReefSettingsRow(
                icon: Icons.restart_alt,
                title: l.wallAutoStartTitle,
                description: l.wallAutoStartSubtitle,
                trailing: Switch.adaptive(
                  value: autoStart && entitled,
                  onChanged: (v) => unawaited(_setAutoStart(context, ref, v)),
                ),
                onTap: () => unawaited(_setAutoStart(context, ref, !autoStart)),
              ),
            ],
          ),
          ReefSettingsSection(
            label: l.wallBehaviourSection,
            children: [
              ReefSettingsRow(
                icon: Icons.update,
                title: l.wallRefreshIntervalTitle,
                description: l.wallRefreshIntervalSubtitle,
                trailing: ReefSettingsDropdown<int>(
                  value: interval.inSeconds,
                  onChanged: (v) => unawaited(
                    settings.setWallRefreshInterval(Duration(seconds: v)),
                  ),
                  items: [
                    for (final s in kWallRefreshChoicesSeconds)
                      (s, intervalLabel(s)),
                  ],
                ),
              ),
              ReefSettingsRow(
                icon: Icons.auto_mode,
                title: l.wallPageSecondsTitle,
                description: l.wallPageSecondsSubtitle,
                trailing: ReefSettingsDropdown<int>(
                  value: pageSeconds,
                  onChanged: (v) => unawaited(settings.setWallPageSeconds(v)),
                  items: [
                    for (final s in kWallPageSecondsChoices)
                      (s, l.wallSecondsLabel(s)),
                  ],
                ),
              ),
              ReefSettingsRow(
                icon: Icons.nightlight_outlined,
                title: l.wallNightTitle,
                description: l.wallNightSubtitle,
                trailing: Switch.adaptive(
                  value: nightEnabled,
                  onChanged: (v) => unawaited(settings.setWallNightEnabled(v)),
                ),
                onTap: () =>
                    unawaited(settings.setWallNightEnabled(!nightEnabled)),
              ),
              if (nightEnabled) ...[
                ReefSettingsRow(
                  icon: Icons.bedtime_outlined,
                  title: l.wallNightFromTitle,
                  trailing: ReefSettingsValue(
                    value: _timeLabel(context, nightFrom),
                    mono: true,
                  ),
                  onTap: () => unawaited(
                    _pickTime(context, nightFrom, settings.setWallNightFrom),
                  ),
                ),
                ReefSettingsRow(
                  icon: Icons.wb_twilight,
                  title: l.wallNightToTitle,
                  trailing: ReefSettingsValue(
                    value: _timeLabel(context, nightTo),
                    mono: true,
                  ),
                  onTap: () => unawaited(
                    _pickTime(context, nightTo, settings.setWallNightTo),
                  ),
                ),
              ],
            ],
          ),
          ReefSettingsSection(
            label: l.wallCardsSection,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  l.wallCardsHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const _WallCardList(),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setAutoStart(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final settings = ref.read(settingsProvider);
    if (!enabled) {
      await settings.setWallAutoStart(false);
      return;
    }
    // Enabling is the Pro action (§12h): a Standard install can look at the
    // options but not arm the kiosk boot.
    if (!ref.read(proFeatureProvider(ProFeature.wallDisplay))) {
      await showProFeatureDialog(context, ProFeature.wallDisplay);
      if (!ref.read(proFeatureProvider(ProFeature.wallDisplay))) return;
    }
    await settings.setWallAutoStart(true);
  }

  String _timeLabel(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  Future<void> _pickTime(
    BuildContext context,
    int minutes,
    Future<void> Function(int) write,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) {
      await write(picked.hour * 60 + picked.minute);
    }
  }
}

/// The reorderable wall-card list: what is known to the wall — remembered
/// device cards (sparse `wall_tile_settings` rows) plus the tracked
/// parameters' stored-readings cards — in the wall's own order.
class _WallCardList extends ConsumerWidget {
  const _WallCardList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tank = ref.watch(activeTankProvider);
    if (tank == null) return const SizedBox.shrink();
    final tracked = ref.watch(trackedParametersProvider).value ?? const [];
    final rows = [
      for (final r
          in ref.watch(wallTileSettingsProvider).value ??
              const <WallTileSetting>[])
        WallTileConfig(
          deviceIdentifier: r.deviceIdentifier,
          paramKey: r.paramKey,
          displayOrder: r.displayOrder,
          visible: r.visible,
        ),
    ];

    // Device names + page order, from the registered inventory. No live
    // reads here: what a device reports is remembered in the rows the wall
    // wrote (`insertMissingWallTiles`) — a device never polled yet simply has
    // no cards to arrange until the wall has seen it once.
    final order = ref.watch(deviceVendorOrderProvider).value ?? kDeviceVendors;
    final byKind = {
      kDeviceKindReefFactory:
          ref.watch(reefFactoryDevicesProvider).value ?? const <DeviceRecord>[],
      kDeviceKindReefBeat:
          ref.watch(reefBeatDevicesProvider).value ?? const <DeviceRecord>[],
      kDeviceKindApex:
          ref.watch(apexDevicesProvider).value ?? const <DeviceRecord>[],
    };
    final deviceNames = <String, String>{};
    final reported = <String, List<String>>{};
    for (final kind in order) {
      if (!deviceKindRefreshes(kind)) continue;
      final devices =
          [
            for (final d in byKind[kind] ?? const <DeviceRecord>[])
              if (d.tankId == tank.id) d,
          ]..sort((a, b) {
            final byOrder = a.displayOrder.compareTo(b.displayOrder);
            if (byOrder != 0) return byOrder;
            return deviceDisplayName(
              a,
            ).toLowerCase().compareTo(deviceDisplayName(b).toLowerCase());
          });
      for (final d in devices) {
        deviceNames[d.identifier] = deviceDisplayName(d);
        reported[d.identifier] = [
          for (final r in rows)
            if (r.deviceIdentifier == d.identifier) r.paramKey,
        ];
      }
    }

    final cards = buildWallCards(
      trackedKeys: [
        for (final p in tracked)
          if (p.enabled) p.paramKey,
      ],
      reportedByDevice: reported,
      rows: rows,
    );
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l.noReadings, style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final visibleCountByDevice = <String, int>{};
    for (final c in cards) {
      if (c.id.deviceIdentifier == kWallNoDevice || !c.visible) continue;
      visibleCountByDevice.update(
        c.id.deviceIdentifier,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }

    final db = ref.read(dbProvider);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: cards.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final c in cards) c.id];
        ids.insert(newIndex, ids.removeAt(oldIndex));
        unawaited(
          db.setWallTileOrder(tank.id, [
            for (final id in ids)
              (deviceIdentifier: id.deviceIdentifier, paramKey: id.paramKey),
          ]),
        );
      },
      itemBuilder: (context, i) {
        final card = cards[i];
        final id = card.id;
        final deviceCard = id.deviceIdentifier != kWallNoDevice;
        final deviceName = deviceCard
            ? (deviceNames[id.deviceIdentifier] ?? id.deviceIdentifier)
            : l.wallStoredCard;
        final muted =
            deviceCard && isWallDeviceMuted(id.deviceIdentifier, rows);
        // The row whose toggle would silence the device says so before it is
        // flipped — the traffic consequence must not be folklore (§12q).
        final lastVisible =
            deviceCard &&
            card.visible &&
            visibleCountByDevice[id.deviceIdentifier] == 1;
        final subtitle = [
          deviceName,
          if (muted) l.wallDeviceNotContacted,
          if (lastVisible) l.wallHideLastCardNote,
        ].join(' · ');
        return ListTile(
          key: ValueKey('${id.deviceIdentifier}|${id.paramKey}'),
          leading: Semantics(
            label: '${l.paramName(id.paramKey)} · $deviceName',
            child: Switch.adaptive(
              value: card.visible,
              onChanged: (v) => unawaited(
                db.setWallTileVisible(
                  tankId: tank.id,
                  deviceIdentifier: id.deviceIdentifier,
                  paramKey: id.paramKey,
                  visible: v,
                ),
              ),
            ),
          ),
          title: Text(l.paramName(id.paramKey)),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ReorderableDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.drag_handle,
                size: 16,
                color: ReefTokens.of(context).textFaint,
                semanticLabel: l.reorder,
              ),
            ),
          ),
        );
      },
    );
  }
}
