import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_encyclopedia.dart';

/// Real dorar.net pages fetched 2026-09-27: /history (its seven eras) and
/// /history?era=1 (عصر النبوة, page 1 of 8: events 1-20).
String fixture(String name) => utf8.decode(
    gzip.decode(File('test/fixtures/dorar_$name.html.gz').readAsBytesSync()));

String bare(String s) => s.replaceAll(RegExp('[ً-ْ]'), '');

void main() {
  test('the seven eras, in order', () {
    final e = parseDorarHistoryEras(fixture('enc_history'));
    expect(e.map((x) => x.number), [1, 2, 3, 4, 5, 6, 7]);
    expect(e.first.title, 'عصر النبوة');
    expect(e.last.title, 'التاريخ المعاصر');
  });

  test('an era page: 20 events with title, both years and the details', () {
    final p = parseDorarHistoryPage(fixture('h_era1'));
    expect(p.events.length, 20);
    expect(p.lastPage, 8);
    final first = p.events.first;
    expect(first.id, 1);
    expect(first.title, contains('ولادة النبي'));
    expect(first.hijri, '53 ق هـ');
    expect(first.gregorian, '571');
    expect(first.details.join(' '), contains('عام الفيل'.substring(0, 2)));
    final second = p.events[1];
    expect(second.id, 2);
    // Compared without diacritics: the site's own mark order is kept as is.
    expect(bare(second.title), contains('حادثة شق صدر النبي'));
    expect(second.hijri, '49 ق هـ');
    expect(second.gregorian, '575');
    expect(p.events.map((e) => e.id), List.generate(20, (i) => i + 1));
  });
}
