import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafeeq_app/core/services/source_rules.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_encyclopedia.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_service.dart';
import 'package:rafeeq_app/features/dorar/presentation/dorar_screen.dart';

class _RealHttp extends HttpOverrides {}

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
}

void main() {
  _Binding();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('new Dorar search retains old in-flight gradings', (
    tester,
  ) async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = (await tester.runAsync(
        () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      ))!;
      final requests = <HttpRequest>[];
      final arrived = Completer<void>();
      await tester.runAsync(() async {
        server.listen((request) {
          requests.add(request);
          if (!arrived.isCompleted) arrived.complete();
        });
      });
      SourceRules.instance.reset();
      SourceRules.instance.apply(
        jsonEncode({
          'version': 99,
          'rules': {'dorar.api.url': 'http://127.0.0.1:${server.port}/lookup'},
        }),
      );
      addTearDown(() async {
        SourceRules.instance.reset();
        await server.close(force: true);
      });
      const oldQuery = 'إنما الأعمال';
      const newQuery = 'الراحمون';
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            startLocale: const Locale('en'),
            path: '.',
            assetLoader: const _Translations(),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const DorarScreen(initialQuery: oldQuery),
              ),
            ),
          ),
        );
        for (var i = 0; i < 10 && requests.isEmpty; i++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      for (var i = 0; i < 20 && requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(arrived.isCompleted, isTrue);
      expect(requests.single.uri.queryParameters['skey'], oldQuery);
      final field = tester.widget<TextField>(find.byType(TextField));
      await tester.enterText(find.byType(TextField), newQuery);
      field.onSubmitted!(newQuery);
      await tester.pump();
      expect(requests.length, 1, reason: 'busy drops the replacement search');
      final payload = File(
        'test/fixtures/dorar_innama_al_amal_2026-09-26.json',
      ).readAsStringSync();
      await tester.runAsync(() async {
        requests.single.response.headers.contentType = ContentType.json;
        requests.single.response.write(payload);
        await requests.single.response.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final cards = tester.widgetList<DorarGradingCard>(
        find.byType(DorarGradingCard),
      );
      final expected = parseDorar(
        (jsonDecode(payload) as Map<String, dynamic>)['ahadith']['result']
            as String,
      );
      expect(cards, isNotEmpty);
      expect(cards.first.h.text, expected.first.text);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        newQuery,
      );
      expect(requests.length, 1);
      expect(tester.takeException(), isNull);
      print(
        'AUDIT_DORAR_QUERY: replacement field=$newQuery; HTTP only=$oldQuery; '
        'rendered old grading cards=${cards.length}; no replacement request',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, _RealHttp());
  });

  test(
    'corrupt encyclopedia cache prevents repeated retry from refetching',
    () async {
      final dir = Directory.systemTemp.createTempSync(
        'rafeeq_dorar_cache_audit_',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = previous;
        dir.deleteSync(recursive: true);
      });
      final cache = File('${dir.path}/dorar/aqeeda.toc.html.gz');
      cache.parent.createSync(recursive: true);
      // A cache with a corrupted gzip signature. The existing cache remains
      // fresh after both retries, so the service never reaches its network try.
      final complete = gzip.encode(utf8.encode('<ul id="mtree"></ul>'));
      complete[0] = 0;
      cache.writeAsBytesSync(complete);
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          DorarEncyclopediaService.instance.toc('aqeeda'),
          throwsA(isA<FormatException>()),
        );
        expect(cache.readAsBytesSync(), complete);
      }
      print(
        'AUDIT_DORAR_CACHE: two actual toc attempts fail decoding fresh '
        'corrupted gzip before the network try; cache remains unchanged',
      );
    },
  );
}
