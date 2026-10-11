import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/book_downloads.dart';

class _LoopbackBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LoopbackBinding();
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();
  late Uint8List bytes;
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    final data = await rootBundle.load(
      'assets/data/builtin_books/$downloadBookId.json',
    );
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  for (final scenario in bookDownloadCases) {
    testWidgets('book download $scenario', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('audit_A29_');
        try {
          await verifyBookDownload(scenario, bytes, databaseFactoryFfi, dir);
        } finally {
          await dir.delete(recursive: true);
        }
      });
    });
  }
  for (final locale in bookDownloadLocales) {
    for (final queued in [true, false]) {
      testWidgets(
        'book card $locale queued=$queued',
        (tester) => verifyBookCard(tester, locale, queued: queued),
      );
    }
  }
  for (final cancel in [true, false]) {
    testWidgets('book streamed HTTP cancel=$cancel', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('audit_A29_');
        try {
          await verifyBookHttp(bytes, databaseFactoryFfi, dir, cancel: cancel);
        } finally {
          await dir.delete(recursive: true);
        }
      });
    });
  }
}
