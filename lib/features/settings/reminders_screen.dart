import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/reef_settings.dart';

/// Settings → Reminders (U1/U2/U12), route `/settings/reminders`: the three
/// category master switches (all opt-in), the delivery time for
/// testing/maintenance reminders, and a persistent warning row when the
/// system notification permission is denied.
///
/// Layout per REDESIGN #23: rebuilt on the `reef_settings.dart` primitives so
/// the screen speaks the Settings dialect on both platforms. The permission
/// warning renders in `caution` — a status, not a validation error, so not
/// `colorScheme.error` (the #1 slot rule).
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  /// Whether the OS currently permits our notifications. Re-checked after
  /// every toggle (the first enable triggers the permission request).
  bool _permitted = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPermission());
  }

  Future<void> _refreshPermission() async {
    final ok = await ref.read(reminderNotificationsProvider).areEnabled();
    if (mounted) setState(() => _permitted = ok);
  }

  /// Turning any category on is the moment to ask for the Android 13+
  /// runtime permission — never at app start.
  Future<void> _setCategory(
    Future<void> Function(bool) write,
    bool enabled,
  ) async {
    await write(enabled);
    if (enabled) {
      final granted = await ref
          .read(reminderNotificationsProvider)
          .requestPermission();
      if (mounted) setState(() => _permitted = granted);
    } else {
      await _refreshPermission();
    }
  }

  Future<void> _pickTime() async {
    final current =
        ref.read(reminderTimeProvider).value ?? kDefaultReminderTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked != null && mounted) {
      await ref
          .read(settingsProvider)
          .setReminderTime(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = ReefTokens.of(context);
    final settings = ref.read(settingsProvider);
    final testing = ref.watch(remindersTestingProvider).value ?? false;
    final dosing = ref.watch(remindersDosingProvider).value ?? false;
    final maintenance = ref.watch(remindersMaintenanceProvider).value ?? false;
    final time = ref.watch(reminderTimeProvider).value ?? kDefaultReminderTime;
    final anyOn = testing || dosing || maintenance;

    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ReefSettingsList(
        sections: [
          ReefSettingsSection(
            children: [
              if (anyOn && !_permitted)
                ReefSettingsRow(
                  icon: Icons.notifications_off_outlined,
                  iconColor: tokens.caution,
                  title: l.remindersPermissionDenied,
                  titleColor: tokens.caution,
                ),
              ReefSettingsRow(
                title: l.notifChannelTesting,
                description: l.remindersTestingSubtitle,
                trailing: Switch.adaptive(
                  value: testing,
                  onChanged: (v) =>
                      _setCategory(settings.setRemindersTesting, v),
                ),
                onTap: () =>
                    _setCategory(settings.setRemindersTesting, !testing),
              ),
              ReefSettingsRow(
                title: l.notifChannelDosing,
                description: l.remindersDosingSubtitle,
                trailing: Switch.adaptive(
                  value: dosing,
                  onChanged: (v) => _setCategory(settings.setRemindersDosing, v),
                ),
                onTap: () => _setCategory(settings.setRemindersDosing, !dosing),
              ),
              ReefSettingsRow(
                title: l.notifChannelMaintenance,
                description: l.remindersMaintenanceSubtitle,
                trailing: Switch.adaptive(
                  value: maintenance,
                  onChanged: (v) =>
                      _setCategory(settings.setRemindersMaintenance, v),
                ),
                onTap: () => _setCategory(
                  settings.setRemindersMaintenance,
                  !maintenance,
                ),
              ),
            ],
          ),
          ReefSettingsSection(
            children: [
              ReefSettingsRow(
                icon: Icons.schedule,
                title: l.reminderTimeTitle,
                description: l.reminderTimeSubtitle,
                trailing: ReefSettingsValue(
                  mono: true,
                  value: MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay(hour: time.hour, minute: time.minute),
                    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                      context,
                    ),
                  ),
                ),
                onTap: _pickTime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
