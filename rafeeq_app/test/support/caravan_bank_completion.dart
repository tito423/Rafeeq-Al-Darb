import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/caravan/data/caravan_world.dart';
import 'package:rafeeq_app/features/caravan/presentation/caravan_map.dart';
import 'package:rafeeq_app/features/caravan/presentation/caravan_painter.dart';
import 'package:rafeeq_app/features/caravan/presentation/caravan_screen.dart';
import 'package:rafeeq_app/features/quiz/data/history_quiz.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

class _HeldPaths extends PathProviderPlatform {
  _HeldPaths(this.ready);
  final Future<String> ready;
  @override
  Future<String?> getApplicationSupportPath() => ready;
}

class _OfflineRefresh extends HttpOverrides {
  _OfflineRefresh(this.port);
  final int port;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
}

void caravanBankCompletionTests({
  Future<void> Function()? screenshotReady,
  bool phoneViewport = true,
}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  final documents = <String, Map<String, dynamic>>{};
  final bankReady = Completer<String>();
  final previousPaths = PathProviderPlatform.instance;
  final previousHttp = HttpOverrides.current;
  final previousFonts = GoogleFonts.config.allowRuntimeFetching;
  late Directory support;
  late HttpServer proxy;
  late List<QuizQuestion> originalBank;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    await GoogleFonts.pendingFonts();
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
    final source =
        jsonDecode(await rootBundle.loadString(HistoryQuiz.asset))
            as Map<String, dynamic>;
    originalBank = [
      for (final question in source['questions'] as List)
        QuizQuestion.fromJson(question as Map<String, dynamic>),
    ];
    expect(originalBank, hasLength(500));
    support = Directory.systemTemp.createTempSync('audit_A42_');
    PathProviderPlatform.instance = _HeldPaths(bankReady.future);
    proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    proxy.listen((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    });
    HttpOverrides.global = _OfflineRefresh(proxy.port);
  });
  tearDownAll(() async {
    if (!bankReady.isCompleted) bankReady.complete(support.path);
    PathProviderPlatform.instance = previousPaths;
    HttpOverrides.global = previousHttp;
    GoogleFonts.config.allowRuntimeFetching = previousFonts;
    await proxy.close(force: true);
    final actual = support.resolveSymbolicLinksSync();
    expect(
      p.isWithin(Directory.systemTemp.resolveSymbolicLinksSync(), actual),
      isTrue,
    );
    support.deleteSync(recursive: true);
  });

  Future<void> show(WidgetTester tester, String language) async {
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
            home: const CaravanScreen(),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 15; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<CaravanWorld> play(WidgetTester tester) async {
    tester.widget<CaravanMap>(find.byType(CaravanMap)).onPlay(CaravanLeg.first);
    await tester.pump();
    return tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<CaravanPainter>()
        .single
        .w;
  }

  Future<void> gate(
    WidgetTester tester,
    CaravanWorld world, {
    bool realTicker = false,
  }) async {
    // The race uses the actual ticker throughout. Ready-bank controls shorten
    // the road with the real model, then let the ticker drive gate transitions.
    if (!realTicker) {
      while (world.time < 23.8) {
        world.step(0.05);
      }
    }
    for (
      var frame = 0;
      frame < 900 && world.phase != CaravanPhase.atGate;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(world.phase, CaravanPhase.atGate);
    await tester.pump();
  }

  void checkQuestion(WidgetTester tester, String language) {
    final candidates = originalBank
        .where((q) => CaravanLeg.first.gateIds.contains(q.id))
        .map((q) => q.localized(language))
        .toList();
    final visible = candidates
        .where((q) => find.text(q.question).evaluate().isNotEmpty)
        .toList();
    expect(visible, hasLength(1));
    for (final choice in visible.single.choices) {
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text(choice),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'A42 delayed bank and all localized gate controls',
    (tester) async {
      if (phoneViewport && tester.binding is LiveTestWidgetsFlutterBinding) {
        // Exercise a phone viewport without resizing the owner's emulator.
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      // Keep the cached HistoryQuiz future in one test zone, including controls.
      // Awaiting it from a later widget test retains the first FakeAsync zone.
      await show(tester, 'en');
      await play(tester);
      expect(bankReady.isCompleted, isFalse);
      await close(tester);
      await show(tester, 'en');
      final world = await play(tester);
      await gate(tester, world, realTicker: true);
      expect(find.byType(FilledButton), findsNothing);
      bankReady.complete(support.path);
      List<QuizQuestion>? loaded;
      unawaited(HistoryQuiz.all().then((bank) => loaded = bank));
      for (var frame = 0; frame < 100 && loaded == null; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(loaded, hasLength(500));
      await tester.pump();
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<CaravanPainter>()
            .single
            .w,
        same(world),
      );
      final lateTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .toList();
      final candidates = originalBank
          .where((q) => CaravanLeg.first.gateIds.contains(q.id))
          .map((q) => q.localized('en'))
          .toList();
      final lateQuestions = candidates
          .where((q) => lateTexts.contains(q.question))
          .toList();
      if (lateQuestions.isNotEmpty && screenshotReady != null) {
        if (phoneViewport) {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 450));
        await screenshotReady();
        if (phoneViewport) {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          await tester.pump();
        }
      }
      await close(tester);
      for (final language in languages) {
        await show(tester, language);
        final readyWorld = await play(tester);
        await gate(tester, readyWorld);
        checkQuestion(tester, language);
        debugPrint('A42_CONTROL_PASS $language');
        await close(tester);
      }
      await show(tester, 'en');
      final first = await play(tester);
      await gate(tester, first);
      checkQuestion(tester, 'en');
      await tester.tap(find.byType(IconButton).first);
      await tester.pump();
      expect(find.byType(CaravanMap), findsOneWidget);
      final replay = await play(tester);
      expect(replay, isNot(same(first)));
      await gate(tester, replay);
      checkQuestion(tester, 'en');
      debugPrint('A42_CONTROL_PASS map replay');
      await close(tester);
      // Require the captured late completion to repair the original journey,
      // after proving every ordinary control and localized bank entry still works.
      expect(lateQuestions, hasLength(1));
      for (final choice in lateQuestions.single.choices) {
        expect(lateTexts, contains(choice));
      }
      debugPrint('A42_CONTROL_PASS delayed bank');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
