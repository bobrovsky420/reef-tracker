import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../domain/icp_import.dart';

/// Prompts the user to pick an ICP report CSV and returns its text content.
/// Returns null when the user cancels the picker; throws [IcpImportException]
/// (`unreadable`) when the file can't be read as text.
Future<String?> pickIcpCsvContent() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.single;
  final bytes = picked.bytes;
  if (bytes != null) return _decodeCsvBytes(bytes);
  final path = picked.path;
  if (path != null) {
    try {
      return _decodeCsvBytes(await File(path).readAsBytes());
    } on FileSystemException catch (e) {
      throw IcpImportException(IcpImportRejection.unreadable, e.message);
    }
  }
  throw const IcpImportException(
    IcpImportRejection.unreadable,
    'could not read the selected file',
  );
}

/// UTF-8 with a Latin-1 fallback: Fauna Marin's portal serves Windows-encoded
/// CSVs in some locales. Every *mapped* column is ASCII either way — the
/// fallback only keeps free-text fields from failing the whole import.
String _decodeCsvBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}
