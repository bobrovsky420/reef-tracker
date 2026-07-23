// Host side of the guide screenshot harness. Writes each captured screenshot
// to build/guide_shots/<name>.png (raw device resolution); the publish step
// resizes them into docs/guide/img/.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outDir = Directory('build/guide_shots');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final file = File('${outDir.path}/$name.png');
          await file.writeAsBytes(bytes);
          stdout.writeln('saved ${file.path} (${bytes.length} bytes)');
          return true;
        },
  );
}
