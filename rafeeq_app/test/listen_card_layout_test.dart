import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/listen_card_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;
  listenCardLayoutTests(
    openRepository: () async {
      final file = File('assets/data/quran_local.db');
      expect(
        sha256.convert(await file.readAsBytes()).toString(),
        listenCardDatabaseSha,
      );
      database = await databaseFactoryFfi.openDatabase(
        file.absolute.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      return QuranRepository(database);
    },
    closeRepository: () => database.close(),
  );
}
