import 'package:flutter/material.dart';

import 'measurement_import_sources.dart';

/// ICP report entry. Lab formats are registry descriptors rather than a
/// screen-owned switch; callers continue to own the Pro entitlement gate.
Future<void> runIcpImportFlow(BuildContext context) =>
    runMeasurementImportSourceFlow(context, MeasurementImportGroup.icpReport);
