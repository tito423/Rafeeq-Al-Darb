import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/core/widgets/arabic_text.dart';
import 'package:rafeeq_app/features/quotes/data/quote_background_catalog.dart';
import 'package:rafeeq_app/features/quotes/data/quote_repository.dart';
import 'package:rafeeq_app/features/quotes/presentation/quote_card_screen.dart';
import 'package:rafeeq_app/features/quotes/presentation/widgets/home_quote_card.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUpAll(EasyLocalization.ensureInitialized);
  testWidgets('audit: tapping the second miniature opens the first quote', (tester) async {
    final library = parseQuoteLibrary(
      jsonDecode(File('assets/data/quotes.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        quoteLibraryProvider.overrideWith((ref) async => library),
        quoteBackgroundsProvider.overrideWith((ref) async =>
            const QuoteBackgroundSet(images: [], scrimArgb: 0xCC071626)),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('en')], startLocale: const Locale('en'),
        path: '.', assetLoader: const _Translations(),
        child: Builder(builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales, locale: context.locale,
          home: const Scaffold(body: HomeQuoteCard()),
        )),
      ),
    ));
    await tester.pumpAndSettle();
    final homePages = tester.widget<PageView>(find.byType(PageView));
    homePages.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    final clicked = find.byType(ScriptText).hitTestable();
    expect(clicked, findsOneWidget);
    final clickedText = tester.widget<ScriptText>(clicked).data;
    await tester.tap(clicked);
    await tester.pumpAndSettle();
    final screen = tester.widget<QuoteCardScreen>(find.byType(QuoteCardScreen));
    expect(screen.initialIndex, 0);
    expect(screen.quotes![1].text, clickedText);
    expect(identical(library.at(0, 0), library.at(0, 0)), isFalse);
    print('AUDIT_QUOTE_SELECTION: tapped page=1; opened initialIndex=${screen.initialIndex}; '
        'fresh Quote instances do not compare equal; route selects index 0.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
