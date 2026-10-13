import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/db/hadith_repository.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';
import 'package:rafeeq_app/features/library/presentation/screens/hadith_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const attributionDatabaseSha =
    '539dea009e718a12afe37052cd4fd6110f8347c1afc70b56184bbdd2428fb252';

class _Translations extends AssetLoader {
  const _Translations(this.document);
  final Map<String, dynamic> document;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      document;
}

void hadithAttributionTests({
  required Future<HadithRepository> Function() openRepository,
  required Future<void> Function() closeRepository,
  Future<void> Function(String)? screenshotReady,
}) {
  // Edition identifiers read from the publisher's printed cards/catalogue.
  const editions = {
    'tirmidhi': '9789960996738',
    'nasai': '9789960587608',
    'ibnmajah': '9789960988139',
  };
  final books = <String, HadithBook>{};
  final items = <String, HadithItem>{};
  setUpAll(() async {
    final repository = await openRepository();
    final originalBooks = await repository.books();
    for (final key in editions.keys) {
      final book = originalBooks.firstWhere((b) => b.key == key);
      books[key] = book;
      final item = (await repository.hadithByNumber(book.id, 1))!;
      expect(item.grade, 'Sahih');
      expect(item.grader, 'Darussalam');
      items[key] = item;
    }
  });
  tearDownAll(closeRepository);
  for (final key in editions.keys) {
    for (final language in ['en', 'ar', 'fr', 'es', 'pt', 'ru', 'ur']) {
      testWidgets('A44 actual $key grading attribution ($language)', (
        tester,
      ) async {
        final previousFonts = GoogleFonts.config.allowRuntimeFetching;
        GoogleFonts.config.allowRuntimeFetching = false;
        addTearDown(
          () => GoogleFonts.config.allowRuntimeFetching = previousFonts,
        );
        SharedPreferences.setMockInitialValues({'book_voice': 'device'});
        late Widget screen;
        await tester.runAsync(() async {
          await EasyLocalization.ensureInitialized();
          final translations =
              jsonDecode(
                    await rootBundle.loadString(
                      'assets/translations/$language.json',
                    ),
                  )
                  as Map<String, dynamic>;
          final theme = AppTheme.light();
          await GoogleFonts.pendingFonts();
          final font = FontLoader('AmiriQuran');
          font.addFont(rootBundle.load('assets/fonts/AmiriQuran-Regular.ttf'));
          await font.load();
          screen = ProviderScope(
            child: EasyLocalization(
              supportedLocales: [Locale(language)],
              startLocale: Locale(language),
              saveLocale: false,
              path: '.',
              assetLoader: _Translations(translations),
              child: Builder(
                builder: (context) => MaterialApp(
                  theme: theme,
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: HadithDetailScreen(
                    book: books[key]!,
                    chapterHadiths: [items[key]!],
                    initialIndex: 0,
                  ),
                ),
              ),
            ),
          );
        });
        try {
          await tester.pumpWidget(screen);
          await tester.pumpAndSettle();
          expect(find.byType(HadithDetailScreen), findsOneWidget);
          expect(
            tester
                .widget<SelectableText>(find.byType(SelectableText).first)
                .data,
            stripBidiControls(items[key]!.arabic),
          );
          final list = find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first;
          // The Dorar button has the same icon. A taller native viewport can
          // build both; select the actual grading line by its original verdict.
          final gradeLine = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data ?? '').startsWith(
                  language == 'ar' ? 'صحيح — ' : 'Sahih — ',
                ),
          );
          await tester.scrollUntilVisible(gradeLine, 300, scrollable: list);
          await tester.pumpAndSettle();
          final name = switch (language) {
            'ar' => 'زبير',
            'ur' => 'زبیر',
            'ru' => 'Зубайр',
            _ => 'Zubair',
          };
          final label = find.textContaining(name);
          expect(label, findsOneWidget);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(label).data!;
          expect(text, contains(language == 'ar' ? 'صحيح' : 'Sahih'));
          expect(text, contains(language == 'ar' ? '٢٠٠٧' : '2007'));
          expect(text, contains(editions[key]!));
          expect(items[key]!.grade, 'Sahih');
          expect(items[key]!.grader, 'Darussalam');
          expect(tester.takeException(), isNull);
          await screenshotReady?.call('${key}_$language');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      });
    }
  }
}
