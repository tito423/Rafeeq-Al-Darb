import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_encyclopedia.dart';
import 'package:rafeeq_app/features/dorar/presentation/dorar_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dorarCacheFixtures = {
  'dorar_enc_aqeeda.html.gz':
      '41c535195c295f198ee2fa3168501f142db809133cca4b4264bc00c825af73a7',
  'dorar_aq10.html.gz':
      '547d1a42ca0394a531de08120645ea1cf9aaa3d3b7e3bbe66769380c5c5b1248',
};

class _Translations extends AssetLoader {
  const _Translations(this.document);
  final Map<String, dynamic> document;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      document;
}

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final String directory;
  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

/// Inject an interrupted write into real files, including a partially written
/// destination. Cache reads and the HTTP transport remain real.
final class _PartialWrites extends IOOverrides {
  _PartialWrites(this.root);
  final String root;
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return p.isWithin(root, p.absolute(path)) ? _PartialFile(file) : file;
  }
}

class _PartialFile implements File {
  _PartialFile(this.file);
  final File file;
  @override
  String get path => file.path;
  @override
  Directory get parent => file.parent;
  @override
  bool existsSync() => file.existsSync();
  @override
  DateTime lastModifiedSync() => file.lastModifiedSync();
  @override
  Future<FileStat> stat() => file.stat();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await file.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2), flush: true);
    throw FileSystemException('Injected interrupted cache write', path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected test file operation ${invocation.memberName}',
  );
}

void dorarCacheRecoveryTests({
  required Future<List<int>> Function(String name) loadFixture,
  Future<void> Function()? screenshotReady,
}) {
  late List<int> tocBytes;
  late String tocHtml;
  late List<int> sectionBytes;
  late String sectionHtml;
  late Map<String, dynamic> translations;
  final originalRuntimeFonts = GoogleFonts.config.allowRuntimeFetching;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppTheme.light();
    await GoogleFonts.pendingFonts();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations =
        jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
            as Map<String, dynamic>;
    tocBytes = await loadFixture('dorar_enc_aqeeda.html.gz');
    sectionBytes = await loadFixture('dorar_aq10.html.gz');
    expect(
      sha256.convert(tocBytes).toString(),
      dorarCacheFixtures['dorar_enc_aqeeda.html.gz'],
    );
    expect(
      sha256.convert(sectionBytes).toString(),
      dorarCacheFixtures['dorar_aq10.html.gz'],
    );
    tocHtml = utf8.decode(gzip.decode(tocBytes));
    sectionHtml = utf8.decode(gzip.decode(sectionBytes));
  });
  tearDownAll(
    () => GoogleFonts.config.allowRuntimeFetching = originalRuntimeFonts,
  );

  int count(List<DorarTocNode> nodes) => nodes.fold(
    0,
    (total, node) => total + (node.isSection ? 1 : 0) + count(node.children),
  );
  void checkToc(List<DorarTocNode> nodes) {
    expect(count(nodes), 1469);
    expect(nodes.first.id, 1);
    expect(nodes.first.title, parseDorarToc(tocHtml, 'aqeeda').first.title);
  }

  Future<void> until(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 200 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      ready(),
      true,
      reason: 'The actual recovered contents did not render',
    );
    await tester.pumpAndSettle();
  }

  const cases = [
    'fresh corrupt header',
    'fresh truncated gzip',
    'fresh malformed UTF8',
    'missing cache fetches',
    'fresh valid cache stays offline',
    'stale valid cache survives network failure',
    'corrupt cache retries after network failure',
    'interrupted write preserves stale valid cache',
    'corrupt section recovers unchanged source',
  ];
  for (final scenario in cases) {
    testWidgets('A39 $scenario', (tester) async {
      await tester.runAsync(() async {
        final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
        final root = await Directory(tempRoot).createTemp('audit_A39_');
        final previousPaths = PathProviderPlatform.instance;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final requested = <Uri>[];
        final statuses =
            scenario == 'corrupt cache retries after network failure'
            ? [503, 200]
            : [
                scenario == 'stale valid cache survives network failure'
                    ? 503
                    : 200,
              ];
        var arrivals = 0;
        server.listen((request) async {
          final status =
              statuses[arrivals < statuses.length
                  ? arrivals
                  : statuses.length - 1];
          arrivals++;
          request.response.statusCode = status;
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            request.uri.path.endsWith('/10') ? sectionHtml : tocHtml,
          );
          await request.response.close();
        });
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final original = options.uri;
              requested.add(original);
              expect(original.scheme, 'https');
              expect(original.host, 'dorar.net');
              options.path = Uri(
                scheme: 'http',
                host: '127.0.0.1',
                port: server.port,
                path: original.path,
                query: original.hasQuery ? original.query : null,
              ).toString();
              handler.next(options);
            },
          ),
        );
        final api = DorarEncyclopediaService.forTesting(
          dio: dio,
          supportDirectory: root,
        );
        final section = scenario == 'corrupt section recovers unchanged source';
        final cache = File(
          p.join(
            root.path,
            'dorar',
            section ? 'aqeeda.10.html.gz' : 'aqeeda.toc.html.gz',
          ),
        );
        try {
          await cache.parent.create(recursive: true);
          if (scenario != 'missing cache fetches') {
            var seed = List<int>.from(section ? sectionBytes : tocBytes);
            if (scenario == 'fresh corrupt header' ||
                scenario == 'corrupt cache retries after network failure' ||
                section) {
              seed[0] = 0;
            } else if (scenario == 'fresh truncated gzip') {
              seed = seed.sublist(0, seed.length ~/ 2);
            } else if (scenario == 'fresh malformed UTF8') {
              final html = utf8.encode(tocHtml);
              html[0] = 0xff;
              seed = gzip.encode(html);
            }
            await cache.writeAsBytes(seed, flush: true);
            if (scenario.startsWith('stale valid') ||
                scenario.startsWith('interrupted write')) {
              await cache.setLastModified(
                DateTime.now().subtract(const Duration(days: 14)),
              );
            }
          }

          if (section) {
            final actual = await api.section('aqeeda', 10);
            final original = parseDorarSection(sectionHtml)!;
            expect(actual!.title, original.title);
            expect(
              actual.paras.map((p) => p.text),
              original.paras.map((p) => p.text),
            );
            expect(actual.footnotes, original.footnotes);
            expect(requested.single.path, '/aqeeda/10');
          } else if (scenario ==
              'corrupt cache retries after network failure') {
            await expectLater(api.toc('aqeeda'), throwsA(isA<DioException>()));
            checkToc(await api.toc('aqeeda'));
            expect(arrivals, 2);
          } else if (scenario ==
              'interrupted write preserves stale valid cache') {
            final recovered = await IOOverrides.runWithIOOverrides(
              () => api.toc('aqeeda'),
              _PartialWrites(root.path),
            );
            checkToc(recovered);
            expect(await cache.readAsBytes(), tocBytes);
          } else {
            checkToc(await api.toc('aqeeda'));
            expect(
              arrivals,
              scenario == 'fresh valid cache stays offline' ? 0 : 1,
            );
          }
          expect(
            utf8.decode(gzip.decode(await cache.readAsBytes())),
            section ? sectionHtml : tocHtml,
          );
          expect(
            cache.parent
                .listSync()
                .map((entry) => p.basename(entry.path))
                .toList(),
            [p.basename(cache.path)],
          );

          if (scenario == 'fresh corrupt header') {
            // The real contents screen reads the freshly repaired cache through
            // the ordinary singleton, with only its support path isolated.
            PathProviderPlatform.instance = _Paths(root.path);
            await tester.pumpWidget(
              EasyLocalization(
                supportedLocales: const [Locale('en')],
                startLocale: const Locale('en'),
                saveLocale: false,
                path: '.',
                assetLoader: _Translations(translations),
                child: Builder(
                  builder: (context) => MaterialApp(
                    theme: AppTheme.light(),
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    locale: context.locale,
                    home: DorarTocScreen(
                      encyclopedia: dorarEncyclopedias.first,
                    ),
                  ),
                ),
              ),
            );
            await until(
              tester,
              () => find
                  .text(parseDorarToc(tocHtml, 'aqeeda').first.title)
                  .evaluate()
                  .isNotEmpty,
            );
            expect(find.text('dorar.failed'.tr()), findsNothing);
            expect(find.byType(ListView), findsOneWidget);
            if (screenshotReady != null) {
              await screenshotReady();
            }
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          PathProviderPlatform.instance = previousPaths;
          dio.close(force: true);
          await server.close(force: true);
          final owned = await root.resolveSymbolicLinks();
          expect(p.isWithin(tempRoot, owned), true);
          expect(p.basename(owned), startsWith('audit_A39_'));
          await Directory(owned).delete(recursive: true);
        }
      });
    });
  }
}
