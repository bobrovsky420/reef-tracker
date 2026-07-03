/// The kind of reef setup a tank is. Used to seed sensible default zone
/// boundaries for each tracked parameter (see `presets.dart`).
///
/// Display names are localized (`l.setupLabel`), not stored here — do not add
/// an English label field back (#54).
enum SetupType {
  fishOnly,
  soft,
  lps,
  sps,
  mixed;

  /// Parses the value stored in the database back into an enum, defaulting to
  /// [SetupType.mixed] for unknown/legacy values.
  static SetupType fromName(String name) => SetupType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => SetupType.mixed,
  );
}
