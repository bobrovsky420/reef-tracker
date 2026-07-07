import 'parameter_catalog.dart';

/// ICP report import (U17 phase 2) — pure parsing of lab CSV exports into
/// canonical readings. Two formats are supported, chosen explicitly by the
/// user (no sniffing): the Fauna Marin lab portal's raw "wide" CSV export and
/// the universal ZIMS "long" measurement export. No Flutter, no DB.
///
/// All concentrations are converted to the app's canonical ppm (mg/L) here,
/// so the UI layer only deals in canonical values (like the manual entry
/// forms after `toCanonical`).

/// The CSV export formats the import screen can read.
enum IcpImportFormat { faunaMarin, zims }

/// Display name of a format — lab/product proper nouns, not localized (same
/// policy as supplement brand names).
String icpFormatDisplayName(IcpImportFormat format) => switch (format) {
  IcpImportFormat.faunaMarin => 'Fauna Marin ICP',
  IcpImportFormat.zims => 'ZIMS',
};

/// Why a file was rejected. Each value maps to a distinct localized message
/// (same pattern as `BackupRejection`).
enum IcpImportRejection {
  /// Not parseable as CSV text at all (binary, empty).
  unreadable,

  /// Parsed as CSV but the header doesn't match the chosen format.
  wrongFormat,

  /// Recognized structure, but not a single importable value in it.
  noValues,
}

/// Raised when a file can't be imported. [reason] drives the user-facing
/// message; [detail] carries developer-facing context.
class IcpImportException implements Exception {
  const IcpImportException(this.reason, [this.detail]);
  final IcpImportRejection reason;
  final String? detail;
  @override
  String toString() =>
      'IcpImportException(${reason.name})${detail == null ? '' : ': $detail'}';
}

/// The parsed contents of an ICP report, ready for the import preview screen.
class IcpImportResult {
  const IcpImportResult({
    required this.format,
    required this.values,
    required this.skipped,
    this.reportDate,
    this.sampleId,
  });

  final IcpImportFormat format;

  /// Catalog `paramKey` → canonical value (ppm for concentrations, dKH/pH
  /// as-is), in catalog order.
  final Map<String, double> values;

  /// Source labels (column codes / measurement names) that carried a value
  /// but map to nothing the app tracks — surfaced on the preview screen so
  /// data never silently disappears.
  final List<String> skipped;

  /// The analysis timestamp from the file (Fauna Marin `analysis_date`, ZIMS
  /// `Date`+`Time`). Only a *default* for the sample date the user picks —
  /// the water sample is typically taken days earlier.
  final DateTime? reportDate;

  /// Fauna Marin `sample_id`, used to warn about re-importing the same
  /// report. Null for ZIMS (the format carries no identifier).
  final String? sampleId;
}

/// Parses [content] as a [format] CSV export. Throws [IcpImportException]
/// when the file doesn't match.
IcpImportResult parseIcpCsv(String content, IcpImportFormat format) =>
    switch (format) {
      IcpImportFormat.faunaMarin => _parseFaunaMarin(content),
      IcpImportFormat.zims => _parseZims(content),
    };

// --- Fauna Marin (wide, semicolon-separated) --------------------------------
//
// One row per analysis; element codes as column headers; **implicit units**
// fixed by the lab's convention (verified against the ZIMS export of the same
// analysis): major ions in mg/L, trace elements in µg/L. Decimal separator
// depends on the export locale (`,` in the -de download, `.` otherwise) —
// unambiguous either way because the field delimiter is `;`.

/// Columns reported in mg/L (already canonical ppm), including the non-ICP
/// wet-chemistry extras the report carries.
const Map<String, String> _kFaunaMarinMgL = {
  'na': 'sodium',
  's': 'sulfur',
  'b': 'boron',
  'br': 'bromine',
  'ca': 'calcium',
  'mg': 'magnesium',
  'k': 'potassium',
  'sr': 'strontium',
  'i': 'iodine',
  'si': 'silicon',
  'nitrate': 'nitrate',
  'nitrite': 'nitrite',
};

/// Columns reported in µg/L → ÷1000 to canonical ppm.
const Map<String, String> _kFaunaMarinUgL = {
  'fe': 'iron',
  'zn': 'zinc',
  'v': 'vanadium',
  'cu': 'copper',
  'ni': 'nickel',
  'mn': 'manganese',
  'mo': 'molybdenum',
  'cr': 'chromium',
  'co': 'cobalt',
  'li': 'lithium',
  'ba': 'barium',
  'se': 'selenium',
  'al': 'aluminium',
  'sb': 'antimony',
  'sn': 'tin',
  'be': 'beryllium',
  'ag': 'silver',
  'w': 'tungsten',
  'la': 'lanthanum',
  'ti': 'titanium',
  'zr': 'zirconium',
  'as': 'arsenic',
  'cd': 'cadmium',
  'hg': 'mercury',
  'pb': 'lead',
};

/// Unitless / already-canonical columns (header lowercased).
const Map<String, String> _kFaunaMarinDirect = {
  'ph': 'ph',
  'alkalinitydkh': 'alkalinity',
};

/// Bookkeeping columns that are never "skipped values" even when populated.
/// `salinity` is deliberately unmapped-but-skippable instead: Fauna Marin
/// reports ppt while the app's canonical salinity is SG, so it surfaces in
/// the skipped list rather than importing a wrong-by-35x value.
const Set<String> _kFaunaMarinMeta = {
  'id',
  'water_type',
  'owner_type',
  'analysis_date',
  'note',
  'aquarium_id',
  'sample_id',
  'smell',
  'color',
  // Phosphate is imported from these two with explicit precedence below —
  // never through the generic column loop.
  'po4g',
  'po4er',
  // Elemental phosphorus: mapping it alongside PO4 would double-log
  // phosphate. It backs `po4er` anyway (PO4 = P × 3.066).
  'p',
};

IcpImportResult _parseFaunaMarin(String content) {
  final rows = _parseCsv(content, ';');
  if (rows.length < 2) {
    throw const IcpImportException(
      IcpImportRejection.wrongFormat,
      'no data row',
    );
  }
  final header = [for (final h in rows.first) h.trim().toLowerCase()];
  // The columns every Fauna Marin export carries; their absence means this
  // isn't one (e.g. a ZIMS file imported under the wrong format choice).
  if (!header.contains('analysis_date') || !header.contains('na')) {
    throw const IcpImportException(
      IcpImportRejection.wrongFormat,
      'missing fauna marin header columns',
    );
  }
  final row = rows[1];
  String? cell(String name) {
    final idx = header.indexOf(name);
    if (idx < 0 || idx >= row.length) return null;
    final v = row[idx].trim();
    return v.isEmpty ? null : v;
  }

  final values = <String, double>{};
  final skipped = <String>[];
  for (var i = 0; i < header.length && i < row.length; i++) {
    final col = header[i];
    final raw = row[i].trim();
    if (raw.isEmpty) continue;
    final mgL = _kFaunaMarinMgL[col];
    final ugL = _kFaunaMarinUgL[col];
    final direct = _kFaunaMarinDirect[col];
    if (mgL == null && ugL == null && direct == null) {
      if (!_kFaunaMarinMeta.contains(col)) skipped.add(col);
      continue;
    }
    final parsed = _parseCsvNumber(raw);
    if (parsed == null) {
      skipped.add(col);
      continue;
    }
    values[mgL ?? direct ?? ugL!] = ugL != null ? parsed / 1000 : parsed;
  }
  // Orthophosphate (mg/L): prefer the photometric measurement (`po4g`), fall
  // back to the value the lab calculates from ICP phosphorus (`po4er`).
  final po4 = _parseCsvNumber(cell('po4g') ?? cell('po4er') ?? '');
  if (po4 != null) values['phosphate'] = po4;
  if (values.isEmpty) {
    throw const IcpImportException(IcpImportRejection.noValues);
  }
  return IcpImportResult(
    format: IcpImportFormat.faunaMarin,
    values: _inCatalogOrder(values),
    skipped: skipped,
    reportDate: switch (cell('analysis_date')) {
      final d? => DateTime.tryParse(d),
      null => null,
    },
    sampleId: cell('sample_id'),
  );
}

// --- ZIMS (long, comma-separated) -------------------------------------------
//
// One row per measurement with an explicit unit column — self-describing, so
// matching is by measurement *name*, tolerant of labeling variants:
// tier 1 matches the parenthetical element symbol ("Strontium (Sr2+)" → Sr)
// against the catalog, tier 2 matches the name against an alias map.

/// Element symbol → catalog key. Catalog symbols cover the micro panel; core
/// parameters (whose `ParameterDef.symbol` is null) are added explicitly.
final Map<String, String> _kSymbolToKey = {
  for (final p in kReefParameters)
    if (p.symbol != null) p.symbol!: p.key,
  'Ca': 'calcium',
  'Mg': 'magnesium',
  'K': 'potassium',
};

/// Lowercased measurement-name aliases, covering en-US/en-GB spelling
/// variants and the species (I2/iodide) collapsing onto the tracked total.
/// `phosphorus` (elemental P) is deliberately absent: PO4 is imported from
/// the Orthophosphate row instead, never both.
const Map<String, String> _kZimsNameToKey = {
  'sodium': 'sodium',
  'sulfur': 'sulfur',
  'sulphur': 'sulfur',
  'boron': 'boron',
  'bromine': 'bromine',
  'strontium': 'strontium',
  'iodine': 'iodine',
  'iodide': 'iodine',
  'silicon': 'silicon',
  'iron': 'iron',
  'zinc': 'zinc',
  'vanadium': 'vanadium',
  'copper': 'copper',
  'nickel': 'nickel',
  'manganese': 'manganese',
  'molybdenum': 'molybdenum',
  'chromium': 'chromium',
  'cobalt': 'cobalt',
  'lithium': 'lithium',
  'barium': 'barium',
  'selenium': 'selenium',
  'aluminium': 'aluminium',
  'aluminum': 'aluminium',
  'antimony': 'antimony',
  'tin': 'tin',
  'beryllium': 'beryllium',
  'silver': 'silver',
  'tungsten': 'tungsten',
  'lanthanum': 'lanthanum',
  'titanium': 'titanium',
  'zirconium': 'zirconium',
  'arsenic': 'arsenic',
  'cadmium': 'cadmium',
  'mercury': 'mercury',
  'lead': 'lead',
  'calcium': 'calcium',
  'magnesium': 'magnesium',
  'potassium': 'potassium',
  'orthophosphate': 'phosphate',
  'phosphate': 'phosphate',
  'nitrate': 'nitrate',
  'nitrite': 'nitrite',
};

/// Resolves a ZIMS measurement label to a catalog key, or null when the app
/// tracks nothing it could map to.
String? zimsMeasurementKey(String label) {
  // Tier 1: the parenthetical symbol, stripped of charges and stoichiometric
  // digits ("Sr2+" → Sr, "I2" → I, "Na+" → Na). "PO4" strips to "PO", which
  // matches no symbol and correctly falls through to the name tier.
  final paren = RegExp(r'\(([^)]*)\)').firstMatch(label)?.group(1);
  if (paren != null) {
    final symbol = paren.replaceAll(RegExp(r'[0-9+\-]'), '').trim();
    final key = _kSymbolToKey[symbol];
    if (key != null) return key;
  }
  // Tier 2: the name before the parenthetical, against the alias map.
  final name = label.split('(').first.trim().toLowerCase();
  return _kZimsNameToKey[name];
}

/// Canonical-ppm factor for a ZIMS unit label, or null when unrecognized
/// (such rows are reported as skipped, never guessed).
double? zimsUnitFactor(String unit) {
  final u = unit.trim().toLowerCase();
  if (u.contains('microgram') ||
      u.startsWith('µg') ||
      u.startsWith('ug') ||
      u == 'ppb') {
    return 0.001;
  }
  if (u.contains('milligram') || u.startsWith('mg') || u == 'ppm') return 1;
  return null;
}

IcpImportResult _parseZims(String content) {
  final rows = _parseCsv(content, ',');
  if (rows.length < 2) {
    throw const IcpImportException(
      IcpImportRejection.wrongFormat,
      'no data row',
    );
  }
  final header = [
    for (final h in rows.first) h.trim().toLowerCase().replaceAll(' ', ''),
  ];
  final nameIdx = header.indexOf('measurement');
  final valueIdx = header.indexOf('measurementvalue');
  final unitIdx = header.indexOf('unitofmeasure');
  final dateIdx = header.indexOf('date');
  final timeIdx = header.indexOf('time');
  if (nameIdx < 0 || valueIdx < 0 || unitIdx < 0) {
    throw const IcpImportException(
      IcpImportRejection.wrongFormat,
      'missing zims header columns',
    );
  }

  final values = <String, double>{};
  final skipped = <String>[];
  DateTime? reportDate;
  for (final row in rows.skip(1)) {
    if (row.length <= nameIdx || row.length <= valueIdx) continue;
    final label = row[nameIdx].trim();
    if (label.isEmpty) continue;
    final key = zimsMeasurementKey(label);
    final parsed = _parseCsvNumber(row[valueIdx]);
    if (key == null || parsed == null) {
      skipped.add(label);
      continue;
    }
    final unit = row.length > unitIdx ? row[unitIdx] : '';
    final factor = key == 'ph' || key == 'alkalinity'
        ? 1.0
        : zimsUnitFactor(unit);
    if (factor == null) {
      skipped.add('$label (${unit.trim()})');
      continue;
    }
    values[key] = parsed * factor;
    if (reportDate == null && dateIdx >= 0 && row.length > dateIdx) {
      final time = timeIdx >= 0 && row.length > timeIdx
          ? row[timeIdx].trim()
          : '';
      reportDate = DateTime.tryParse(
        time.isEmpty ? row[dateIdx].trim() : '${row[dateIdx].trim()} $time',
      );
    }
  }
  if (values.isEmpty) {
    throw const IcpImportException(IcpImportRejection.noValues);
  }
  return IcpImportResult(
    format: IcpImportFormat.zims,
    values: _inCatalogOrder(values),
    skipped: skipped,
    reportDate: reportDate,
  );
}

// --- Shared helpers ---------------------------------------------------------

/// Reorders [values] into catalog order (the order every screen lists
/// parameters in), so the preview reads like the app, not like the file.
Map<String, double> _inCatalogOrder(Map<String, double> values) => {
  for (final p in kReefParameters)
    if (values.containsKey(p.key)) p.key: values[p.key]!,
};

/// Parses a CSV cell number accepting `.` or `,` as the decimal separator
/// (the export's locale, not the app's — unambiguous because neither format
/// uses grouping). Returns null for non-numbers and non-finite values.
double? _parseCsvNumber(String raw) {
  var t = raw.trim();
  if (t.isEmpty || (t.contains('.') && t.contains(','))) return null;
  t = t.replaceAll(',', '.');
  final v = double.tryParse(t);
  return v != null && v.isFinite ? v : null;
}

/// Minimal RFC-4180-style CSV parser with a configurable [delimiter]:
/// double-quoted fields (with `""` escapes), CR/LF/CRLF row breaks, UTF-8 BOM
/// stripped. Blank lines are dropped.
List<List<String>> _parseCsv(String text, String delimiter) {
  final t = text.startsWith('﻿') ? text.substring(1) : text;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    // A row that is entirely empty is a blank line, not data.
    if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delimiter) {
      endField();
    } else if (c == '\r') {
      if (i + 1 < t.length && t[i + 1] == '\n') i++;
      endRow();
    } else if (c == '\n') {
      endRow();
    } else {
      field.write(c);
    }
  }
  endRow();
  return rows;
}
