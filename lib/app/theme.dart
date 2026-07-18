import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The ReefTracker design language (REDESIGN §2): a fixed token palette per
/// brightness, exposed as a [ThemeExtension] so widgets read colors via
/// `ReefTokens.of(context)` — no hardcoded colors in feature code.
///
/// Zone→color mapping lives in `widgets/zone_visuals.dart` (this file stays
/// domain-free); the tokens here are the single source for both that mapping
/// and the Material [ColorScheme] built in [buildReefTheme].
@immutable
class ReefTokens extends ThemeExtension<ReefTokens> {
  const ReefTokens({
    required this.scaffoldTop,
    required this.scaffoldBody,
    required this.surface,
    required this.surfaceBorder,
    required this.primary,
    required this.onPrimary,
    required this.healthy,
    required this.caution,
    required this.critical,
    required this.healthySoft,
    required this.cautionSoft,
    required this.criticalSoft,
    required this.cautionBorder,
    required this.criticalBorder,
    required this.band,
    required this.track,
    required this.tick,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.cardShadow,
    required this.markerRing,
    required this.tabBarBg,
  });

  /// Vertical scaffold gradient endpoints (top → body, stop at 14%).
  final Color scaffoldTop;
  final Color scaffoldBody;

  /// Card background and its 1 px border.
  final Color surface;
  final Color surfaceBorder;

  /// "Actinic" accent: FAB, active tab, links, segmented-control accents.
  final Color primary;
  final Color onPrimary;

  /// Status colors (Zone.green / amber / red map onto these).
  final Color healthy;
  final Color caution;
  final Color critical;

  /// Soft fills for the status colors: tag/chip backgrounds, band fills.
  final Color healthySoft;
  final Color cautionSoft;
  final Color criticalSoft;

  /// Borders of the amber/critical equipment-alert card (REDESIGN #11). The
  /// caution variant isn't in the §2.1 mock table (the mock only shows a
  /// critical alert) — same alpha recipe over the caution color.
  final Color cautionBorder;
  final Color criticalBorder;

  /// Ideal-range band on gauges/ratio tracks.
  final Color band;

  /// Background track of gauges/bars/rings.
  final Color track;

  /// Gauge tick marks.
  final Color tick;

  /// Primary / secondary / tertiary text.
  final Color text;
  final Color textDim;
  final Color textFaint;

  /// Card elevation (empty in dark — the border carries structure).
  final List<BoxShadow> cardShadow;

  /// Ring around gauge/ratio marker dots.
  final Color markerRing;

  /// Translucent bottom tab-bar background (blurred behind).
  final Color tabBarBg;

  /// The bundled monospace family for numeric values (gauge values, deltas,
  /// scores, dose amounts). Weights 400/500/700 are available.
  static const String monoFamily = 'JetBrainsMono';

  /// Base style for numeric values; `copyWith` size/weight/color at use sites.
  static const TextStyle monoTextStyle = TextStyle(fontFamily: monoFamily);

  /// Entry style for numeric form fields (REDESIGN #18): the mono family at
  /// the M3 default input size. Screens pass it as `TextField.style` on
  /// numeric fields (bounds, doses, volumes, reading values, calculator I/O)
  /// so typed numerals match the rendered ones app-wide.
  static const TextStyle monoInputStyle = TextStyle(
    fontFamily: monoFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// The scaffold background (REDESIGN §2.1): a vertical gradient fading
  /// `scaffoldTop` → `scaffoldBody` within the top 14%, flat below. Painted
  /// app-wide by `widgets/reef_background.dart` and behind each sliding route
  /// by the Cupertino-dialect page transition (see [buildReefTheme]).
  BoxDecoration get backgroundDecoration => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.14],
      colors: [scaffoldTop, scaffoldBody],
    ),
  );

  /// The active theme's tokens. Falls back to the brightness-matched default
  /// set when the theme wasn't built by [buildReefTheme] (bare-`MaterialApp`
  /// widget tests), so token reads never crash.
  static ReefTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ReefTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  static const ReefTokens light = ReefTokens(
    scaffoldTop: Color(0xFFFFFFFF),
    scaffoldBody: Color(0xFFF2FAFA),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x1A10262A), // 10% ink
    primary: Color(0xFF0A8599),
    onPrimary: Color(0xFFFFFFFF),
    healthy: Color(0xFF2FA968),
    caution: Color(0xFFC97F1E),
    critical: Color(0xFFE2593A),
    healthySoft: Color(0x292FA968), // 16%
    cautionSoft: Color(0x1FC97F1E), // 12%
    criticalSoft: Color(0x1AE2593A), // 10%
    cautionBorder: Color(0x47C97F1E), // 28%
    criticalBorder: Color(0x47E2593A), // 28%
    band: Color(0x332FA968), // 20%
    track: Color(0x1710262A), // 9% ink
    tick: Color(0x2E10262A), // 18% ink
    text: Color(0xFF10262A),
    textDim: Color(0x9410262A), // 58%
    textFaint: Color(0x5C10262A), // 36%
    cardShadow: [
      BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x1210262A)),
      BoxShadow(offset: Offset(0, 6), blurRadius: 16, color: Color(0x0D10262A)),
    ],
    markerRing: Color(0xFFFFFFFF),
    tabBarBg: Color(0xD9FFFFFF), // 85%
  );

  static const ReefTokens dark = ReefTokens(
    scaffoldTop: Color(0xFF0D2124),
    scaffoldBody: Color(0xFF0A1A1D),
    surface: Color(0x0BFFFFFF), // 4.5% white over the gradient
    surfaceBorder: Color(0x17FFFFFF), // 9%
    primary: Color(0xFF3FD1E0),
    onPrimary: Color(0xFF04262B),
    healthy: Color(0xFF7DE8A0),
    caution: Color(0xFFF5B95B),
    critical: Color(0xFFFF7A59),
    healthySoft: Color(0x297DE8A0), // 16%
    cautionSoft: Color(0x29F5B95B), // 16%
    criticalSoft: Color(0x24FF7A59), // 14%
    cautionBorder: Color(0x59F5B95B), // 35%
    criticalBorder: Color(0x59FF7A59), // 35%
    band: Color(0x617DE8A0), // 38%
    track: Color(0x14EAF6F3), // 8%
    tick: Color(0x2EEAF6F3), // 18%
    text: Color(0xFFEAF6F3),
    textDim: Color(0x8FEAF6F3), // 56%
    textFaint: Color(0x57EAF6F3), // 34%
    cardShadow: [],
    markerRing: Color(0xFF0A1A1D),
    tabBarBg: Color(0xB306100F), // 70%
  );

  @override
  ReefTokens copyWith({
    Color? scaffoldTop,
    Color? scaffoldBody,
    Color? surface,
    Color? surfaceBorder,
    Color? primary,
    Color? onPrimary,
    Color? healthy,
    Color? caution,
    Color? critical,
    Color? healthySoft,
    Color? cautionSoft,
    Color? criticalSoft,
    Color? cautionBorder,
    Color? criticalBorder,
    Color? band,
    Color? track,
    Color? tick,
    Color? text,
    Color? textDim,
    Color? textFaint,
    List<BoxShadow>? cardShadow,
    Color? markerRing,
    Color? tabBarBg,
  }) {
    return ReefTokens(
      scaffoldTop: scaffoldTop ?? this.scaffoldTop,
      scaffoldBody: scaffoldBody ?? this.scaffoldBody,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      healthy: healthy ?? this.healthy,
      caution: caution ?? this.caution,
      critical: critical ?? this.critical,
      healthySoft: healthySoft ?? this.healthySoft,
      cautionSoft: cautionSoft ?? this.cautionSoft,
      criticalSoft: criticalSoft ?? this.criticalSoft,
      cautionBorder: cautionBorder ?? this.cautionBorder,
      criticalBorder: criticalBorder ?? this.criticalBorder,
      band: band ?? this.band,
      track: track ?? this.track,
      tick: tick ?? this.tick,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      cardShadow: cardShadow ?? this.cardShadow,
      markerRing: markerRing ?? this.markerRing,
      tabBarBg: tabBarBg ?? this.tabBarBg,
    );
  }

  @override
  ReefTokens lerp(ReefTokens? other, double t) {
    if (other == null) return this;
    return ReefTokens(
      scaffoldTop: Color.lerp(scaffoldTop, other.scaffoldTop, t)!,
      scaffoldBody: Color.lerp(scaffoldBody, other.scaffoldBody, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      healthy: Color.lerp(healthy, other.healthy, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      healthySoft: Color.lerp(healthySoft, other.healthySoft, t)!,
      cautionSoft: Color.lerp(cautionSoft, other.cautionSoft, t)!,
      criticalSoft: Color.lerp(criticalSoft, other.criticalSoft, t)!,
      cautionBorder: Color.lerp(cautionBorder, other.cautionBorder, t)!,
      criticalBorder: Color.lerp(criticalBorder, other.criticalBorder, t)!,
      band: Color.lerp(band, other.band, t)!,
      track: Color.lerp(track, other.track, t)!,
      tick: Color.lerp(tick, other.tick, t)!,
      text: Color.lerp(text, other.text, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
      markerRing: Color.lerp(markerRing, other.markerRing, t)!,
      tabBarBg: Color.lerp(tabBarBg, other.tabBarBg, t)!,
    );
  }
}

/// Explicit [ColorScheme]s built from the token palette (REDESIGN #1: no
/// `fromSeed` — the old reef-blue seed is retired). Slots that Material
/// widgets consume are set deliberately:
///
/// - `primary` = actinic teal (series lines, FAB, switches, buttons).
/// - `secondary` = violet — the carbon-change chart marker (#47: markers must
///   stay distinct from the primary-colored series line on both brightnesses).
/// - `tertiary` = ocean blue — the water-change marker + noted-reading dots
///   ("annotation" family) and informational hints.
/// - `error` = darkened coral in light (destructive UI + validation text keeps
///   AA contrast); pure coral in dark. Status "critical" reads use the
///   [ReefTokens.critical] token, not `error`.
/// - `secondaryContainer` = soft actinic (M3 NavigationBar active pill).
const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0A8599),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFC8EDF2),
  onPrimaryContainer: Color(0xFF053A42),
  secondary: Color(0xFF7A5BC4),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFD2EEF2),
  onSecondaryContainer: Color(0xFF0A3A42),
  tertiary: Color(0xFF3E6FC4),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFDCE7FA),
  onTertiaryContainer: Color(0xFF1C3260),
  error: Color(0xFFC64B2E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFADCD4),
  onErrorContainer: Color(0xFF5C1A0B),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF10262A),
  onSurfaceVariant: Color(0x9410262A),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF7FBFB),
  surfaceContainer: Color(0xFFF2FAFA),
  surfaceContainerHigh: Color(0xFFECF5F5),
  surfaceContainerHighest: Color(0xFFE6F0F0),
  outline: Color(0xFF607D82),
  outlineVariant: Color(0xFFC3D6D8),
  inverseSurface: Color(0xFF2C3E41),
  onInverseSurface: Color(0xFFECF5F5),
  inversePrimary: Color(0xFF3FD1E0),
  surfaceTint: Colors.transparent,
);

const ColorScheme _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF3FD1E0),
  onPrimary: Color(0xFF04262B),
  primaryContainer: Color(0xFF0E4A54),
  onPrimaryContainer: Color(0xFFB8ECF2),
  secondary: Color(0xFFB9A3F0),
  onSecondary: Color(0xFF2A1A55),
  secondaryContainer: Color(0xFF123E44),
  onSecondaryContainer: Color(0xFFB8ECF2),
  tertiary: Color(0xFF8FB8F0),
  onTertiary: Color(0xFF102A55),
  tertiaryContainer: Color(0xFF2A3E66),
  onTertiaryContainer: Color(0xFFC8D8F8),
  error: Color(0xFFFF7A59),
  onError: Color(0xFF3A1105),
  errorContainer: Color(0xFF5C2415),
  onErrorContainer: Color(0xFFFFD9CE),
  surface: Color(0xFF0D2124),
  onSurface: Color(0xFFEAF6F3),
  onSurfaceVariant: Color(0x8FEAF6F3),
  surfaceContainerLowest: Color(0xFF071214),
  surfaceContainerLow: Color(0xFF102629),
  surfaceContainer: Color(0xFF132B2E),
  surfaceContainerHigh: Color(0xFF163135),
  surfaceContainerHighest: Color(0xFF1A373B),
  outline: Color(0xFF7C989C),
  outlineVariant: Color(0xFF294246),
  inverseSurface: Color(0xFFEAF6F3),
  onInverseSurface: Color(0xFF10262A),
  inversePrimary: Color(0xFF0A8599),
  surfaceTint: Colors.transparent,
);

/// Whether [platform] renders the Cupertino dialect (REDESIGN #15). The one
/// predicate every dialect fork keys on — iOS and macOS get the Cupertino
/// look, everything else the M3 look. Only theme/shared-widget code may call
/// this; feature code stays branch-free (CLAUDE.md rule).
bool reefCupertinoDialect(TargetPlatform platform) =>
    platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

/// Card corner radius per platform dialect (§2.3: r20 iOS, r16 Android).
/// Shared by [buildReefTheme]'s `CardThemeData` and the `ReefCard` widget so
/// both card paths agree on the shape.
double reefCardRadius(TargetPlatform platform) =>
    reefCupertinoDialect(platform) ? 20 : 16;

/// App-bar mini-card icon-button shape per platform dialect (§2.3: r9
/// squircle on iOS, circle on Android). Consumed by `ReefIconButton`.
OutlinedBorder reefIconButtonShape(TargetPlatform platform) =>
    reefCupertinoDialect(platform)
    ? RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(9))
    : const CircleBorder();

/// Primary-action shape per platform dialect (§2.3's FAB row: stadium pill on
/// iOS, r16 on Android). Shared by the FAB and `FilledButton` themes so every
/// primary button and FAB agree on the silhouette (REDESIGN #18).
OutlinedBorder reefPrimaryActionShape(TargetPlatform platform) =>
    reefCupertinoDialect(platform)
    ? const StadiumBorder()
    : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

/// The Cupertino-dialect route transition: the standard iOS slide with the
/// app background gradient painted behind each route. Scaffolds are
/// transparent over the shared `ReefBackground` (REDESIGN #2), but the
/// Cupertino slide keeps both routes fully opaque and overlapping — without
/// a backdrop the outgoing page's content would show through the incoming
/// one. Painting the same gradient inside every route keeps the steady-state
/// look identical while pages slide as opaque cards, iOS-style.
class _ReefCupertinoTransitionsBuilder extends CupertinoPageTransitionsBuilder {
  const _ReefCupertinoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return super.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      DecoratedBox(
        decoration: ReefTokens.of(context).backgroundDecoration,
        child: child,
      ),
    );
  }
}

/// Cupertino-dialect styling for `Switch.adaptive` (§A.7: on-track =
/// `healthy`, like the mock's iOS switch). Registered in
/// [ThemeData.adaptations]; the framework consults it only for `.adaptive`
/// switches. Mirrors the default adaptation's platform split — on M3-dialect
/// platforms the ambient [SwitchThemeData] passes through untouched.
class _ReefSwitchAdaptation extends Adaptation<SwitchThemeData> {
  const _ReefSwitchAdaptation(this.tokens);

  final ReefTokens tokens;

  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) {
    if (!reefCupertinoDialect(theme.platform)) return defaultValue;
    return SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? tokens.healthy : null,
      ),
    );
  }
}

/// Builds the app [ThemeData] for a brightness × platform pair. Platform
/// dialects (radii, chrome shapes — REDESIGN #15) resolve here and only here;
/// feature code never branches on the platform (CLAUDE.md rule).
ThemeData buildReefTheme(Brightness brightness, TargetPlatform platform) {
  final dark = brightness == Brightness.dark;
  final tokens = dark ? ReefTokens.dark : ReefTokens.light;
  final scheme = dark ? _darkScheme : _lightScheme;
  OutlineInputBorder inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: color, width: width),
      );
  return ThemeData(
    colorScheme: scheme,
    platform: platform,
    // Card language (REDESIGN #2): flat `surface` + 1 px `surfaceBorder` at
    // the platform radius. This restyles every plain `Card`; the exact
    // two-layer light shadow needs a multi-shadow decoration `Card` can't
    // paint, so the shared `ReefCard` widget carries it and the main cards
    // adopt it incrementally.
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(reefCardRadius(platform)),
        side: BorderSide(color: tokens.surfaceBorder),
      ),
    ),
    // Screens are transparent over the shared `ReefBackground` gradient
    // mounted in MaterialApp's `builder` (scaffoldTop→scaffoldBody, 14% stop).
    scaffoldBackgroundColor: Colors.transparent,
    // Route transitions must not repaint that background: the M3 Android
    // transition (predictive-back, falling back to FadeForwards for normal
    // pushes) paints a `surface`-colored scrim behind the cross-fading
    // routes, which flashed white over the transparent scaffolds on every
    // push/pop. A transparent scrim lets the static gradient show through
    // the whole transition. The Cupertino slide instead needs each route
    // opaque (no cross-fade — overlapping transparent pages would show
    // through each other), so its builder wraps every route in the gradient.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
          fallbackColor: Colors.transparent,
        ),
        TargetPlatform.iOS: _ReefCupertinoTransitionsBuilder(),
        TargetPlatform.macOS: _ReefCupertinoTransitionsBuilder(),
      },
    ),
    // The app bar is transparent too, so the gradient's top glow shows behind
    // the status-bar/app-bar area. Zero scrolled-under elevation: the M3
    // default would flash `surface`→`surfaceContainer` when content scrolls
    // under. With no background to derive it from, the status-bar icon
    // brightness must be set explicitly.
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    // Bottom tab bar per the mockup (§A.6): translucent `tabBarBg` (the
    // hairline top border and the backdrop blur live in HomeShell —
    // NavigationBar has no slots for either), 21 px icons + 10 px w600
    // labels, active = actinic. Dialects: the Android active tab gets the
    // `healthySoft` pill (M3's indicator), iOS is indicator-less.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.tabBarBg,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: switch (platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => Colors.transparent,
        _ => tokens.healthySoft,
      },
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 21,
          color: states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textFaint,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textFaint,
        ),
      ),
    ),
    // FABs (§A.6): actinic pill — stadium on iOS, r16 on Android (all FABs
    // app-wide, extended or not). M3's default would use primaryContainer.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.primary,
      foregroundColor: tokens.onPrimary,
      shape: reefPrimaryActionShape(platform),
      extendedTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 48),
    ),
    // Forms (REDESIGN #18): the one input treatment for every text field and
    // dropdown app-wide — M3 outlined, restyled from the tokens (r12,
    // `surfaceBorder` at rest, 2 px `primary` focused, `surface` fill).
    // Fields that never set a local `border:` (tank editor, ZoneBoundsEditor)
    // pick this up too — the pre-redesign underline is retired. `error` stays
    // the validation color per the #1 slot rules.
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: tokens.surface,
      border: inputBorder(tokens.surfaceBorder, 1),
      enabledBorder: inputBorder(tokens.surfaceBorder, 1),
      focusedBorder: inputBorder(tokens.primary, 2),
      errorBorder: inputBorder(scheme.error, 1),
      focusedErrorBorder: inputBorder(scheme.error, 2),
      disabledBorder: inputBorder(tokens.track, 1),
      labelStyle: TextStyle(color: tokens.textDim),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? tokens.primary
              : tokens.textDim,
        ),
      ),
      hintStyle: TextStyle(color: tokens.textFaint),
      helperStyle: TextStyle(color: tokens.textFaint),
      prefixStyle: TextStyle(color: tokens.textFaint),
      suffixStyle: TextStyle(color: tokens.textFaint),
    ),
    // Primary buttons (REDESIGN #18): every `FilledButton` — editor saves,
    // dialog confirms — carries the FAB's w700 label and platform silhouette.
    // Colors are deliberately not set here: they already come from the
    // token-built ColorScheme, and overriding them in `styleFrom` would lose
    // the M3 disabled states (the in-button `_saving` spinner convention
    // relies on them).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: reefPrimaryActionShape(platform),
      ),
    ),
    // Switches (REDESIGN #15): call sites use the `.adaptive` constructors.
    // The M3 dialect keeps the default primary track and gains the mock's
    // check-marked thumb; the Cupertino dialect renders the iOS-shaped switch
    // with the `healthy` track via the adaptation below (adaptive switches on
    // iOS deliberately ignore the ambient [SwitchThemeData]).
    switchTheme: reefCupertinoDialect(platform)
        ? null
        : SwitchThemeData(
            thumbIcon: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Icon(Icons.check)
                  : null,
            ),
          ),
    adaptations: [_ReefSwitchAdaptation(tokens)],
    extensions: [tokens],
  );
}
