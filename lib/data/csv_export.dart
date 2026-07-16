import 'dart:isolate';

import 'package:intl/intl.dart';

import '../domain/parameter_catalog.dart';
import '../domain/units.dart';
import 'database.dart';
import 'export_share.dart';

/// Encodes measurements as an RFC 4180 CSV document (U3): comma-delimited,
/// CRLF line endings, quote-escaped fields, one row per measurement in the
/// order given (callers pass oldest first).
///
/// Format choices, made for spreadsheets and lab comparisons:
/// - header `taken_at,parameter,value,unit,note`;
/// - `parameter` is the stable catalog key (`alkalinity`, …) — the same
///   identifier the JSON backup uses — so files are comparable across app
///   languages;
/// - values are converted to the user's display units ([prefs] plus the
///   tracked parameter's stored unit, named in the `unit` column) at the
///   parameter's display precision, but always with `.` as the decimal
///   separator: locale decimals would fight the comma delimiter, and the
///   invariant form survives any spreadsheet's import dialog;
/// - timestamps are device-local `yyyy-MM-dd HH:mm:ss`, which spreadsheets
///   parse as a date without help.
String encodeReadingsCsv({
  required List<Reading> readings,
  required List<TrackedParameter> params,
  required UnitPrefs prefs,
}) {
  final presentations = <String, ParamPresentation>{
    for (final p in params)
      p.paramKey: presentationForKey(p.paramKey, p.unit, prefs),
  };
  final buf = StringBuffer('taken_at,parameter,value,unit,note\r\n');
  for (final r in readings) {
    // Readings outlive their tracked-parameter row (removing a parameter
    // keeps its history); fall back to the catalog's default unit for them.
    final pres = presentations.putIfAbsent(
      r.paramKey,
      () => presentationForKey(
        r.paramKey,
        kParameterByKey[r.paramKey]?.unit ?? '',
        prefs,
      ),
    );
    buf
      ..write(_timestamp(r.takenAt))
      ..write(',')
      ..write(_csvField(r.paramKey))
      ..write(',')
      ..write(pres.toDisplay(r.value).toStringAsFixed(pres.decimals))
      ..write(',')
      ..write(_csvField(pres.unitLabel))
      ..write(',')
      ..write(_csvField(r.note ?? ''))
      ..write('\r\n');
  }
  return buf.toString();
}

/// Exports every measurement of [tankId] as a CSV file handed to the OS share
/// sheet (staging/sweep lifecycle in [shareExportFile]). Returns false —
/// without opening the sheet — when the tank has no measurements. Encoding
/// runs off the UI isolate (T5): readings are the app's largest table.
Future<bool> exportReadingsCsv(
  AppDatabase db, {
  required int tankId,
  required String tankName,
  required UnitPrefs prefs,
}) async {
  final readings = await db.getReadingsForTank(tankId);
  if (readings.isEmpty) return false;
  final params = await db.getTrackedParameters(tankId);
  final csv = await Isolate.run(
    () => encodeReadingsCsv(readings: readings, params: params, prefs: prefs),
  );

  final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
  final slug = _fileSlug(tankName);
  await shareExportFile(
    fileName: '$kCsvExportPrefix$stamp${slug.isEmpty ? '' : '-$slug'}.csv',
    content: csv,
    mimeType: 'text/csv',
  );
  return true;
}

/// Quotes a field when it contains the delimiter, a quote, or a line break
/// (RFC 4180), doubling embedded quotes.
///
/// Fields starting with a spreadsheet formula-lead character (`=`, `+`, `-`,
/// `@`, tab, CR) are prefixed with an apostrophe first: the export is a share
/// artifact opened in spreadsheets, and a note like `=HYPERLINK(...)` would
/// otherwise execute as a live formula there (CSV formula injection).
String _csvField(String s) {
  var v = s;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  if (v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// Local timestamp as `yyyy-MM-dd HH:mm:ss`, locale-independent (no
/// [DateFormat], whose digits/symbols follow the app locale).
String _timestamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Sanitizes a tank name into a filename-safe suffix: runs of anything other
/// than letters/digits collapse to a single `-`, trimmed and capped so the
/// filename stays reasonable. May be empty (suffix is then omitted).
String _fileSlug(String name) {
  final s = name
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return s.length > 30 ? s.substring(0, 30) : s;
}
