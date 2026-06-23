/// The kind of reef setup a tank is. Used to seed sensible default zone
/// boundaries for each tracked parameter (see `presets.dart`).
enum SetupType {
  fishOnly('Fish-only / FOWLR'),
  soft('Soft coral'),
  lps('LPS'),
  sps('SPS'),
  mixed('Mixed reef');

  const SetupType(this.label);

  /// Human-readable name shown in the UI.
  final String label;

  /// Parses the value stored in the database back into an enum, defaulting to
  /// [SetupType.mixed] for unknown/legacy values.
  static SetupType fromName(String name) =>
      SetupType.values.firstWhere((e) => e.name == name,
          orElse: () => SetupType.mixed);
}
