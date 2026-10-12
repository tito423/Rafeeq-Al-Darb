import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafeeq_app/core/services/source_rules.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_service.dart';
import 'package:rafeeq_app/features/dorar/presentation/dorar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dorarOriginalFixtureSha =
    '3e4652040587f0006e5cac6ed84e69ea97337d4d6156179008e3bd3912e33975';

class _Translations extends AssetLoader {
  const _Translations(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      documents[locale.languageCode]!;
}

/// Actual screen, singleton service, parser and loopback HTTP. Response blocks
/// are byte-for-byte selections from the original Dorar fixture, not new text.
void dorarSearchLifetimeTests({
  required Future<List<int>> Function() loadFixture,
  Future<void> Function()? screenshotReady,
}) {
  const languages = ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'];
  const oldQuery = 'إنما الأعمال';
  const newQuery = 'النيات';
  final documents = <String, Map<String, dynamic>>{};
  final originalRuntimeFonts = GoogleFonts.config.allowRuntimeFetching;
  late List<String> blocks;

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
    final bytes = await loadFixture();
    expect(sha256.convert(bytes).toString(), dorarOriginalFixtureSha);
    final source = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final ahadith = source['ahadith'] as Map<String, dynamic>;
    final html = ahadith['result'] as String;
    blocks = [
      for (final match
          in SourceRules.instance.re('dorar.api.block').allMatches(html))
        match.group(0)!,
    ];
    expect(blocks, hasLength(15));
    expect(parseDorar(blocks[0]), hasLength(1));
    expect(parseDorar(blocks[1]), hasLength(1));
  });
  tearDownAll(
    () => GoogleFonts.config.allowRuntimeFetching = originalRuntimeFonts,
  );

  String response(List<int> indices) => jsonEncode({
    'ahadith': {
      'result': [for (final index in indices) blocks[index]].join(),
    },
  });
  String identity(DorarHadith h) => '${h.text}|${h.muhaddith}|${h.page}';
  List<String> visibleCards(WidgetTester tester) => [
    for (final card in tester.widgetList<DorarGradingCard>(
      find.byType(DorarGradingCard),
    ))
      identity(card.h),
  ];
  String expected(int index) => identity(parseDorar(blocks[index]).single);

  Future<void> until(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 200 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      ready(),
      true,
      reason: 'Actual HTTP or visible search state did not arrive',
    );
    await tester.pump();
  }

  Future<void> withScreen(
    WidgetTester tester,
    String language,
    Future<void> Function(List<HttpRequest> requests) check,
  ) async {
    await tester.runAsync(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <HttpRequest>[];
      server.listen(requests.add);
      SourceRules.instance.reset();
      SourceRules.instance.apply(
        jsonEncode({
          'version': 99,
          'rules': {'dorar.api.url': 'http://127.0.0.1:${server.port}/lookup'},
        }),
      );
      try {
        await tester.pumpWidget(
          EasyLocalization(
            key: UniqueKey(),
            supportedLocales: [for (final code in languages) Locale(code)],
            startLocale: Locale(language),
            saveLocale: false,
            path: '.',
            assetLoader: _Translations(documents),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.light(),
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const DorarScreen(initialQuery: oldQuery),
              ),
            ),
          ),
        );
        await until(tester, () => requests.isNotEmpty);
        expect(requests.single.uri.queryParameters, {
          'skey': oldQuery,
          'page': '1',
        });
        await check(requests);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await server.close(force: true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        SourceRules.instance.reset();
      }
    });
  }

  Future<void> submit(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  Future<void> reply(
    HttpRequest request,
    List<int> indices, {
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(response(indices));
    await request.response.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Finder moreButton() => find.ancestor(
    of: find.text('dorar.more'.tr()),
    matching: find.byWidgetPredicate((widget) => widget is TextButton),
  );

  Future<void> more(WidgetTester tester) async {
    final button = moreButton();
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button.hitTestable());
    await tester.pump();
  }

  Future<void> replace(
    WidgetTester tester,
    List<HttpRequest> requests, {
    String query = newQuery,
  }) async {
    await submit(tester, query);
    await until(tester, () => requests.length == 2);
    expect(requests[1].uri.queryParameters, {'skey': query, 'page': '1'});
  }

  for (final language in languages) {
    testWidgets(
      'A38 $language replacement starts before old response and keeps its own cards',
      (tester) async {
        await withScreen(tester, language, (requests) async {
          await replace(tester, requests);
          await reply(requests[1], [0]);
          await until(tester, () => visibleCards(tester).isNotEmpty);
          await reply(requests[0], [1]);
          await tester.pumpAndSettle();
          expect(visibleCards(tester), [expected(0)]);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            newQuery,
          );
          expect(find.byType(LinearProgressIndicator), findsNothing);
          if (language == 'en' && screenshotReady != null) {
            await screenshotReady();
          }
          await more(tester);
          await until(tester, () => requests.length == 3);
          expect(requests.last.uri.queryParameters, {
            'skey': newQuery,
            'page': '2',
          });
          await reply(requests.last, [1]);
          await until(
            tester,
            () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
          );
          expect(visibleCards(tester), containsAll([expected(0), expected(1)]));
        });
      },
    );
  }

  for (final status in [200, 503]) {
    testWidgets(
      'A38 stale empty or failed status $status preserves current pending request',
      (tester) async {
        await withScreen(tester, 'en', (requests) async {
          await replace(tester, requests);
          await reply(requests[0], [], status: status);
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await tester.pump();
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(find.text('dorar.failed'.tr()), findsNothing);
          expect(find.text('dorar.none'.tr()), findsNothing);
          await reply(requests[1], [0]);
          await until(tester, () => visibleCards(tester).isNotEmpty);
          expect(visibleCards(tester), [expected(0)]);
          expect(moreButton(), findsOneWidget);
        });
      },
    );
  }

  testWidgets(
    'A38 late old success cannot resurrect cards after current failure',
    (tester) async {
      await withScreen(tester, 'en', (requests) async {
        await replace(tester, requests);
        await reply(requests[1], [], status: 503);
        await until(
          tester,
          () => find.text('dorar.failed'.tr()).evaluate().isNotEmpty,
        );
        await reply(requests[0], [1]);
        await tester.pumpAndSettle();
        expect(visibleCards(tester), isEmpty);
        expect(find.text('dorar.failed'.tr()), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    },
  );

  testWidgets('A38 a pending next page is superseded by a new first page', (
    tester,
  ) async {
    await withScreen(tester, 'en', (requests) async {
      await reply(requests[0], [0]);
      await until(tester, () => visibleCards(tester).isNotEmpty);
      await more(tester);
      await until(tester, () => requests.length == 2);
      expect(requests[1].uri.queryParameters, {'skey': oldQuery, 'page': '2'});
      await submit(tester, newQuery);
      await until(tester, () => requests.length == 3);
      expect(requests[2].uri.queryParameters, {'skey': newQuery, 'page': '1'});
      await reply(requests[2], [1]);
      await until(tester, () => visibleCards(tester).isNotEmpty);
      await reply(requests[1], [0]);
      await tester.pumpAndSettle();
      expect(visibleCards(tester), [expected(1)]);
    });
  });

  testWidgets(
    'A38 ordinary pagination retry keeps page and removes duplicates at end',
    (tester) async {
      await withScreen(tester, 'en', (requests) async {
        await reply(requests[0], [0]);
        await until(tester, () => visibleCards(tester).isNotEmpty);
        await more(tester);
        await until(tester, () => requests.length == 2);
        await reply(requests[1], [], status: 503);
        await until(
          tester,
          () => find.text('dorar.failed'.tr()).evaluate().isNotEmpty,
        );
        await more(tester);
        await until(tester, () => requests.length == 3);
        expect(requests.last.uri.queryParameters, {
          'skey': oldQuery,
          'page': '2',
        });
        await reply(requests.last, [0, 1]);
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('dorar.failed'.tr()), findsNothing);
        expect(visibleCards(tester), containsAll([expected(0), expected(1)]));
        await more(tester);
        await until(tester, () => requests.length == 4);
        expect(requests.last.uri.queryParameters['page'], '3');
        await reply(requests.last, [0, 1]);
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(moreButton(), findsNothing);
        expect(visibleCards(tester).toSet(), {expected(0), expected(1)});
      });
    },
  );

  testWidgets('A38 short input does not replace a valid pending search', (
    tester,
  ) async {
    await withScreen(tester, 'en', (requests) async {
      await submit(tester, 'x');
      await reply(requests[0], [0]);
      await until(tester, () => visibleCards(tester).isNotEmpty);
      expect(requests, hasLength(1));
      expect(visibleCards(tester), [expected(0)]);
    });
  });

  testWidgets('A38 closing with pending HTTP never updates a disposed screen', (
    tester,
  ) async {
    await withScreen(tester, 'en', (requests) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await reply(requests[0], [0]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
      expect(find.byType(DorarScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'A38 restarting the same query still creates a new search owner',
    (tester) async {
      await withScreen(tester, 'en', (requests) async {
        await replace(tester, requests, query: oldQuery);
        await reply(requests[1], [0]);
        await until(tester, () => visibleCards(tester).isNotEmpty);
        await reply(requests[0], [1]);
        await tester.pumpAndSettle();
        expect(visibleCards(tester), [expected(0)]);
      });
    },
  );
}
