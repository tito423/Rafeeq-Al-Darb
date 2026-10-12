import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/assistant_story_selection.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Database database;
  late Directory support;
  assistantStorySelectionTests(
    openRepository: () async {
      final asset = await rootBundle.load('assets/data/quran_local.db');
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      expect(
        sha256.convert(bytes).toString(),
        '3b27c8ab9c1a15a9db12e89c844680cf40aedb659168b6f3a3ae97b52a361679',
      );
      support = Directory.systemTemp.createTempSync('audit_A32_');
      final file = File('${support.path}/quran.sqlite');
      await file.writeAsBytes(bytes, flush: true);
      database = await openDatabase(file.path, readOnly: true);
      return QuranRepository(database);
    },
    closeRepository: () async {
      await database.close();
      expect(
        sha256
            .convert(await File('${support.path}/quran.sqlite').readAsBytes())
            .toString(),
        '3b27c8ab9c1a15a9db12e89c844680cf40aedb659168b6f3a3ae97b52a361679',
      );
      final actual = support.resolveSymbolicLinksSync();
      expect(
        p.isWithin(Directory.systemTemp.resolveSymbolicLinksSync(), actual),
        isTrue,
      );
      support.deleteSync(recursive: true);
    },
    screenshotReady: () async {
      debugPrint('A32_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
