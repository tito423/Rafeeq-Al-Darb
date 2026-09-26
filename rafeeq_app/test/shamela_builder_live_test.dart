@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rafeeq_app/features/shamela/data/shamela_book_builder.dart';

/// LIVE: builds two small books from shamela.ws with the app's builder and
/// compares them with the pipeline's copies in scripts/book_text_build.
/// Run 2026-09-26: urid_an_atahaddath 11/11 pages identical; tuhfat_al_atfal
/// same title, author, 8 pages, 7 TOC entries, 7 pages different - each by
/// ONE trailing paragraph in the stored copy: the editor's footnotes
/// («(١) النون الساكنة ...»). That copy was built 2026-09-12, before the
/// pipeline learned to drop `<p class="hamesh">`; today's Python parse of
/// the same live page has 10 paragraphs, like the app. So pages are not
/// asserted equal here - title, author, page count and TOC are.
/// Hits the network, so it is skipped unless asked for:
///   flutter test --tags live --run-skipped test/shamela_builder_live_test.dart
class _Dirs extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.createTempSync('shamela').path;
}

Map<String, dynamic> _pipeline(String name) {
  var raw = File('../scripts/book_text_build/$name.json').readAsBytesSync();
  if (raw[0] == 0x1f && raw[1] == 0x8b) raw = gzip.decode(raw) as dynamic;
  return jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
}

void main() {
  PathProviderPlatform.instance = _Dirs();
  for (final (name, id) in [('tuhfat_al_atfal', 9632), ('urid_an_atahaddath', 1387)]) {
    test('$name ($id) builds like the pipeline built it', () async {
      final b = ShamelaBookBuilder(id);
      final card = await b.fetchCard();
      final bytes = await b.build(card, bookId: name);
      final doc = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
      final ref = _pipeline(name);
      final out = StringBuffer();
      final m = doc['meta'] as Map, rm = ref['meta'] as Map;
      out.writeln('title  app=${m['titleAr']} | pipe=${rm['titleAr']}');
      out.writeln('author app=${m['authorAr']} | pipe=${rm['authorAr']}');
      out.writeln('pages  app=${m['pageCount']} pipe=${rm['pageCount']}  '
          'toc app=${(doc['toc'] as List).length} pipe=${(ref['toc'] as List).length}');
      final ap = doc['pages'] as List, rp = ref['pages'] as List;
      var same = 0, diff = 0;
      for (var i = 0; i < ap.length && i < rp.length; i++) {
        if (jsonEncode(ap[i]) == jsonEncode(rp[i])) {
          same++;
        } else {
          diff++;
          if (diff <= 2) out.writeln('page $i differs:\n  app=${jsonEncode(ap[i]).substring(0, 200.clamp(0, jsonEncode(ap[i]).length))}\n  pipe=${jsonEncode(rp[i]).substring(0, 200.clamp(0, jsonEncode(rp[i]).length))}');
        }
      }
      out.writeln('pages identical $same, different $diff');
      File('build/shamela_live_$name.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(out.toString());
      expect(m['pageCount'], rm['pageCount']);
      expect(jsonEncode(doc['toc']), jsonEncode(ref['toc']));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
