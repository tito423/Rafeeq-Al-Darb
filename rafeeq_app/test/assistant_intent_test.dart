// Reads JSON fixtures field by field; a wrong shape fails the test, which
// is the point.
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_intent.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_lexicon.dart';
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
  final latin = (jsonDecode(File('test/fixtures/surah_names_en.json')
          .readAsStringSync()) as List)
      .cast<String>();
  // The app's own seven translation files, as the app reads them.
  final labels = labelsFrom([
    for (final l in ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'])
      jsonDecode(File('assets/translations/$l.json').readAsStringSync())
          as Map<String, dynamic>,
  ]);
  final p = AssistantParser(AssistantCatalog(
      surahs: surahs,
      surahsLatin: latin,
      reciters: reciters,
      books: books,
      screenLabels: labels.screens,
      settingLabels: labels.settings,
      optionLabels: labels.options,
      settingSections: labels.sections));
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

  test('Shamela: a title said with «الشاملة» (owner, 2026-09-27)', () {
    expect(p.parse('يا رفيق نزلي كتاب الزهد للامام احمد ابن حنبل من الشامله').toString(),
        'shamela "الزهد للامام احمد ابن حنبل" download');
    expect(p.parse('دورلي في المكتبه الشامله علي كتاب صيد الخاطر').toString(),
        'shamela "صيد الخاطر"');
    // No title: the screen itself.
    expect(p.parse('افتح المكتبه الشامله').toString(), 'open shamela');
  });

  test('a setting opens its own section (owner, 2026-09-27)', () {
    expect(of('افتح ضبط المواقيت والتاريخ'), 'setting prayer.adjustments');
    expect(of('يا رفيق افتحلي تذكير صيام السنن'), 'setting fasting.section_title');
    expect(of('افتح لي تذكير صيام السنن'), 'setting fasting.section_title');
    expect(of('ساعة الشاشة الرئيسية'), 'setting home.clock_section');
    // As the recogniser wrote it on emulator-5554 (2026-09-28): the name
    // glued to a two-letter word, and «السنن» heard as «السنا».
    const heard = 'يا رفيقفي تحلي تذكير صيام السنا';
    expect(afterWakeWord(heard), isNotNull);
    expect(of(afterWakeWord(heard)!), 'setting fasting.section_title');
    // Egyptian: «عايز أشوف …», «فين …», «خدني على …».
    expect(of('عايز اشوف تذكير صيام السنن'), 'setting fasting.section_title');
    expect(of('فين الاذكار'), 'open azkar');
    expect(of('خدني علي القبله'), 'open qibla');
    // «افتح ضبط المواقيت والتاريخ», as it was heard the same night.
    expect(of(afterWakeWord('يار فيق فتحضط المواقيط والتاريخ')!),
        'setting prayer.adjustments');
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

  test('options, in Arabic', () {
    expect(of('خلي التطبيق ليلي'), 'theme dark');
    expect(of('غير المظهر لنهاري'), 'theme light');
    expect(of('غير اللغة للانجليزي'), 'language en');
    expect(of('اقفل التأثيرات الحركية'), 'toggle motion off');
    expect(of('شغل فيديو البداية'), 'toggle splash on');
    // Egyptian, pronoun attached.
    expect(of('طفيها التأثيرات الحركية'), 'toggle motion off');
    expect(of('ولع فيديو البداية'), 'toggle splash on');
    expect(of('افتح شكل الساعة'), 'open clockFaces');
  });

  test('English, as people say it', () {
    expect(of('open settings'), 'open settings');
    expect(of('take me to the qibla'), 'open qibla');
    expect(of('show me the downloads'), 'open downloads');
    expect(of('play surah Al Kahf'), 'play surah 18 by -');
    expect(of('play Yasin by Alafasy'), startsWith('play surah 36 by ar.alafasy'));
    expect(of('switch to dark mode'), 'theme dark');
    expect(of('change the language to French'), 'language fr');
    expect(of('turn off animations'), 'toggle motion off');
    expect(of('on this day'), 'on this day -/-');
    expect(of('open privacy policy'), 'open settings');
    expect(of('what is the ruling on prayer'), 'unknown');
  });

  test('Spanish, French, Portuguese', () {
    expect(of('abre los ajustes'), 'open settings');
    expect(of('pon la sura Al-Kahf'), 'play surah 18 by -');
    expect(of('cambia el idioma a inglés'), 'language en');
    expect(of('modo oscuro'), 'theme dark');
    expect(of('ouvre les paramètres'), 'open settings');
    expect(of('mets la sourate Al-Fatiha'), 'play surah 1 by -');
    expect(of('passe en mode sombre'), 'theme dark');
    expect(of('change la langue en arabe'), 'language ar');
    expect(of('abre as configurações'), 'open settings');
    expect(of('toca a surata Al-Mulk'), 'play surah 67 by -');
    expect(of('muda o idioma para russo'), 'language ru');
  });

  test('Russian and Urdu', () {
    expect(of('открой настройки'), 'open settings');
    expect(of('включи суру Аль-Кахф'), 'play surah 18 by -');
    expect(of('поменяй язык на английский'), 'language en');
    expect(of('тёмная тема'), 'theme dark');
    expect(of('ترتیبات کھولو'), 'open settings');
    expect(of('سورہ کہف چلاؤ'), 'play surah 18 by -');
    expect(of('زبان انگریزی کرو'), 'language en');
  });

  // omnilingual-asr's own output on the spoken test commands
  // (E:\\DevEnv\\asr\\measure2.py, 2026-09-27) - the text the app will get.
  test('what the recogniser actually wrote', () {
    String call(String heard) => of(afterWakeWord(heard) ?? 'NO WAKE');
    expect(call('يار فيق فتحل الأثكار'), 'open azkar');
    expect(call('يا رفيق شغل سورة الكهف بصوت الحصري'),
        startsWith('play surah 18 by ar.husary'));
    expect(call('يا رفيق خل التديق ليلي'), 'theme dark');
    expect(call('يا رفيق افتح كتاب بلوغ المرام'), 'book bulugh_al_maram');
    expect(call('يا رفيق حدث في مثل هذا اليوم أتناش الربيع الأول'),
        'on this day 12/3');
    expect(call('يارفيق ورين اتجاها القبلة'), 'open qibla');
    expect(call('рафик открой настройки'), 'open settings');
    expect(call('rafec abre los ajustes'), 'open settings');
    expect(call('rafek ouvre la kibla'), 'open qibla');
    expect(afterWakeWord('صلاة العصر بعد قليل'), isNull);
    expect(afterWakeWord('افتح الأذكار'), isNull);
  });

  // The same clips through silero VAD with RafeeqEar's settings, then the
  // recogniser (E:\DevEnv\asr\vad_pipe.py, 2026-09-27): one segment each.
  test('the VAD pipeline output', () {
    String call(String heard) => of(afterWakeWord(heard) ?? 'NO WAKE');
    expect(call('يار فيق فيتحل الأثكار'), 'open azkar');
    expect(call('يارفيق خل التديق ليلي'), 'theme dark');
    expect(call('يا رفيق إفتح كتاب بلوغ المرام'), 'book bulugh_al_maram');
    expect(call('يارفيقورين اتجاه القبلة'), 'open qibla');
    expect(call('rafique passe en mode sombre'), 'theme dark');
    expect(call('rafiek abre as configurações'), 'open settings');
    expect(call('رفيق ترتيبت کولو'), 'open settings');
  });
}
