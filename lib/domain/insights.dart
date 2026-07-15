/// Pure, testable rule-based tank insights (U28). Like `health_score.dart`
/// and `stability_score.dart` this has no Flutter and no DB dependency — it
/// works on the domain's own outputs so it can be unit-tested in isolation.
///
/// Where the health score answers *"how is the tank doing?"* as one number,
/// the insights answer *"so what should I look at?"* — a short prioritized
/// list of observations composed from signals the domain already computes:
/// zone classification, trend slopes and forecasts, the recovering flag, and
/// the health score's freshness rule. Deterministic rules, no inference, no
/// network — every insight is explainable from the user's own data.
///
/// An [Insight] is a **typed value** (kind + severity + numeric payload),
/// never text: the widget layer maps kinds to localized ARB messages, so the
/// rule set stays one translation key per kind instead of free text ×5
/// languages.
library;

import 'clock.dart';
import 'health_score.dart';
import 'trend.dart';
import 'zones.dart';

/// How urgent an insight is; also its sort rank (critical first). [positive]
/// deliberately sorts last — reassurance never outranks a problem.
enum InsightSeverity { critical, warning, notice, positive }

/// The rule that produced an insight, which is also its message shape.
enum InsightKind {
  /// The latest fresh reading sits in its amber or red zone (and is not
  /// recovering): severity [InsightSeverity.critical] for red,
  /// [InsightSeverity.warning] for amber. [Insight.worsening] is true when
  /// the trend still points further out of range.
  outOfRange,

  /// The value is in range but its trend forecast crosses a zone bound
  /// within the horizon: [Insight.days] is the soonest projected crossing.
  /// [InsightSeverity.warning] when the *red* bound is within the horizon,
  /// [InsightSeverity.notice] when only the amber bound is.
  forecast,

  /// The value is out of range but heading back toward green
  /// ([TrendResult.recovering], the U15 positive surface):
  /// [InsightSeverity.positive], [Insight.days] estimates re-entry when the
  /// trend can say.
  recovering,

  /// The parameter has a reading but it is older than the health score's
  /// freshness window — the score and trends are flying blind for it.
  /// [InsightSeverity.notice], [Insight.days] = days since the last test.
  staleTest,
}

/// One prioritized observation about a parameter. Value-equal (T2) so an
/// unchanged recompute doesn't read as a new list entry.
class Insight {
  const Insight({
    required this.paramKey,
    required this.kind,
    required this.severity,
    this.isLow,
    this.worsening = false,
    this.days,
  });

  final String paramKey;
  final InsightKind kind;
  final InsightSeverity severity;

  /// Which side of the range the value sits on / is heading toward: true =
  /// low, false = high, null = undeterminable (message drops the side).
  final bool? isLow;

  /// [InsightKind.outOfRange] only: the trend still points further away from
  /// the green range (false also when no trend is available).
  final bool worsening;

  /// Rounded day estimate, meaning per [kind]: projected crossing
  /// ([InsightKind.forecast]), projected re-entry ([InsightKind.recovering],
  /// null when the trend can't say), or days since the last test
  /// ([InsightKind.staleTest]). Always >= 1 for the projections.
  final int? days;

  @override
  bool operator ==(Object other) =>
      other is Insight &&
      other.paramKey == paramKey &&
      other.kind == kind &&
      other.severity == severity &&
      other.isLow == isLow &&
      other.worsening == worsening &&
      other.days == days;

  @override
  int get hashCode =>
      Object.hash(paramKey, kind, severity, isLow, worsening, days);

  @override
  String toString() =>
      'Insight($paramKey, $kind, $severity, isLow: $isLow, '
      'worsening: $worsening, days: $days)';
}

/// Rounds a positive day estimate to a whole number, never below 1 — the same
/// presentation rule as the trend chips ("~1 d" is the soonest we claim).
int _roundDays(double v) {
  final r = v.round();
  return r < 1 ? 1 : r;
}

/// Which side of its green range [value] sits on: true = low, false = high,
/// null when it can't be placed (in range, or no bound on the violated side).
bool? lowSideOf(ZoneBounds b, double value) {
  if (!b.isValid) return null;
  final low = b.greenLow ?? b.amberLow;
  final high = b.greenHigh ?? b.amberHigh;
  if (low != null && value < low) return true;
  if (high != null && value > high) return false;
  return null;
}

/// Composes the prioritized insight list from the computed [health], the
/// per-parameter [trends] (pass an empty map when trend detection is off —
/// the out-of-range and stale rules still work, just without direction or
/// forecasts), and each parameter's [bounds] (for the low/high wording).
///
/// [horizonDays] bounds the forecast rule exactly like the dashboard trend
/// chips: a projected crossing further out is not worth an insight.
///
/// Ordering: severity (critical → warning → notice → positive), then the
/// health score's importance weight (an alkalinity problem outranks a
/// nitrate one), then input order — deterministic for a given input.
List<Insight> computeInsights({
  required TankHealth health,
  required Map<String, TrendResult> trends,
  required Map<String, ZoneBounds> bounds,
  int horizonDays = kTrendDefaultHorizon,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final insights = <Insight>[];

  for (final p in health.parameters) {
    final trend = trends[p.paramKey];

    if (p.includedInScore) {
      // includedInScore guarantees a fresh value and usable bounds.
      final value = p.value!;
      final b = bounds[p.paramKey] ?? const ZoneBounds();

      if (p.zone == Zone.red || p.zone == Zone.amber) {
        final isLow = lowSideOf(b, value);
        if (trend != null && trend.recovering) {
          // Rule 3: recovering — reassure instead of alarming (#25/U15).
          insights.add(
            Insight(
              paramKey: p.paramKey,
              kind: InsightKind.recovering,
              severity: InsightSeverity.positive,
              isLow: isLow,
              days: trend.daysToGreen != null
                  ? _roundDays(trend.daysToGreen!)
                  : null,
            ),
          );
        } else {
          // Rule 1: out of range, with a "still worsening" qualifier when
          // the trend points further away from green.
          final worsening =
              trend != null &&
              isLow != null &&
              (isLow
                  ? trend.direction == TrendDirection.falling
                  : trend.direction == TrendDirection.rising);
          insights.add(
            Insight(
              paramKey: p.paramKey,
              kind: InsightKind.outOfRange,
              severity: p.zone == Zone.red
                  ? InsightSeverity.critical
                  : InsightSeverity.warning,
              isLow: isLow,
              worsening: worsening,
            ),
          );
        }
      } else if (p.zone == Zone.green &&
          trend != null &&
          trend.hasForecast &&
          trend.soonestCrossing! <= horizonDays) {
        // Rule 2: preemptive — in range today, projected out within the
        // horizon. Red crossing inside the horizon outranks amber-only.
        insights.add(
          Insight(
            paramKey: p.paramKey,
            kind: InsightKind.forecast,
            severity:
                (trend.daysToRed != null && trend.daysToRed! <= horizonDays)
                ? InsightSeverity.warning
                : InsightSeverity.notice,
            isLow: trend.direction == TrendDirection.falling,
            days: _roundDays(trend.soonestCrossing!),
          ),
        );
      }
    } else if (p.stale && p.value != null && p.takenAt != null) {
      // Rule 4: has history but the latest test is too old to trust. A
      // parameter never tested at all is deliberately not flagged — a newly
      // tracked parameter would nag from day one.
      insights.add(
        Insight(
          paramKey: p.paramKey,
          kind: InsightKind.staleTest,
          severity: InsightSeverity.notice,
          days: daysSince(p.takenAt!, now: clock),
        ),
      );
    }
  }

  // Stable sort: severity rank, then importance weight (desc), then input
  // order (List.sort isn't stable, so the original index breaks ties).
  final indexed = insights.asMap().entries.toList()
    ..sort((a, b) {
      final bySeverity = a.value.severity.index.compareTo(
        b.value.severity.index,
      );
      if (bySeverity != 0) return bySeverity;
      final byWeight = importanceWeightFor(
        b.value.paramKey,
      ).compareTo(importanceWeightFor(a.value.paramKey));
      if (byWeight != 0) return byWeight;
      return a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}
