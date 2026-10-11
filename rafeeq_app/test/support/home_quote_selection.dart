import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';
import 'package:rafeeq_app/core/widgets/arabic_text.dart';
import 'package:rafeeq_app/features/quotes/data/quote_background_catalog.dart';
import 'package:rafeeq_app/features/quotes/data/quote_repository.dart';
import 'package:rafeeq_app/features/quotes/presentation/quote_card_screen.dart';
import 'package:rafeeq_app/features/quotes/presentation/widgets/home_quote_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

/// Actual mini-card, full-screen navigator and unmodified bundled quotations
/// in all seven languages. Only network backgrounds are replaced by their
/// existing offline fallback so selection tests do not depend on the network.
void homeQuoteSelectionTests({Future<void> Function()? screenshotReady}) {
  late QuoteLibrary library;
  final translations = <String, Map<String, dynamic>>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    library = parseQuoteLibrary(
      jsonDecode(await rootBundle.loadString('assets/data/quotes.json'))
          as Map<String, dynamic>,
    );
    for (final language in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      translations[language] = jsonDecode(await rootBundle.loadString(
          'assets/translations/$language.json')) as Map<String, dynamic>;
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(
    WidgetTester tester,
    String language, {
    QuoteLibrary? corpus,
    ProviderContainer? container,
  }) async {
    final scope =
        container ??
        ProviderContainer(
          overrides: [
            quoteLibraryProvider.overrideWith((ref) async => corpus ?? library),
            quoteBackgroundsProvider.overrideWith(
              (ref) async =>
                  const QuoteBackgroundSet(images: [], scrimArgb: 0xCC071626),
            ),
          ],
        );
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: EasyLocalization(
          supportedLocales: [Locale(language)],
          startLocale: Locale(language),
          path: '.',
          assetLoader: _Translations(translations),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const Scaffold(body: HomeQuoteCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> select(WidgetTester tester, int index) async {
    final home = tester.widget<PageView>(find.byType(PageView));
    home.controller!.jumpToPage(index);
    await tester.pumpAndSettle();
    final clicked = find.byType(ScriptText).hitTestable();
    expect(clicked, findsOneWidget);
    return tester.widget<ScriptText>(clicked).data;
  }

  Future<void> verifyOpened(
    WidgetTester tester,
    int index,
    String clicked,
  ) async {
    await tester.tap(find.byType(ScriptText).hitTestable());
    await tester.pumpAndSettle();
    final screen = tester.widget<QuoteCardScreen>(find.byType(QuoteCardScreen));
    expect(screen.initialIndex, index);
    expect(screen.quote.text, clicked);
    expect(screen.quotes![index].text, clicked);
    final fullPages = tester.widget<PageView>(
      find.descendant(
        of: find.byType(QuoteCardScreen),
        matching: find.byType(PageView),
      ),
    );
    expect(fullPages.controller!.page, index.toDouble());
    expect(
      find
          .descendant(
            of: find.byType(QuoteCardScreen),
            matching: find.byWidgetPredicate(
              (w) => w is ScriptText && w.data == stripBidiControls(clicked),
            ),
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }

  for (final language in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
    for (final index in [0, 1, 11]) {
      testWidgets(
        'A34 selected miniature $index opens matching full quote in $language',
        (tester) async {
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
          await show(tester, language);
          final clicked = await select(tester, index);
          await verifyOpened(tester, index, clicked);
          if (language == 'en' && index == 1 && screenshotReady != null) {
            await tester.runAsync(screenshotReady);
          }
          final screenContext = tester.element(find.byType(QuoteCardScreen));
          Navigator.of(screenContext).pop();
          await tester.pumpAndSettle();
          expect(
            tester.widget<PageView>(find.byType(PageView)).controller!.page,
            index.toDouble(),
          );
          expect(
            tester
                .widget<ScriptText>(find.byType(ScriptText).hitTestable())
                .data,
            clicked,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'A34 filtered earlier pick keeps the selected quote index valid',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
      final books = library.books
          .take(2)
          .map(
            (b) => QuoteBook(
              id: b.id,
              titleAr: b.titleAr,
              authorAr: b.authorAr,
              sourceLabel: b.sourceLabel,
              quotes: [b.quotes.first],
            ),
          )
          .toList();
      final corpus = StateProvider<QuoteLibrary>((ref) => QuoteLibrary(books));
      final scope = ProviderContainer(
        overrides: [
          quoteLibraryProvider.overrideWith((ref) async => ref.watch(corpus)),
          quoteBackgroundsProvider.overrideWith(
            (ref) async =>
                const QuoteBackgroundSet(images: [], scrimArgb: 0xCC071626),
          ),
        ],
      );
      await show(tester, 'en', container: scope);
      final first = await select(tester, 0);
      final clicked = await select(tester, 1);
      final invalid = books.indexWhere(
        (b) =>
            (b.quotes.first.text['en'] ?? b.quotes.first.text['ar']) == first,
      );
      expect(invalid, greaterThanOrEqualTo(0));
      final old = books[invalid];
      books[invalid] = QuoteBook(
        id: old.id,
        titleAr: old.titleAr,
        authorAr: old.authorAr,
        sourceLabel: old.sourceLabel,
        quotes: const [],
      );
      scope.read(corpus.notifier).state = QuoteLibrary([...books]);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScriptText>(find.byType(ScriptText).hitTestable()).data,
        clicked,
      );
      await verifyOpened(tester, 0, clicked);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
