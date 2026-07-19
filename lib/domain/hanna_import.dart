/// Hanna Lab measurement import (U32) — pure parsing of the CSV history the
/// Hanna Lab phone app shares per Hanna tank (HI97115 Marine Master and
/// friends), plus the session/dedupe planning math. No Flutter, no DB.
///
/// Format facts (verified against a real 2026-07 export): UTF-8 with BOM; a
/// metadata preamble (`Meter`, `Meter ID`, `Meter Serial Number`,
/// `Meter Firmware`, `Sample Location` = the Hanna-app tank name), a blank
/// line, then `Reading,Unit,Method,Date,Status,Note` rows. Dates are
/// `dd/MM/yyyy HH:mm:ss` local wall-clock with no zone. The file is the FULL
/// history on every export, newest-first in the sample — an observation, not
/// a contract; nothing here relies on row order. Identical rows repeat (the
/// app duplicates some log entries 3–7×) and range failures appear as
/// non-numeric readings (`<200`) with a `Status` message.
///
/// Values are already canonical (ppm / dKH / pH); mapping is on the `Method`
/// column, never on `Unit` — the unit strings carry Unicode sub/superscripts
/// (`ppm PO₄³⁻`) whose encoding varies with how the file was produced.
library;

import 'icp_import.dart' show parseDelimitedCsv;

/// Rows are matched to catalog parameters by the method's leading keyword so
/// range variants (`Nitrate Marine HR`/`LR`, `Phosphate Marine ULR`/`HR`)
/// all map. Order matters: `phosphate` must match before `ph`.
const List<(String, String)> _kMethodPrefixToKey = [
  ('alkalinity', 'alkalinity'),
  ('calcium', 'calcium'),
  ('magnesium', 'magnesium'),
  ('nitrate', 'nitrate'),
  ('phosphate', 'phosphate'),
  ('ammonia', 'ammonia'),
  ('ph', 'ph'),
];

/// The `ImportSources.source` value for this format. Persisted (unlike
/// ProFeature keys) — never rename without a migration.
const String kHannaImportSource = 'hannaLab';

/// Why a file was rejected — mirrors `IcpImportRejection`; the UI reuses the
/// ICP rejection messages (they name no lab).
enum HannaImportRejection { unreadable, wrongFormat, noValues }

/// Raised when a file can't be imported. [reason] drives the user-facing
/// message; [detail] carries developer-facing context.
class HannaImportException implements Exception {
  const HannaImportException(this.reason, [this.detail]);
  final HannaImportRejection reason;
  final String? detail;
  @override
  String toString() =>
      'HannaImportException(${reason.name})${detail == null ? '' : ': $detail'}';
}

/// Why a data row was left out of [HannaImportResult.rows] — surfaced on the
/// preview so data never silently disappears (the `icp_import.dart` policy).
enum HannaSkipReason {
  /// The meter flagged the measurement (`Status` non-empty, e.g.
  /// "Under Range. Check Sample/Prep.") — there is no importable value.
  outOfRange,

  /// A `Method` (or its unit) the app maps to nothing it tracks.
  unknownTest,

  /// A reading or date that doesn't parse.
  badValue,
}

/// One row the parser rejected: the raw method label (a Hanna proper noun,
/// not localized) and why.
class HannaSkippedRow {
  const HannaSkippedRow(this.label, this.reason);
  final String label;
  final HannaSkipReason reason;
}

/// One importable measurement, in the catalog's canonical unit.
class HannaReading {
  const HannaReading({
    required this.paramKey,
    required this.value,
    required this.takenAt,
  });

  final String paramKey;
  final double value;

  /// The file's wall-clock timestamp parsed as local time (the export carries
  /// no zone). Second-precise and stable across re-exports — the watermark
  /// and rewind-diff both key on it.
  final DateTime takenAt;
}

/// The parsed contents of a Hanna Lab export, ready for the preview screen.
class HannaImportResult {
  const HannaImportResult({
    required this.meter,
    required this.location,
    required this.rows,
    required this.skipped,
  });

  /// Meter model from the preamble (e.g. `HI97115`), or null when absent.
  final String? meter;

  /// `Sample Location` — the Hanna-app tank name this history belongs to.
  /// Drives the remembered location → tank mapping. Null when absent.
  final String? location;

  /// Importable readings, oldest first, exact in-file duplicates collapsed
  /// (first occurrence wins, keyed on parameter + timestamp).
  final List<HannaReading> rows;

  /// Rows left out, in file order.
  final List<HannaSkippedRow> skipped;
}

/// Parses [content] as a Hanna Lab CSV export. Throws [HannaImportException]
/// when the file doesn't match.
HannaImportResult parseHannaCsv(String content) {
  final rows = parseDelimitedCsv(content, ',');

  String? meter;
  String? location;
  var headerIdx = -1;
  for (var i = 0; i < rows.length; i++) {
    final first = rows[i].first.trim();
    if (first == 'Meter' && rows[i].length > 1) {
      meter = rows[i][1].trim();
    } else if (first == 'Sample Location' && rows[i].length > 1) {
      location = rows[i][1].trim();
    } else if (first == 'Reading' &&
        rows[i].any((c) => c.trim() == 'Method') &&
        rows[i].any((c) => c.trim() == 'Date')) {
      headerIdx = i;
      break;
    }
  }
  // The meter preamble plus the Reading/Method/Date header is what makes this
  // a Hanna Lab export; either missing means the wrong file (or format pick).
  if (headerIdx < 0 || meter == null) {
    throw const HannaImportException(
      HannaImportRejection.wrongFormat,
      'missing hanna preamble or header row',
    );
  }
  final header = [for (final c in rows[headerIdx]) c.trim()];
  final readingIdx = header.indexOf('Reading');
  final unitIdx = header.indexOf('Unit');
  final methodIdx = header.indexOf('Method');
  final dateIdx = header.indexOf('Date');
  final statusIdx = header.indexOf('Status');

  final seen = <String>{};
  final imported = <HannaReading>[];
  final skipped = <HannaSkippedRow>[];
  for (final row in rows.skip(headerIdx + 1)) {
    if (row.length <= methodIdx || row.length <= dateIdx) continue;
    final method = row[methodIdx].trim();
    if (method.isEmpty) continue;

    // A meter-flagged measurement (under/over range) carries no usable value.
    final status = statusIdx >= 0 && row.length > statusIdx
        ? row[statusIdx].trim()
        : '';
    if (status.isNotEmpty) {
      skipped.add(HannaSkippedRow(method, HannaSkipReason.outOfRange));
      continue;
    }

    final key = hannaMethodKey(method);
    final unit = unitIdx >= 0 && row.length > unitIdx ? row[unitIdx].trim() : '';
    if (key == null || !_unitMatches(key, unit)) {
      skipped.add(HannaSkippedRow(method, HannaSkipReason.unknownTest));
      continue;
    }

    final value = _parseNumber(row[readingIdx]);
    final takenAt = _parseHannaDate(row[dateIdx]);
    if (value == null || takenAt == null) {
      skipped.add(HannaSkippedRow(method, HannaSkipReason.badValue));
      continue;
    }

    // Exact in-file duplicates (the 3–7× repeated log rows) collapse
    // silently; parameter + timestamp identifies a measurement.
    if (seen.add('$key|${takenAt.millisecondsSinceEpoch}')) {
      imported.add(
        HannaReading(paramKey: key, value: value, takenAt: takenAt),
      );
    }
  }
  if (imported.isEmpty && skipped.isEmpty) {
    throw const HannaImportException(HannaImportRejection.noValues);
  }
  imported.sort((a, b) => a.takenAt.compareTo(b.takenAt));
  return HannaImportResult(
    meter: meter,
    location: (location?.isEmpty ?? true) ? null : location,
    rows: imported,
    skipped: skipped,
  );
}

/// Resolves a Hanna `Method` label to a catalog key, or null when the app
/// tracks nothing it could map to.
String? hannaMethodKey(String method) {
  final m = method.trim().toLowerCase();
  for (final (prefix, key) in _kMethodPrefixToKey) {
    if (m.startsWith(prefix)) return key;
  }
  return null;
}

/// Whether the row's unit is the one the app's canonical unit expects for
/// [key]. Prefix-matched (`ppm PO₄³⁻` → `ppm`) so the Unicode tail — whose
/// encoding depends on how the file traveled — never matters. A mismatch
/// (e.g. a checker configured to ppm CaCO₃ alkalinity) is skipped rather
/// than converted: no guessing, same policy as the ZIMS unit handling.
bool _unitMatches(String key, String unit) {
  final u = unit.toLowerCase();
  return switch (key) {
    'ph' => u == 'ph',
    'alkalinity' => u == 'dkh',
    _ => u.startsWith('ppm'),
  };
}

/// Parses `dd/MM/yyyy HH:mm:ss` as local wall-clock time. Day-first per the
/// format; a US-locale export (month-first) self-disambiguates when the
/// day field exceeds 12 — full histories always contain such dates.
DateTime? _parseHannaDate(String raw) {
  final m = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})$',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  var day = int.parse(m.group(1)!);
  var month = int.parse(m.group(2)!);
  if (month > 12 && day <= 12) (day, month) = (month, day);
  final year = int.parse(m.group(3)!);
  final hour = int.parse(m.group(4)!);
  final minute = int.parse(m.group(5)!);
  final second = int.parse(m.group(6)!);
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23) return null;
  final dt = DateTime(year, month, day, hour, minute, second);
  // DateTime rolls over out-of-range days (31/04 → 01/05); reject those.
  return dt.day == day && dt.month == month ? dt : null;
}

/// Parses a reading accepting `.` or `,` as the decimal separator (the
/// export's locale — unambiguous, Hanna never groups digits).
double? _parseNumber(String raw) {
  var t = raw.trim();
  if (t.isEmpty || (t.contains('.') && t.contains(','))) return null;
  t = t.replaceAll(',', '.');
  final v = double.tryParse(t);
  return v != null && v.isFinite ? v : null;
}

/// Splits chronological [rows] into test sessions: a new session starts when
/// the gap to the previous reading exceeds [maxGap]. An imported session
/// becomes one reading group, so it reads like a manually entered batch.
List<List<HannaReading>> hannaSessions(
  List<HannaReading> rows, {
  Duration maxGap = const Duration(minutes: 90),
}) {
  final sessions = <List<HannaReading>>[];
  for (final r in rows) {
    if (sessions.isEmpty ||
        r.takenAt.difference(sessions.last.last.takenAt) > maxGap) {
      sessions.add([r]);
    } else {
      sessions.last.add(r);
    }
  }
  return sessions;
}

/// What an import of [HannaImportResult.rows] into one tank would do.
class HannaImportPlan {
  const HannaImportPlan({
    required this.newRows,
    required this.alreadyImported,
    required this.beforeCutoff,
  });

  /// Rows that would be inserted, oldest first.
  final List<HannaReading> newRows;

  /// Rows at or below the watermark — plus, after a rewind, rows in the
  /// re-covered range that the diff matched against existing readings.
  final int alreadyImported;

  /// First-import only: rows the user's chosen start date excludes.
  final int beforeCutoff;
}

/// Key of a reading in the rewind-diff set — shared by the planner and the
/// screen building [existingKeys] from DB rows.
String hannaReadingKey(String paramKey, DateTime takenAt) =>
    '$paramKey|${takenAt.millisecondsSinceEpoch}';

/// Computes what an import would insert (decided 2026-07-19, U32):
///
/// * Normal import: everything strictly newer than [importedUpTo].
/// * First import ([importedUpTo] null): everything from [cutoff] on (null =
///   the full history) — the user's explicit answer to pre-integration
///   manually-typed history.
/// * After a settings rewind/reset ([rewound]): the watermark alone would
///   duplicate the re-covered range, so candidates are additionally diffed
///   against [existingKeys] ([hannaReadingKey] of the tank's readings in
///   range) and only genuinely missing rows import.
HannaImportPlan planHannaImport({
  required List<HannaReading> rows,
  DateTime? importedUpTo,
  DateTime? cutoff,
  bool rewound = false,
  Set<String> existingKeys = const {},
}) {
  var alreadyImported = 0;
  var beforeCutoff = 0;
  final newRows = <HannaReading>[];
  for (final r in rows) {
    if (importedUpTo != null) {
      if (!r.takenAt.isAfter(importedUpTo)) {
        alreadyImported++;
        continue;
      }
    } else if (cutoff != null && r.takenAt.isBefore(cutoff)) {
      beforeCutoff++;
      continue;
    }
    if (rewound && existingKeys.contains(hannaReadingKey(r.paramKey, r.takenAt))) {
      alreadyImported++;
      continue;
    }
    newRows.add(r);
  }
  return HannaImportPlan(
    newRows: newRows,
    alreadyImported: alreadyImported,
    beforeCutoff: beforeCutoff,
  );
}
