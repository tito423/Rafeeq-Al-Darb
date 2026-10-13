import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/adhan_recompute_entry.dart';
import 'package:rafeeq_app/core/db/hadith_repository.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/hadith_attribution_metadata.dart';
import '../test/support/hadith_attribution_ui.dart';

@pragma('vm:entry-point')
Future<void> adhanRecomputeMain() => runAdhanRecompute();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  late Database database;
  late Directory support;
  hadithAttributionMetadataTests();
  hadithAttributionTests(
    openRepository: () async {
      final asset = await rootBundle.load('assets/data/hadith.zip');
      final archive = ZipDecoder().decodeBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      final bytes = archive.findFile('hadith.db')!.content;
      expect(sha256.convert(bytes).toString(), attributionDatabaseSha);
      support = await Directory.systemTemp.createTemp('audit_A44_');
      final file = File('${support.path}/hadith.sqlite');
      await file.writeAsBytes(bytes, flush: true);
      database = await openDatabase(file.path, readOnly: true);
      return HadithRepository(database);
    },
    closeRepository: () async {
      await database.close();
      expect(
        sha256
            .convert(await File('${support.path}/hadith.sqlite').readAsBytes())
            .toString(),
        attributionDatabaseSha,
      );
      final actual = support.resolveSymbolicLinksSync();
      expect(
        p.isWithin(Directory.systemTemp.resolveSymbolicLinksSync(), actual),
        isTrue,
      );
      support.deleteSync(recursive: true);
    },
    screenshotReady: (label) async {
      debugPrint('A44_SCREENSHOT_READY_$label');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
