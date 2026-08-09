import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/reef_background.dart';

/// The app's [MaterialApp.builder] — everything that must wrap *every* route,
/// below the localization delegates and above the Navigator.
///
/// Two jobs, both of which have to happen once for the whole app rather than
/// per screen:
///
/// * Keeps `intl` in sync with the resolved app locale. Assigning
///   [Intl.defaultLocale] here is the single line that makes every
///   `DateFormat(...)` and every `formatLocaleNumber(...)` in the app follow the
///   selected language — a dosing amount renders `8,25` in cs/de/fr and `8.25`
///   in en. It runs while [MaterialApp] builds, i.e. strictly before any route
///   (or a screen's `initState`, which is where several screens seed their
///   number fields) is built, so the first frame of a screen is already
///   formatted in the right locale.
/// * Puts the [ReefBackground] gradient behind the Navigator, so every screen
///   (scaffolds are transparent) shares one background.
///
/// Named and lifted out of `main.dart` so a test can pump the real app and
/// assert the locale wiring end to end, instead of re-implementing it in a
/// harness that would only prove itself right.
Widget reefAppBuilder(BuildContext context, Widget? child) {
  Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
  return ReefBackground(child: child ?? const SizedBox.shrink());
}
