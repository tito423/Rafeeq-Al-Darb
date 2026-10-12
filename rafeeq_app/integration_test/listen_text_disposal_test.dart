import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/db/hadith_repository.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/listen_text_disposal.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Database database;
  late Directory support;
  listenTextDisposalTests(
    openRepository: () async {
      final asset = await rootBundle.load('assets/data/hadith.zip');
      final archive = ZipDecoder().decodeBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      final bytes = archive.findFile('hadith.db')!.content;
      expect(sha256.convert(bytes).toString(), listenDisposalDatabaseSha);
      support = Directory.systemTemp.createTempSync('audit_A45_');
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
        listenDisposalDatabaseSha,
      );
      final actual = support.resolveSymbolicLinksSync();
      expect(
        p.isWithin(Directory.systemTemp.resolveSymbolicLinksSync(), actual),
        isTrue,
      );
      support.deleteSync(recursive: true);
    },
    screenshotReady: () async {
      debugPrint('A45_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
