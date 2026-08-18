/// Presentation policy for ratio values and charts.
///
/// Ratio entities own chemistry/math only. This neutral Flutter-facing module
/// decides whether a ratio reads as `1 : N` or a decimal and formats it for
/// every dashboard/history/editor consumer.
library;

import '../domain/ratio.dart';
import '../domain/units.dart';

enum RatioDisplay { oneToN, decimal }

RatioDisplay ratioDisplayOf(RatioKind kind) => switch (kind) {
  RatioKind.po4no3 => RatioDisplay.oneToN,
  RatioKind.mgca || RatioKind.caalk || RatioKind.mgalk => RatioDisplay.decimal,
};

String formatRatioN(double value) {
  if (!value.isFinite) return '—';
  if (value >= 10) return formatLocaleNumber(value, 0);
  if (value >= 1) return formatLocaleNumber(value, 1);
  return formatLocaleNumber(value, 2);
}

String formatRatioValue(RatioKind kind, double ratio) {
  switch (ratioDisplayOf(kind)) {
    case RatioDisplay.oneToN:
      if (!ratio.isFinite || ratio <= 0) return '—';
      return '1 : ${formatRatioN(1 / ratio)}';
    case RatioDisplay.decimal:
      if (!ratio.isFinite) return '—';
      return formatLocaleNumber(ratio, 1);
  }
}

String ratioMetricLabel(RatioKind kind) => switch (ratioDisplayOf(kind)) {
  RatioDisplay.oneToN => '${kind.denominatorSymbol} ÷ ${kind.numeratorSymbol}',
  RatioDisplay.decimal => '${kind.numeratorSymbol} ÷ ${kind.denominatorSymbol}',
};

String formatRatioBound(RatioKind kind, double value) => switch (ratioDisplayOf(
  kind,
)) {
  RatioDisplay.oneToN => value == 0 ? '—' : formatRatioValue(kind, 1 / value),
  RatioDisplay.decimal => formatRatioValue(kind, value),
};
