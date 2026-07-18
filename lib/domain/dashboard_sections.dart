/// The grouped dashboard's fixed section model and composite sort key
/// (REDESIGN #6). Pure and DB-free like `ratio.dart`: works on plain keys
/// and order values mapped at the call sites, so it can be unit-tested in
/// isolation.
library;

import 'parameter_catalog.dart';
import 'ratio.dart';

/// Fixed top-to-bottom section order of the grouped dashboard. Not
/// user-controllable — the shared `displayOrder` space only orders items
/// *within* a section. [other] is the headerless trailing bucket for tracked
/// params without a catalog entry (legacy hand-edited keys render as core,
/// see [isCoreParam]) so nothing a user tracks silently disappears. The
/// Microelements summary tile is pinned after every section and is not part
/// of this enum.
enum DashboardSection { coreChemistry, nutrients, ratios, environment, other }

/// The section a tracked core parameter renders in, from its catalog group.
/// Only meaningful for keys that pass [isCoreParam] — microelements never
/// reach the dashboard grid.
DashboardSection sectionOfParam(String paramKey) =>
    switch (kParameterByKey[paramKey]?.dashboardGroup) {
      DashboardGroup.core => DashboardSection.coreChemistry,
      DashboardGroup.nutrients => DashboardSection.nutrients,
      DashboardGroup.environment => DashboardSection.environment,
      null => DashboardSection.other,
    };

/// Composite dashboard sort key: fixed section rank first, then the
/// user-managed shared display order (now meaningful within a section only),
/// then a stable catalog tiebreak — fresh installs can collide a ratio's
/// default order (1000+) with a stored parameter order numerically, and ties
/// must sort deterministically.
///
/// Used by the dashboard grid, the Manage Parameters list (mirror-sorted so
/// manage order always equals dashboard order) and the compare view's chart
/// stack.
class DashboardSortKey implements Comparable<DashboardSortKey> {
  const DashboardSortKey(this.section, this.order, this.tiebreak);

  final DashboardSection section;
  final double order;
  final double tiebreak;

  @override
  int compareTo(DashboardSortKey other) {
    final bySection = section.index.compareTo(other.section.index);
    if (bySection != 0) return bySection;
    final byOrder = order.compareTo(other.order);
    if (byOrder != 0) return byOrder;
    return tiebreak.compareTo(other.tiebreak);
  }
}

/// Sort key for a tracked (core) parameter tile/row. Unknown keys sort into
/// [DashboardSection.other] with a past-catalog tiebreak.
DashboardSortKey paramSortKey(String paramKey, int displayOrder) =>
    DashboardSortKey(
      sectionOfParam(paramKey),
      displayOrder.toDouble(),
      (kParameterIndexByKey[paramKey] ?? kReefParameters.length).toDouble(),
    );

/// Sort key for a ratio card/row.
DashboardSortKey ratioSortKey(RatioKind kind, RatioSettings? settings) =>
    DashboardSortKey(
      DashboardSection.ratios,
      ratioRowOrder(kind, settings),
      kind.index.toDouble(),
    );
