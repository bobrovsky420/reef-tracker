import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/settings.dart';
import '../../l10n/app_localizations.dart';

/// Settings → Reminders (U1/U2/U12), route `/settings/reminders`: the three
/// category master switches (all opt-in), the delivery time for
/// testing/maintenance reminders, and a persistent warning row when the
/// system notification permission is denied.
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
    final settings = ref.read(settingsProvider);
    final testing = ref.watch(remindersTestingProvider).value ?? false;
    final dosing = ref.watch(remindersDosingProvider).value ?? false;
    final maintenance = ref.watch(remindersMaintenanceProvider).value ?? false;
    final time = ref.watch(reminderTimeProvider).value ?? kDefaultReminderTime;
    final anyOn = testing || dosing || maintenance;

    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ListView(
        children: [
          if (anyOn && !_permitted)
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l.remindersPermissionDenied,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SwitchListTile.adaptive(
            title: Text(l.notifChannelTesting),
            subtitle: Text(l.remindersTestingSubtitle),
            value: testing,
            onChanged: (v) => _setCategory(settings.setRemindersTesting, v),
          ),
          SwitchListTile.adaptive(
            title: Text(l.notifChannelDosing),
            subtitle: Text(l.remindersDosingSubtitle),
            value: dosing,
            onChanged: (v) => _setCategory(settings.setRemindersDosing, v),
          ),
          SwitchListTile.adaptive(
            title: Text(l.notifChannelMaintenance),
            subtitle: Text(l.remindersMaintenanceSubtitle),
            value: maintenance,
            onChanged: (v) => _setCategory(settings.setRemindersMaintenance, v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l.reminderTimeTitle),
            subtitle: Text(l.reminderTimeSubtitle),
            trailing: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay(hour: time.hour, minute: time.minute),
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: _pickTime,
          ),
        ],
      ),
    );
  }
}
