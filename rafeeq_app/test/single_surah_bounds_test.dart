import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/prefs_provider.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_data_provider.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_text_page.dart';
import 'package:rafeeq_app/features/sunan_suwar/presentation/single_surah_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late MushafData data;
  late List<MushafEdition> editions;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    db = await databaseFactory.openDatabase(
      File('assets/data/quran_local.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final repo = QuranRepository(db);
    data = MushafData(
      surahs: await repo.surahs(),
      surahStartPages: await repo.surahStartPages(),
      surahEndPages: await repo.surahEndPages(),
      juzStartPages: await repo.juzStartPages(),
      rubElHizbPages: const [],
      repo: repo,
    );
    final catalog =
        jsonDecode(File('assets/data/mushaf/editions.json').readAsStringSync())
            as Map;
    editions = [
      for (final e in catalog['editions'] as List)
        MushafEdition.fromJson(e as Map<String, dynamic>),
    ];
  });
  tearDownAll(() => db.close());

  for (final surah in [67, 19, 55, 56, 50]) {
    testWidgets('limited reader includes real final page of surah $surah', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            mushafDataProvider.overrideWith((ref) async => data),
            // Actual bundled catalogue, without unrelated disk-cache purging.
            mushafEditionsProvider.overrideWith((ref) async => editions),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('en')],
            startLocale: const Locale('en'),
            path: '.',
            assetLoader: const _Translations(),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: SingleSurahScreen(surahId: surah),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      final start = data.surahStartPages[surah]!;
      final end = data.surahEndPages[surah]!;
      final pages = tester.widget<PageView>(find.byType(PageView));
      expect(pages.childrenDelegate.estimatedChildCount, end - start + 1);
      pages.controller!.jumpToPage(end - start);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      final text = tester
          .widgetList<MushafTextPage>(find.byType(MushafTextPage))
          .singleWhere((page) => page.ayahs.last.pageNumber == end);
      final lastAyah = data.surahs.singleWhere((s) => s.id == surah).ayahsCount;
      expect(text.ayahs.every((a) => a.surahId == surah), isTrue);
      expect(text.ayahs.last.ayahNumber, lastAyah);
      expect(pages.controller!.page, (end - start).toDouble());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
