import 'package:flutter_test/flutter_test.dart';
import 'package:reeftracker/domain/dashboard_sections.dart';
import 'package:reeftracker/domain/parameter_catalog.dart';
import 'package:reeftracker/domain/ratio.dart';

void main() {
  group('sectionOfParam (REDESIGN #6)', () {
    test('maps each core group to its fixed section', () {
      expect(sectionOfParam('alkalinity'), DashboardSection.coreChemistry);
      expect(sectionOfParam('calcium'), DashboardSection.coreChemistry);
      expect(sectionOfParam('magnesium'), DashboardSection.coreChemistry);
      expect(sectionOfParam('nitrate'), DashboardSection.nutrients);
      expect(sectionOfParam('phosphate'), DashboardSection.nutrients);
      expect(sectionOfParam('ammonia'), DashboardSection.nutrients);
      expect(sectionOfParam('nitrite'), DashboardSection.nutrients);
      expect(sectionOfParam('temperature'), DashboardSection.environment);
      expect(sectionOfParam('ph'), DashboardSection.environment);
      expect(sectionOfParam('salinity'), DashboardSection.environment);
      expect(sectionOfParam('orp'), DashboardSection.environment);
    });

    test('an unknown legacy key falls into the headerless other bucket', () {
      expect(sectionOfParam('some-hand-edited-key'), DashboardSection.other);
    });

    test('microelement keys are not core and are never queried for a '
        'section by the dashboard, but resolve to other if they were', () {
      // Microelements never reach sectionOfParam via the dashboard build
      // (isCoreParam filters them out first) — this just documents that a
      // stray call degrades safely instead of throwing.
      expect(sectionOfParam('zinc'), DashboardSection.other);
    });
  });

  group('DashboardSortKey ordering', () {
    test('section rank dominates the within-section displayOrder', () {
      // A nutrients item with displayOrder 0 still sorts after a
      // coreChemistry item with displayOrder 99 — sections are fixed, not
      // user-reorderable across the boundary.
      final nutrient = paramSortKey('nitrate', 0);
      final core = paramSortKey('alkalinity', 99);
      expect(core.compareTo(nutrient), lessThan(0));
    });

    test('within a section, displayOrder decides', () {
      final first = paramSortKey('alkalinity', 0);
      final second = paramSortKey('calcium', 1);
      expect(first.compareTo(second), lessThan(0));
    });

    test('ratios occupy their own fixed section between nutrients and '
        'environment', () {
      final nutrient = paramSortKey('nitrate', 1000);
      final ratio = ratioSortKey(RatioKind.po4no3, null);
      final env = paramSortKey('temperature', 0);
      expect(nutrient.compareTo(ratio), lessThan(0));
      expect(ratio.compareTo(env), lessThan(0));
    });

    test(
      'ties break on the stable catalog/RatioKind index, not arbitrarily',
      () {
        // Fresh-install collision: a ratio's default order (1000+kind.index)
        // can numerically equal a parameter's stored displayOrder.
        final param = paramSortKey('nitrate', 1000);
        final ratio = ratioSortKey(RatioKind.po4no3, null);
        // Different sections, so the tie never actually compares tiebreaks —
        // this documents that both still produce a total, deterministic order.
        expect(param.compareTo(ratio), isNot(0));

        final a = paramSortKey('nitrate', 5);
        final b = paramSortKey('phosphate', 5);
        // Same section, same displayOrder: catalog index breaks the tie
        // deterministically (nitrate precedes phosphate in parameters.yaml).
        expect(a.compareTo(b), lessThan(0));
      },
    );

    test('sorting a full param+ratio list groups strictly by section', () {
      // Both ratios have no stored settings, so they fall back to
      // kind.defaultOrder (1000 + kind.index): po4no3 (index 0) = 1000,
      // mgca (index 1) = 1001 — po4no3 sorts first.
      final keys = <(String label, DashboardSortKey key)>[
        ('phosphate', paramSortKey('phosphate', 3)),
        ('temperature', paramSortKey('temperature', 0)),
        ('mgca', ratioSortKey(RatioKind.mgca, null)),
        ('alkalinity', paramSortKey('alkalinity', 5)),
        ('nitrate', paramSortKey('nitrate', 1)),
        ('po4no3', ratioSortKey(RatioKind.po4no3, null)),
        ('ph', paramSortKey('ph', 1)),
        ('calcium', paramSortKey('calcium', 0)),
      ]..sort((a, b) => a.$2.compareTo(b.$2));

      expect(keys.map((e) => e.$1).toList(), [
        'calcium', // coreChemistry (order 0)
        'alkalinity', // coreChemistry (order 5)
        'nitrate', // nutrients (order 1)
        'phosphate', // nutrients (order 3)
        'po4no3', // ratios (defaultOrder 1000)
        'mgca', // ratios (defaultOrder 1001)
        'temperature', // environment (order 0)
        'ph', // environment (order 1)
      ]);
    });
  });

  group('parameters.yaml integration', () {
    test('every core catalog parameter has a dashboardGroup', () {
      for (final p in kReefParameters.where((p) => !p.isMicro)) {
        expect(
          p.dashboardGroup,
          isNotNull,
          reason: '${p.key} is core but carries no dashboardGroup',
        );
      }
    });

    test('sectionOfParam agrees with the catalog dashboardGroup for every '
        'core parameter', () {
      for (final p in kReefParameters.where((p) => !p.isMicro)) {
        final expected = switch (p.dashboardGroup!) {
          DashboardGroup.coreChemistry => DashboardSection.coreChemistry,
          DashboardGroup.nutrients => DashboardSection.nutrients,
          DashboardGroup.environment => DashboardSection.environment,
        };
        expect(sectionOfParam(p.key), expected, reason: p.key);
      }
    });
  });
}
