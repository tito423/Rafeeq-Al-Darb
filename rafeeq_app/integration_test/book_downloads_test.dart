import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/book_downloads.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('audit_A29.');
  late Uint8List bytes;
  late Directory cache;
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    cache = await getTemporaryDirectory();
    final data = await rootBundle.load(
      'assets/data/builtin_books/$downloadBookId.json',
    );
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  for (final scenario in bookDownloadCases) {
    testWidgets('Android book download $scenario', (tester) async {
      final dir = await cache.createTemp('audit_A29_');
      try {
        await verifyBookDownload(scenario, bytes, databaseFactory, dir);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  }
  for (final locale in bookDownloadLocales) {
    for (final queued in [true, false]) {
      testWidgets(
        'Android book card $locale queued=$queued',
          (tester) => verifyBookCard(tester, locale, queued: queued,
            capture: locale == 'en' && !queued ? () async {
              debugPrint('A29_SCREENSHOT_READY');
              await Future<void>.delayed(const Duration(seconds: 4));
            } : null),
      );
    }
  }
  for (final cancel in [true, false]) {
    testWidgets('Android book streamed HTTP cancel=$cancel', (tester) async {
      final dir = await cache.createTemp('audit_A29_');
      try {
        await verifyBookHttp(bytes, databaseFactory, dir, cancel: cancel);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  }
}
