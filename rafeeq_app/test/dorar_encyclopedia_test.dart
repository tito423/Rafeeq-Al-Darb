import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_encyclopedia.dart';

/// Against real dorar.net pages fetched 2026-09-26: the aqeeda front page
/// (its whole table of contents), sections aqeeda/10 and feqhia/10, and
/// aqeeda/30 - an id that is NOT a section (the generic page, a soft 404).
String _page(String name) => utf8.decode(
    gzip.decode(File('test/fixtures/dorar_$name.html.gz').readAsBytesSync()));

/// Without harakat: a retyped string need not order them as Dorar does.
String _bare(String t) => t.replaceAll(RegExp('[ً-ْ]'), '');

int _count(List<DorarTocNode> nodes) => nodes.fold(
    0, (n, x) => n + (x.isSection ? 1 : 0) + _count(x.children));

void main() {
  test('the aqeeda contents: the whole tree, every section linked', () {
    final toc = parseDorarToc(_page('enc_aqeeda'), 'aqeeda');
    // 1,469 `/aqeeda/N` links on the page; the tree holds them all.
    expect(_count(toc), 1469);
    expect(_bare(toc.first.title), 'مقدمة');
    expect(toc.first.id, 1);
    final book1 = toc[1];
    expect(book1.isSection, isFalse);
    expect(_bare(book1.title), startsWith('الكتاب الأول'));
    // كتاب > باب > فصل > مبحث > مطلب > فرع: section 10 sits five folders down.
    var node = book1;
    for (var i = 0; i < 4; i++) {
      node = node.children.first;
    }
    expect(node.children.map((c) => c.id), [8, 10]);
  });

  test('a section: title, text, footnotes lifted out', () {
    final s = parseDorarSection(_page('aq10'))!;
    expect(_bare(s.title), 'الفرع الثاني: تعريف العقيدة اصطلاحا');
    expect(_bare(s.paras.single.text), startsWith('العقيدة في الاصطلاح:'));
    expect(_bare(s.footnotes.single), startsWith('ينظر: ((المصباح المنير))'));
  });

  test('a fiqh section keeps its headings and all its footnotes', () {
    final s = parseDorarSection(_page('fq10'))!;
    final heads = [for (final p in s.paras) if (p.heading) _bare(p.text)];
    expect(heads, contains('المطلب الأول: تعريف الماء النجس'));
    expect(heads, contains('المطلب الثاني: حكم الماء النجس'));
    expect(s.footnotes.length, greaterThanOrEqualTo(3));
    // The page's FAQ block below the section is not section text.
    expect(s.paras.any((p) => p.text.contains('public-qa')), isFalse);
  });

  test('an id that is not a section is recognised, not shown blank', () {
    expect(parseDorarSection(_page('aq30')), isNull);
  });
}
