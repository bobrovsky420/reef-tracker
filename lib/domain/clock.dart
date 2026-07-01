/// Wall-clock helpers that stay sane when the device clock is wrong or a record
/// is (accidentally) timestamped in the future. Centralizing "now" here also
/// keeps the comparisons injectable/testable via the optional [now] argument.
library;

/// Age of [t] measured from [now] (default: the wall clock), never negative.
///
/// A future [t] — e.g. a reading logged ahead of time, or a device clock that
/// moved backward after the reading was saved — clamps to [Duration.zero]
/// instead of yielding a negative duration that would read as "just now" math
/// gone wrong, "-N days ago", or a bogus "always fresh" health input.
Duration ageSince(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  return d.isNegative ? Duration.zero : d;
}

/// Whole days since [t], rounded to the nearest day (not truncated) and clamped
/// to `>= 0`. Rounding avoids under-counting: a reading 18 h into its 7th day
/// reads as 7 days, not 6.
int daysSince(DateTime t, {DateTime? now}) =>
    (ageSince(t, now: now).inMinutes / (60 * 24)).round();
