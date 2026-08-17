import 'package:flutter/material.dart';

import 'measurement_import_sources.dart';

/// App-history import entry. Source presentation, parsing and navigation are
/// contributed by [measurementImportSources].
Future<void> runMeasurementImportFlow(BuildContext context) =>
    runMeasurementImportSourceFlow(context, MeasurementImportGroup.appHistory);
