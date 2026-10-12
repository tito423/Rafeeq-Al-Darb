import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/assistant_story_selection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;
  assistantStorySelectionTests(
    openRepository: () async {
      final file = File('assets/data/quran_local.db');
      expect(
        sha256.convert(await file.readAsBytes()).toString(),
        '3b27c8ab9c1a15a9db12e89c844680cf40aedb659168b6f3a3ae97b52a361679',
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
