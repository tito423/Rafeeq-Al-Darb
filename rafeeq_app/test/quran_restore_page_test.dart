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
import 'package:rafeeq_app/features/quran/presentation/screens/quran_screen.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf/page_overlay.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf_text_page.dart';
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'quran_last_page': 541,
      'quran_reader_mode': 'text',
      'quran_text_layout_v1': 'cards',
    });
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
  });
  tearDownAll(() => db.close());
  testWidgets(
    'restoring page541 moves existing controller and content then persists the next page',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final catalog =
          jsonDecode(
                File('assets/data/mushaf/editions.json').readAsStringSync(),
              )
              as Map;
      final editions = [
        for (final e in catalog['editions'] as List)
          MushafEdition.fromJson(e as Map<String, dynamic>),
      ];
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          mushafDataProvider.overrideWith((ref) => data),
          // Keep the real catalogue while excluding unrelated disk-cache purge.
          mushafEditionsProvider.overrideWith((ref) async => editions),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
                home: const QuranScreen(),
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
      // The restore jumps in a post-frame callback; lay out that viewport
      // before waiting for its real SQLite query, then paint its result.
      await tester.pump();
      final expected = (await tester.runAsync(
        () => data.repo.ayahsOfPage(541),
      ))!;
      await tester.pump();
      final pages = tester.widget<PageView>(find.byType(PageView));
      final badge = tester.widget<PageNumberBadge>(
        find.byType(PageNumberBadge).first,
      );
      final text = tester.widget<MushafTextPage>(
        find.byType(MushafTextPage).first,
      );
      expect(badge.page, 541);
      expect(pages.controller!.page, 540);
      expect(text.ayahs.first.surahId, 57);
      expect(text.ayahs.map((a) => a.id), expected.map((a) => a.id));
      pages.controller!.jumpToPage(541);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      expect(
        tester.widget<PageNumberBadge>(find.byType(PageNumberBadge).first).page,
        542,
      );
      expect(prefs.getInt('quran_last_page'), 542);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
