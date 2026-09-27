import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_encyclopedia.dart';

/// Real dorar.net pages fetched 2026-09-27: /tafseer (the 114 surah cards),
/// /tafseer/2 (al-Baqarah's introduction), /tafseer/2/1 (its first ayah
/// range), /tafseer/1/1 (al-Fatiha's last part, whose «التالي» leads to
/// al-Baqarah).
String fixture(String name) => utf8.decode(
    gzip.decode(File('test/fixtures/dorar_$name.html.gz').readAsBytesSync()));

void main() {
  test('the surah cards: all 114, in order', () {
    final s = parseDorarTafseerSurahs(fixture('enc_tafseer'));
    expect(s.length, 114);
    expect(s.first.number, 1);
    expect(s.first.title, contains('الفاتحة'));
    expect(s.last.number, 114);
  });

  test("a surah's introduction: its sections, footnotes and chain", () {
    final p = parseDorarChainPage(fixture('t2'), 'tafseer')!;
    expect(p.title, contains('البَقَرَةِ'));
    final heads = [for (final x in p.paras) if (x.heading) x.text];
    // The site's own diacritic order is kept (never normalised), so the
    // check is on the undiacritised word.
    expect(heads.first, startsWith('أسماء'));
    expect(p.footnotes, isNotEmpty);
    expect(p.prev, '/tafseer/1');
    expect(p.next, '/tafseer/2/1');
  });

  test('an ayah range: the seven sections the site lists', () {
    final p = parseDorarChainPage(fixture('t21'), 'tafseer')!;
    final heads = [for (final x in p.paras) if (x.heading) x.text];
    expect(heads, containsAll(['غريب الكلمات', 'تفسير الآيات', 'بلاغة الآيات']));
    expect(p.prev, '/tafseer/2');
    expect(p.next, '/tafseer/2/2');
  });

  test("the chain crosses surahs: al-Fatiha's last part leads to al-Baqarah", () {
    final p = parseDorarChainPage(fixture('t11'), 'tafseer')!;
    expect(p.title, contains('الفاتحة'));
    expect(p.next, '/tafseer/2');
  });
}
