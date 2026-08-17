/// Shared dosing mutations used by more than one presentation surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/database.dart';
import '../../l10n/app_localizations.dart';

Future<bool> stopDosingWithUndo(
  BuildContext context,
  WidgetRef ref,
  DosingEntry entry,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);
  await db.stopDosingEntry(entry.id);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l.supplementStopped),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => db.restoreDosingEntry(entry),
        ),
      ),
    );
  return true;
}
