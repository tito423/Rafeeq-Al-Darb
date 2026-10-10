import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/features/tajweed/data/course_book.dart';
import 'package:rafeeq_app/features/tajweed/data/tajweed_example.dart';
import 'package:rafeeq_app/features/tajweed/presentation/widgets/listen_card.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late QuranRepository repo;
  late CourseSpan quote;
  final results = <Map<String, Object?>>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final entry in {
      'AmiriQuran': 'assets/fonts/AmiriQuran-Regular.ttf',
      'KFGQPCHafs': 'assets/fonts/KFGQPC-HAFS-Uthmanic-Script-v18.ttf',
      'Cairo': 'assets/fonts/google_fonts/Cairo-Regular.ttf',
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(Future.value(ByteData.sublistView(File(entry.value).readAsBytesSync())));
      await loader.load();
    }
    db = await databaseFactory.openDatabase(File('assets/data/quran_local.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true));
    repo = QuranRepository(db);
    final course = CourseBook.fromGzip(File('assets/data/tajweed/ghayat_al_murid.json.gz').readAsBytesSync());
    quote = course.lessons[3].blocks[37].spans.firstWhere((s) => s.kind == 'q' && s.ref == '4:115');
    expect(quote.text, (await repo.ayah(4, 115))!.textUthmani);
  });
  tearDownAll(() async {
    await db.close();
    File('../docs/audits/evidence/2026-10-09/listen-card-layout.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(results));
  });
  for (final lang in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('actual course quotation overflows ListenCard: $lang scale$scale', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(overrides: [
          quranRepositoryProvider.overrideWith((ref) async => repo),
        ], child: EasyLocalization(supportedLocales: [Locale(lang)], startLocale: Locale(lang),
          path: '.', assetLoader: const _Translations(),
          child: Builder(builder: (context) => MaterialApp(
            theme: ThemeData(fontFamily: 'Cairo'),
            locale: context.locale, supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: MediaQuery(data: MediaQueryData(size: const Size(360,800),
              textScaler: TextScaler.linear(scale)), child: Scaffold(body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenCard(example: TajweedExample(surah: 4, ayah: 115,
                  phrase: quote.text, listenKey: 'tajweed.listen_example'))),
            ))),
          )),
        )));
        await tester.pump();
        final errors = <String>[];
        Object? error;
        while ((error = tester.takeException()) != null) { errors.add(error.toString()); }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        while ((error = tester.takeException()) != null) { errors.add(error.toString()); }
        expect(errors.any((e) => e.contains('RenderFlex overflowed') && e.contains('pixels')), isTrue);
        expect(errors.every((e) => e.contains('RenderFlex overflowed')), isTrue);
        final buttonRect = tester.getRect(find.byWidgetPredicate((w) => w is FilledButton));
        final buttonOutsideViewport = !buttonRect.overlaps(const Rect.fromLTWH(0, 0, 360, 800));
        if (lang == 'en') {
          expect(buttonOutsideViewport, isTrue,
            reason: 'actual English play button is beyond the viewport');
        }
        results.add({'lang':lang, 'scale':scale, 'screenDp':[360,800], 'cardWidthDp':328,
          'source':'ghayat_al_murid lesson3 block37 q span 4:115', 'errors':errors,
          'buttonRect':[buttonRect.left,buttonRect.top,buttonRect.right,buttonRect.bottom],
          'buttonOutsideViewport':buttonOutsideViewport,
          'fonts':'real bundled Cairo/AmiriQuran/KFGQPCHafs; no Ahem measurement'});
        print('AUDIT_LISTEN_LAYOUT: $lang scale$scale ${errors.join(' | ')}');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
