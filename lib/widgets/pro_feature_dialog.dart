import 'package:flutter/material.dart';

import '../domain/pro_features.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';

/// Explains that [feature] belongs to the Pro tier (U19). This is the shared
/// stand-in for every gated action while no purchase mechanism exists; when
/// the paid tier ships it becomes the paywall entry point. Unreachable in
/// practice until then: every current install is Founder's Edition and
/// founders pass the gate for all grandfathered features.
/// [body] replaces the generic "… is part of ReefTracker Pro." line when the
/// gate needs more context (e.g. the tank cap explains the limit).
Future<void> showProFeatureDialog(
  BuildContext context,
  ProFeature feature, {
  String? body,
}) {
  final l = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.workspace_premium_outlined),
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
}
