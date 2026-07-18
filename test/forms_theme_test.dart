import 'package:flutter/cupertino.dart' show CupertinoCheckbox;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/app/theme.dart';
import 'package:reeftracker/domain/zones.dart';
import 'package:reeftracker/l10n/app_localizations.dart';
import 'package:reeftracker/widgets/reef_sheet.dart';
import 'package:reeftracker/widgets/zone_bounds_editor.dart';

/// Forms & sheets foundation (REDESIGN #18): the theme-level input treatment,
/// the primary-button theme, the sheet-header primitive, and the adaptive
/// checkbox accent gotcha.
void main() {
  group('input decoration theme', () {
    test('outlined from tokens: r12, surfaceBorder rest, 2 px primary focus', () {
      final theme = buildReefTheme(Brightness.light, TargetPlatform.android);
      const t = ReefTokens.light;
      final deco = theme.inputDecorationTheme;
      expect(deco.filled, isTrue);
      expect(deco.fillColor, t.surface);
      final enabled = deco.enabledBorder! as OutlineInputBorder;
      expect(enabled.borderSide.color, t.surfaceBorder);
      expect(enabled.borderSide.width, 1);
      expect(
        enabled.borderRadius,
        const BorderRadius.all(Radius.circular(12)),
      );
      final focused = deco.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, t.primary);
      expect(focused.borderSide.width, 2);
      // Validation stays on the ColorScheme error slot (#1 rule), not on the
      // critical status token.
      final error = deco.errorBorder! as OutlineInputBorder;
      expect(error.borderSide.color, theme.colorScheme.error);
    });

    test('dark variant reads the dark tokens', () {
      final theme = buildReefTheme(Brightness.dark, TargetPlatform.android);
      const t = ReefTokens.dark;
      final deco = theme.inputDecorationTheme;
      expect(deco.fillColor, t.surface);
      expect(
        (deco.enabledBorder! as OutlineInputBorder).borderSide.color,
        t.surfaceBorder,
      );
      expect(
        (deco.focusedBorder! as OutlineInputBorder).borderSide.color,
        t.primary,
      );
    });

    testWidgets(
      'a field with no local border (ZoneBoundsEditor) renders outlined',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildReefTheme(Brightness.light, TargetPlatform.android),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ZoneBoundsEditor(
                  initial: const ZoneBounds(
                    amberLow: 7,
                    greenLow: 8,
                    greenHigh: 9,
                    amberHigh: 10,
                  ),
                  format: (v) => v.toStringAsFixed(1),
                ),
              ),
            ),
          ),
        );
        // The pre-redesign underline came from the default theme; the fields
        // set no local border, so the #18 theme must reach them.
        final decorator = tester.widget<InputDecorator>(
          find.byType(InputDecorator).first,
        );
        expect(decorator.decoration.enabledBorder, isA<OutlineInputBorder>());
        expect(
          (decorator.decoration.enabledBorder! as OutlineInputBorder)
              .borderSide
              .color,
          ReefTokens.light.surfaceBorder,
        );
      },
    );
  });

  group('primary button theme', () {
    test('w700 label at the platform primary-action shape', () {
      final android = buildReefTheme(Brightness.light, TargetPlatform.android);
      final ios = buildReefTheme(Brightness.light, TargetPlatform.iOS);
      final style = android.filledButtonTheme.style!;
      expect(style.textStyle!.resolve(const {})!.fontWeight, FontWeight.w700);
      expect(
        style.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
      expect(
        ios.filledButtonTheme.style!.shape!.resolve(const {}),
        const StadiumBorder(),
      );
      // Colors deliberately unset: they come from the token-built ColorScheme
      // and overriding them would lose the M3 disabled states.
      expect(style.backgroundColor, isNull);
      expect(style.foregroundColor, isNull);
    });
  });

  group('ReefSheetHeader', () {
    testWidgets('renders the 17/w700 title with leading and trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildReefTheme(Brightness.light, TargetPlatform.android),
          home: const Scaffold(
            body: ReefSheetHeader(
              'Edit set',
              leading: Icon(Icons.auto_awesome_outlined),
              trailing: Icon(Icons.close),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Edit set'));
      expect(text.style!.fontSize, 17);
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.style!.color, ReefTokens.light.text);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('adaptive checkboxes', () {
    testWidgets(
      'Cupertino dialect needs the widget-level token accent '
      '(no CheckboxThemeData adaptation exists)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildReefTheme(Brightness.light, TargetPlatform.iOS),
            home: Scaffold(
              body: CheckboxListTile.adaptive(
                value: true,
                onChanged: (_) {},
                title: const Text('Alkalinity'),
                activeColor: ReefTokens.light.primary,
                checkColor: ReefTokens.light.onPrimary,
              ),
            ),
          ),
        );
        // On iOS the adaptive constructor renders a CupertinoCheckbox, which
        // ignores Material theming — without the explicit accent it would be
        // iOS system blue. The call sites (test-set / micro-view sheets) pass
        // the tokens exactly like this.
        final cupertino = tester.widget<CupertinoCheckbox>(
          find.byType(CupertinoCheckbox),
        );
        expect(cupertino.activeColor, ReefTokens.light.primary);
        expect(cupertino.checkColor, ReefTokens.light.onPrimary);
      },
    );
  });
}
