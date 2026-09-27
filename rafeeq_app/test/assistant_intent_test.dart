import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_intent.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// «رفيق»'s understanding, on the app's REAL catalogues: the 114 surah
/// names from quran_local.db, the 176 Arabic audio editions of
/// audio_editions.json, the library's book catalogue.
void main() {
  final surahs = (jsonDecode(File('test/fixtures/surah_names_ar.json')
          .readAsStringSync()) as List)
      .cast<String>();
  final reciters = [
    for (final r in jsonDecode(File('test/fixtures/assistant_reciters.json')
        .readAsStringSync()) as List)
      CatalogReciter(r['id'] as String, (r['names'] as List).cast<String>()),
  ];
  final books = [
    for (final b in libraryBookCatalog)
      CatalogBook(b.id, b.titleAr, b.authorAr),
  ];
  final p = AssistantParser(AssistantCatalog(
      surahs: surahs, reciters: reciters, books: books));
  String of(String s) => p.parse(s).toString();

  test('screens, in the words people say', () {
    expect(of('يا رفيق افتحلي الأذكار'), 'open azkar');
    expect(of('افتح المسبحة'), 'open tasbeeh');
    expect(of('عايز أروح للإعدادات'), 'open settings');
    expect(of('وريني التنزيلات'), 'open downloads');
    expect(of('افتح مشغل التلاوة'), 'open recitationPlayer');
    expect(of('افتحلي مشغل التلاوة آية بآية'), 'open ayahPlayer');
    expect(of('افتح المكتبة الشاملة'), 'open shamela');
    expect(of('افتح المكتبة'), 'open library');
    expect(of('اتجاه القبلة'), 'open qibla');
  });

  test('a surah, with and without a reciter', () {
    expect(of('شغل سورة الكهف'), 'play surah 18 by -');
    expect(of('شغللي سورة الكهف بصوت الشاطري'),
        startsWith('play surah 18 by ar.shaatree'));
    expect(of('اقرالي يس للعفاسي'), startsWith('play surah 36 by ar.alafasy'));
    expect(of('شغل سورة آل عمران'), 'play surah 3 by -');
    expect(of('شغل سورة ١٨'), 'play surah 18 by -');
    expect(of('يا رفيق شغل البقرة بصوت الحصري'), startsWith('play surah 2 by ar.husary'));
  });

  test('books and authors from the library', () {
    expect(of('افتح كتاب بلوغ المرام'), 'book bulugh_al_maram');
    expect(of('وريني كل كتب ابن حجر العسقلاني'), contains('ابن حجر العسقلاني'));
  });

  test('on this day, today or a hijri date', () {
    expect(of('حدث في مثل هذا اليوم'), 'on this day -/-');
    expect(of('حدث في مثل هذا اليوم ١٢ ربيع الأول'), 'on this day 12/3');
    expect(of('حدث في مثل هذا اليوم 27 رمضان'), 'on this day 27/9');
  });

  test('nothing the app has is not made up', () {
    expect(of('ما هو حكم صلاة الجمعة'), 'unknown');
    expect(of('شغل سورة المستحيل'), 'unknown');
  });
}
