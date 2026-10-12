import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/hadith_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/listen_text_disposal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;
  listenTextDisposalTests(
    openRepository: () async {
      final file = File('assets/data/hadith.db');
      expect(
        sha256.convert(await file.readAsBytes()).toString(),
        listenDisposalDatabaseSha,
      );
      database = await databaseFactoryFfi.openDatabase(
        file.absolute.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      return HadithRepository(database);
    },
    closeRepository: () => database.close(),
  );
}
