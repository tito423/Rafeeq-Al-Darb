import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/tajweed/data/course_book.dart';
import 'package:rafeeq_app/features/tajweed/data/tajweed_example.dart';
import 'package:rafeeq_app/features/tajweed/presentation/widgets/listen_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const listenCardDatabaseSha =
    '3b27c8ab9c1a15a9db12e89c844680cf40aedb659168b6f3a3ae97b52a361679';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

void listenCardLayoutTests({
  required Future<QuranRepository> Function() openRepository,
  required Future<void> Function() closeRepository,
  Future<void> Function()? screenshotReady,
}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  final documents = <String, Map<String, dynamic>>{};
  final previousFonts = GoogleFonts.config.allowRuntimeFetching;
  late QuranRepository repository;
  late CourseSpan quote;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    await GoogleFonts.pendingFonts();
    for (final entry in {
      'AmiriQuran': 'assets/fonts/AmiriQuran-Regular.ttf',
      'KFGQPCHafs': 'assets/fonts/KFGQPC-HAFS-Uthmanic-Script-v18.ttf',
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(rootBundle.load(entry.value));
      await loader.load();
    }
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final language in languages) {
      documents[language] =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/translations/$language.json',
                ),
              )
              as Map<String, dynamic>;
    }
    repository = await openRepository();
    final source = await rootBundle.load(
      'assets/data/tajweed/ghayat_al_murid.json.gz',
    );
    final course = CourseBook.fromGzip(
      source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
    );
    quote = course.lessons[3].blocks[37].spans.firstWhere(
      (span) => span.kind == 'q' && span.ref == '4:115',
    );
    expect(quote.text, (await repository.ayah(4, 115))!.textUthmani);
  });
  tearDownAll(() async {
    await closeRepository();
    GoogleFonts.config.allowRuntimeFetching = previousFonts;
  });

  Future<void> verify(
    WidgetTester tester,
    String language,
    double scale, {
    bool emptyPhrase = false,
  }) async {
    if (tester.binding is! LiveTestWidgetsFlutterBinding) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quranRepositoryProvider.overrideWith((ref) async => repository),
          ],
          child: EasyLocalization(
            key: UniqueKey(),
            supportedLocales: [
              for (final language in languages) Locale(language),
            ],
            startLocale: Locale(language),
            saveLocale: false,
            path: '.',
            assetLoader: _Translations(documents),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.light(),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: IconButton(
                        key: const ValueKey('open-listen-sheet'),
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          // Same bounded sheet structure as CourseBookScreen._listen.
                          // The inner phone column also exercises328dp cards natively.
                          builder: (_) => SafeArea(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              heightFactor: 1,
                              child: SizedBox(
                                width: 360,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: ListenCard(
                                    example: TajweedExample(
                                      surah: 4,
                                      ayah: 115,
                                      phrase: emptyPhrase ? '' : quote.text,
                                      listenKey: 'tajweed.listen_example',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-listen-sheet')));
      await tester.pumpAndSettle();
      final button = find.byWidgetPredicate((widget) => widget is FilledButton);
      for (
        var frame = 0;
        frame < 100 && tester.widget<FilledButton>(button).onPressed == null;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      final card = tester.getRect(find.byType(ListenCard));
      expect(card.width, closeTo(328, 0.01));
      final actualButton = tester.getRect(button);
      expect(actualButton.left, greaterThanOrEqualTo(card.left));
      expect(actualButton.right, lessThanOrEqualTo(card.right));
      if (!emptyPhrase) {
        final phrase = find.text('﴿${quote.text}﴾');
        expect(phrase, findsOneWidget);
        final text = tester.widget<Text>(phrase);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
        final actualPhrase = tester.getRect(phrase);
        expect(actualPhrase.left, greaterThanOrEqualTo(card.left));
        expect(actualPhrase.right, lessThanOrEqualTo(card.right));
      }
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getRect(button).overlaps(Offset.zero & viewport), isTrue);
      expect(tester.takeException(), isNull);
      if (language == 'en' &&
          scale == 1 &&
          !emptyPhrase &&
          screenshotReady != null) {
        await screenshotReady();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }

  for (final language in languages) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'A43 $language original course quote fits at scale $scale',
        (tester) => verify(tester, language, scale),
      );
    }
  }
  for (final language in ['ar', 'en']) {
    testWidgets(
      'A43 $language empty phrase keeps listen button accessible',
      (tester) => verify(tester, language, 1, emptyPhrase: true),
    );
  }
}
