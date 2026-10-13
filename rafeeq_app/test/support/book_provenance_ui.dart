import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/library/presentation/screens/book_text_reader_screen.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/book_provenance_sheet.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/book_provenance_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ghidha_edition_excerpt.dart';

class _Translations extends AssetLoader {
  const _Translations(this.document);
  final Map<String, dynamic> document;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      document;
}

void bookProvenanceTests({Future<void> Function(String)? screenshotReady}) {
  final book = libraryBookCatalog.firstWhere((b) => b.id == 'ghidha_al_albab');
  final original = jsonDecode(ghidhaEditionExcerpt) as Map<String, dynamic>;
  final card = (original['meta'] as Map)['editionCard'] as String;
  test(
    'A28 retains the exact original edition card for plain and gzip files',
    () {
      final bytes = utf8.encode(ghidhaEditionExcerpt);
      for (final data in [bytes, gzip.encode(bytes)]) {
        final doc = BookText.fromBytes(data);
        expect(doc.meta.editionCard, card);
        expect(doc.meta.shamelaUrl, 'https://shamela.ws/book/25791');
        expect(
          doc.pages.single.paras.first.text,
          ((((original['pages'] as List).first as Map)['paras'] as List).first
              as Map)['t'],
        );
        expect(bookProvenanceLabel(book, doc.meta), 'المكتبة الشاملة');
      }
    },
  );
  test('A28 older and malformed optional metadata remain readable', () {
    for (final value in [null, 42, [], {}, '']) {
      final json = jsonDecode(ghidhaEditionExcerpt) as Map<String, dynamic>;
      (json['meta'] as Map)['editionCard'] = value;
      final doc = BookText.fromJson(json);
      expect(doc.meta.editionCard, isEmpty);
      expect(doc.pages, hasLength(1));
    }
    final json = jsonDecode(ghidhaEditionExcerpt) as Map<String, dynamic>;
    (json['meta'] as Map).remove('editionCard');
    expect(BookText.fromJson(json).meta.editionCard, isEmpty);
  });
  test(
    'A28 preserves richer catalogue attribution and metadata-free fallback',
    () {
      final doc = BookText.fromJson(original);
      final rich = libraryBookCatalog.firstWhere(
        (b) => b.textEdition != null && b.textEdition!.sourceLabel.length > 30,
      );
      expect(
        bookProvenanceLabel(rich, doc.meta),
        rich.textEdition!.sourceLabel,
      );
      expect(bookProvenanceLabel(book, null), book.textEdition!.sourceLabel);
    },
  );
  for (final language in ['en', 'ar', 'fr', 'es', 'pt', 'ru', 'ur']) {
    testWidgets(
      'A28 actual reader exposes original publisher and edition ($language)',
      (tester) async {
        final previousFonts = GoogleFonts.config.allowRuntimeFetching;
        GoogleFonts.config.allowRuntimeFetching = false;
        addTearDown(
          () => GoogleFonts.config.allowRuntimeFetching = previousFonts,
        );
        SharedPreferences.setMockInitialValues({});
        late Directory directory;
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
          directory = await Directory.systemTemp.createTemp('rafeeq_a28_');
          final file = File('${directory.path}/ghidha_al_albab.json');
          await file.writeAsBytes(
            gzip.encode(utf8.encode(ghidhaEditionExcerpt)),
          );
          expect((await BookText.fromFile(file.path)).meta.editionCard, card);
          final theme = AppTheme.light();
          await GoogleFonts.pendingFonts();
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
                  home: BookTextReaderScreen(book: book, path: file.path),
                ),
              ),
            ),
          );
          await tester.pumpWidget(screen);
          await Future<void>.delayed(const Duration(seconds: 1));
        });
        addTearDown(() async {
          // Delete only this test's freshly-created private temporary directory.
          await directory.delete(recursive: true);
        });
        for (var attempt = 0; attempt < 12; attempt++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(BookProvenanceStrip).evaluate().isNotEmpty) break;
        }
        expect(find.byType(BookProvenanceStrip), findsOneWidget);
        expect(
          tester
              .widget<BookProvenanceStrip>(find.byType(BookProvenanceStrip))
              .meta!
              .editionCard,
          card,
        );
        await tester.tap(find.byType(BookProvenanceStrip));
        await tester.pump(const Duration(milliseconds: 500));
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(
            of: sheet,
            matching: find.textContaining('مؤسسة قرطبة'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.textContaining('الثانية')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text(card)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sheet,
            matching: find.text('library.text_source'.tr()),
          ),
          findsOneWidget,
        );
        final link = find.descendant(
          of: sheet,
          matching: find.text('library.text_open_shamela'.tr()),
        );
        await tester.ensureVisible(link);
        await tester.pump(const Duration(milliseconds: 500));
        expect(link, findsOneWidget);
        expect(tester.takeException(), isNull);
        await screenshotReady?.call(language);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
