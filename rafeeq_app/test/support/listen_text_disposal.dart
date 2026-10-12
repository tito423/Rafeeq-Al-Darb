import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/db/hadith_repository.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/library/presentation/screens/hadith_detail_screen.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/listen_text_button.dart';
import 'package:rafeeq_app/features/tajweed/data/course_book.dart';
import 'package:shared_preferences/shared_preferences.dart';

const listenDisposalDatabaseSha =
    '539dea009e718a12afe37052cd4fd6110f8347c1afc70b56184bbdd2428fb252';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

/// Original database rows, real translations and actual widget disposal.
/// No voice is started: the TTS transport is controlled, not audible evidence.
void listenTextDisposalTests({
  required Future<HadithRepository> Function() openRepository,
  required Future<void> Function() closeRepository,
  Future<void> Function()? screenshotReady,
}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  final documents = <String, Map<String, dynamic>>{};
  final previousFonts = GoogleFonts.config.allowRuntimeFetching;
  late HadithBook book;
  late HadithItem hidden;
  late HadithItem visible;
  late String quran;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    await GoogleFonts.pendingFonts();
    final loader = FontLoader('AmiriQuran');
    loader.addFont(rootBundle.load('assets/fonts/AmiriQuran-Regular.ttf'));
    await loader.load();
    SharedPreferences.setMockInitialValues({'book_voice': 'device'});
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
    final repository = await openRepository();
    book = (await repository.books()).firstWhere((b) => b.key == 'tirmidhi');
    hidden = (await repository.hadithByNumber(book.id, 1))!;
    visible = (await repository.hadithByNumber(1, 1))!;
    expect(hidden.id, 20013);
    expect(visible.id, 1);
    expect(diacritisedShare(hidden.arabic), lessThan(80));
    expect(diacritisedShare(visible.arabic), greaterThanOrEqualTo(80));
    final asset = await rootBundle.load(
      'assets/data/tajweed/ghayat_al_murid.json.gz',
    );
    quran =
        CourseBook.fromGzip(
              asset.buffer.asUint8List(
                asset.offsetInBytes,
                asset.lengthInBytes,
              ),
            ).lessons[3].blocks[37].spans
            .firstWhere((span) => span.kind == 'q' && span.ref == '4:115')
            .text;
  });
  tearDownAll(() async {
    await closeRepository();
    GoogleFonts.config.allowRuntimeFetching = previousFonts;
  });
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      calls.add(call);
      return 1;
    });
  });
  tearDown(() {
    expect(calls.where((call) => call.method == 'speak'), isEmpty);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      null,
    );
  });

  Future<void> show(WidgetTester tester, String language, Widget child) async {
    await tester.pumpWidget(
      EasyLocalization(
        key: UniqueKey(),
        supportedLocales: [for (final language in languages) Locale(language)],
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
            home: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final pulse = find.descendant(
    of: find.byType(ListenTextButton),
    matching: find.byType(ScaleTransition),
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final language in languages) {
    testWidgets('A45 $language close actual hidden Tirmidhi1 listen button', (
      tester,
    ) async {
      await show(
        tester,
        language,
        HadithDetailScreen(
          book: book,
          chapterHadiths: [hidden],
          initialIndex: 0,
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(ListenTextButton),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListenTextButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListenTextButton),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      if (language == 'en' && screenshotReady != null) {
        await screenshotReady();
      }
      await close(tester);
    });

    for (final kind in ['empty', 'Quran only', 'visible']) {
      testWidgets('A45 $language close $kind button without starting voice', (
        tester,
      ) async {
        final text = switch (kind) {
          'empty' => '',
          'Quran only' => '﴿$quran﴾',
          _ => visible.arabic,
        };
        await show(
          tester,
          language,
          Scaffold(body: ListenTextButton(text: () => text)),
        );
        expect(pulse, kind == 'visible' ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  }

  testWidgets('A45 same button can become visible and hidden before closing', (
    tester,
  ) async {
    var text = '';
    late StateSetter update;
    await show(
      tester,
      'en',
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ListenTextButton(text: () => text);
          },
        ),
      ),
    );
    expect(pulse, findsNothing);
    update(() => text = visible.arabic);
    await tester.pumpAndSettle();
    expect(pulse, findsOneWidget);
    update(() => text = hidden.arabic);
    await tester.pumpAndSettle();
    expect(pulse, findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
