// Host side of the screenshot harness. Writes each captured screenshot to
// store_assets/screenshots/<SHOT_DIR>/<name>.png. SHOT_DIR env selects the
// per-device output folder (e.g. phone, tablet7, tablet10).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final sub = Platform.environment['SHOT_DIR'] ?? 'phone';
  final outDir = Directory('store_assets/screenshots/$sub');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  await integrationDriver(
    onScreenshot: (String name, List<int> bytes,
        [Map<String, Object?>? args]) async {
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes);
      stdout.writeln('saved ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
