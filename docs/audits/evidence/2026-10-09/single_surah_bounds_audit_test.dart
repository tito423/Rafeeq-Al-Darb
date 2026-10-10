import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rafeeq_app/core/config/prefs_provider.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_data_provider.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';
import 'package:rafeeq_app/features/sunan_suwar/presentation/single_surah_screen.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
    jsonDecode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late MushafData data;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    db = await databaseFactory.openDatabase(File('assets/data/quran_local.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true));
    final repo = QuranRepository(db);
    data = MushafData(surahs: await repo.surahs(),
      surahStartPages: await repo.surahStartPages(),
      surahEndPages: await repo.surahEndPages(),
      juzStartPages: await repo.juzStartPages(), rubElHizbPages: const [], repo: repo);
  });
  tearDownAll(() => db.close());
  testWidgets('audit: actual Mulk reader excludes canonical final page', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = jsonDecode(File('assets/data/mushaf/editions.json').readAsStringSync()) as Map;
    final editions = [for (final e in catalog['editions'] as List)
      MushafEdition.fromJson(e as Map<String, dynamic>)];
    await tester.pumpWidget(ProviderScope(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      mushafDataProvider.overrideWith((ref) async => data),
      // Keep the real catalogue while excluding unrelated disk-cache purge.
      mushafEditionsProvider.overrideWith((ref) async => editions),
    ], child: EasyLocalization(supportedLocales: const [Locale('en')],
      startLocale: const Locale('en'), path: '.', assetLoader: const _Translations(),
      child: Builder(builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales, locale: context.locale,
        home: const SingleSurahScreen(surahId: 67),
      )),
    )));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    final pages = tester.widget<PageView>(find.byType(PageView));
    expect(data.surahStartPages[67], 562);
    expect(data.surahEndPages[67], 564);
    expect(data.surahStartPages[68], 564);
    expect(pages.childrenDelegate.estimatedChildCount, 2);
    final omitted = (await tester.runAsync(() => data.repo.ayahsOfPage(564)))!
      .where((a) => a.surahId == 67).map((a) => a.ayahNumber).toList();
    expect(omitted, [27, 28, 29, 30]);
    print('AUDIT_SURAH_BOUNDS: production PageView count=2 pages562-563; '
      'canonical Mulk end=564; omitted verses=$omitted.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
