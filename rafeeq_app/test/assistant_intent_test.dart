// Reads JSON fixtures field by field; a wrong shape fails the test, which
// is the point.
// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/recitation_source.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_intent.dart';
import 'package:rafeeq_app/features/assistant/data/assistant_lexicon.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/sunan_suwar/data/sunan_suwar_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// «رفيق»'s understanding, on the app's REAL catalogues: the 114 surah
/// names from quran_local.db, the 176 Arabic audio editions of
/// audio_editions.json, the library's book catalogue.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final surahs = (jsonDecode(File('test/fixtures/surah_names_ar.json')
          .readAsStringSync()) as List)
      .cast<String>();
  final reciters = [
    for (final r in jsonDecode(File('test/fixtures/assistant_reciters.json')
        .readAsStringSync()) as List)
      if (RecitationSource.hasVerifiedMirror(r['id'] as String))
        CatalogReciter(r['id'] as String, (r['names'] as List).cast<String>()),
  ];
  final books = [
    for (final b in libraryBookCatalog)
      CatalogBook(b.id, b.titleAr, b.authorAr),
  ];
  final wholeSurahReciters = [
    for (final r in jsonDecode(
        File('assets/data/catalogs/reciters_full.json').readAsStringSync()) as List)
      CatalogWholeReciter(r['id'] as int, [r['name'] as String]),
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
  late AssistantParser p;
  setUpAll(() async {
    final db = await databaseFactory.openDatabase(
        File('assets/data/azkar.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    final rows = await db.query('azkar_sections', orderBy: 'id');
    final hadeethDir = Directory.systemTemp.createTempSync('hadeethenc_test_');
    final archive = ZipDecoder().decodeBytes(
        File('assets/data/hadeethenc/hadeethenc_ar.zip').readAsBytesSync());
    final dbEntry = archive.files.firstWhere(
        (entry) => entry.isFile && entry.name.toLowerCase().endsWith('.db'));
    final hadeethFile = File('${hadeethDir.path}/hadeethenc_ar.db')
      ..writeAsBytesSync(dbEntry.content as List<int>);
    final hadeethDb = await databaseFactory.openDatabase(hadeethFile.path,
        options: OpenDatabaseOptions(readOnly: true));
    final hadeethRows = await hadeethDb.query('categories',
        columns: ['id', 'title', 'title_ar'], orderBy: 'CAST(id AS INTEGER)');
    final hadithArchive = ZipDecoder()
        .decodeBytes(File('assets/data/hadith.zip').readAsBytesSync());
    final hadithEntry = hadithArchive.files.firstWhere(
        (entry) => entry.isFile && entry.name.toLowerCase().endsWith('.db'));
    final hadithFile = File('${hadeethDir.path}/hadith.db')
      ..writeAsBytesSync(hadithEntry.content as List<int>);
    final hadithDb = await databaseFactory.openDatabase(hadithFile.path,
        options: OpenDatabaseOptions(readOnly: true));
    final hadithRows = await hadithDb.query('books',
        columns: ['id', 'name_ar', 'name_en'], orderBy: 'sort_order');
    final chapterRows = await hadithDb.query('chapters',
        columns: ['book_id', 'chapter_no', 'name_ar', 'name_en'],
        orderBy: 'book_id, chapter_no');
    final localeData = [
      for (final l in ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'])
        jsonDecode(File('assets/translations/$l.json').readAsStringSync())
            as Map<String, dynamic>,
    ];
    p = AssistantParser(AssistantCatalog(
        surahs: surahs,
        surahsLatin: latin,
        sunanSurahIds: {for (final s in sunanSuwarCatalog) s.surahId},
        azkarSections: [
          for (final row in rows)
            CatalogAzkarSection(row['id'] as int, [
              row['title'] as String,
              for (final locale in localeData)
                (((locale['azkar'] as Map<String, dynamic>)['section']
                        as Map<String, dynamic>)['${row['id']}'])
                    as String,
            ]),
        ],
        wholeSurahReciters: wholeSurahReciters,
        hadeethCategories: [
          for (final row in hadeethRows)
            CatalogHadeethCategory(row['id'] as String,
                [row['title'] as String, row['title_ar'] as String]),
        ],
        hadithBooks: [
          for (final row in hadithRows)
            CatalogHadithBook(row['id'] as int,
                [row['name_ar'] as String, row['name_en'] as String]),
        ],
        hadithChapters: [
          for (final row in chapterRows)
            CatalogHadithChapter(
                row['book_id'] as int, row['chapter_no'] as num,
                [row['name_ar'] as String, row['name_en'] as String]),
        ],
        reciters: reciters,
        books: books,
        screenLabels: labels.screens,
        settingLabels: labels.settings,
        optionLabels: labels.options,
        settingSections: labels.sections));
    await db.close();
    await hadeethDb.close();
    await hadithDb.close();
    hadeethDir.deleteSync(recursive: true);
  });
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
    expect(of('افتح عن التطبيق'), 'open about');
    expect(of('افتح المصادر والمراجع'), 'open sources');
    expect(of('افتح ادعم التطبيق'), 'open support');
    expect(of('افتح الإهداءات'), 'open dedications');
    expect(of('افتح ختمة القرآن'), 'open khatma');
    expect(of('افتح بحث في كل الكتب'), 'open bookSearch');
    expect(of('افتح إعدادات الأذان'), 'open adhanSettings');
    expect(of('افتح خلفيات شاشة الأذان'), 'open adhanBackgrounds');
    expect(of('افتح شاشة ضبط المواقيت والتاريخ'), 'open prayerAdjustments');
    expect(of('افتح موقع الصلاة'), 'open prayerLocation');
    expect(of('افتح علوم القرآن'), 'open quranSciences');
    expect(of('افتح مخارج الحروف'), 'open makharij');
    expect(of('افتح المستوى الأول تحفة الأطفال'), 'open tuhfa');
    expect(of('افتح المستوى الثاني المقدمة الجزرية'), 'open jazariyyah');
    expect(of('افتح المستوى الثالث التمهيد في علم التجويد'), 'open tamhid');
    expect(of('افتح بحث في الموسوعات كلها'), 'open dorarSearch');
    expect(of('افتح تخريج الأحاديث الدرر السنية'), 'open dorarHadith');
    expect(of('افتح موسوعة التفسير'), 'open dorarTafseer');
    expect(of('افتح الموسوعة التاريخية'), 'open dorarHistory');
    expect(of('افتح الرقية الشرعية'), 'open ruqyah');
    expect(of('افتح الاستماع للرقية الشرعية'), 'open ruqyahAudio');
    expect(of('افتح التحميلات المبدئية'), 'open initialDownloads');
    expect(of('افتح معاينة الفيديو الافتتاحي'), 'open splashPreview');
    expect(of('افتح البحث الموضوعي'), 'open quranSearch');
  });

  test('a surah, with and without a reciter', () {
    expect(of('شغل سورة الكهف'), 'play surah 18 by -');
    expect(of('شغللي سورة الكهف بصوت الشاطري'),
        startsWith('play surah 18 by ar.shaatree'));
    expect(of('اقرالي يس للعفاسي'), startsWith('play surah 36 by ar.alafasy'));
    expect(of('شغل سورة آل عمران'), 'play surah 3 by -');
    expect(of('شغل سورة ١٨'), 'play surah 18 by -');
    expect(of('يا رفيق شغل البقرة بصوت الحصري'), startsWith('play surah 2 by ar.husary'));
    expect(of('احفظ سورة الكهف'), 'memorize surah 18');
    expect(of('حفظني البقرة'), 'memorize surah 2');
  });

  // Owner, 2026-09-29: this sentence, said from outside the app, started a
  // recitation of al-Baqarah from ayah 1 in the background instead of
  // opening the mushaf on the ayah.
  test('open the mushaf on a surah and an ayah', () {
    expect(of('يا رفيق افتح التطبيق على القرآن سورة البقرة آية ٢٥٥'),
        'open quran 2:255 marked');
    expect(of('افتح سورة البقرة الاية 255'), 'open quran 2:255 marked');
    expect(of('افتح سوره البقره ايه مئتين وخمسه وخمسين'), 'open quran 2:255 marked');
    expect(of('افتح البقرة آية ميتين خمسة وخمسين'), 'open quran 2:255 marked');
    expect(of('وريني آية الكرسي'), 'open quran 2:255 marked');
    expect(of('افتح سورة الكهف'), 'open quran 18:1');
    expect(of('افتح سورة يس آية عشرين'), 'open quran 36:20 marked');
    expect(of('open surah Al Kahf verse 10'), 'open quran 18:10 marked');
  });

  // What the recogniser REALLY wrote for the owner's sentence, said from the
  // phone's home screen on emulator-5554 (2026-09-30): the verb glued to
  // «التطبيق», the phrase cut after «آي», the number in the next breath.
  // It used to become «play surah 2» in the background.
  test('the owner sentence as the recogniser heard it', () {
    expect(of('افتحتطبيق علي القران سوره البقره اي'),
        'open quran 2:1 (number pending)');
    expect(spokenNumber('مئتين وخمسه وخمسين'), 255);
    expect(spokenNumber('الآية ٢٥٥'), 255);
    expect(spokenNumber('افتح الأذكار'), isNull);
    final f = AyahFollowUp()
      ..arm(p.parse('افتحتطبيق علي القران سوره البقره اي'));
    expect(f.take('مئتين وخمسة وخمسين').toString(), 'open quran 2:255 marked');
    expect(f.take('مئتين وخمسة وخمسين'), isNull, reason: 'used once');
  });

  // The Arabic pack (NVIDIA FastConformer) on the owner's sentence, measured
  // on the PC 2026-09-30: numbers in MSA words, «صورة» for «سورة».
  test('the Arabic pack wording', () {
    expect(of('يا رفيق افتح التطبيق على القرآن سورة البقرة آية مئتان وخمسة وخمسون'),
        'open quran 2:255 marked');
    expect(of('افتح صورة البقرة آية مئتان وخمسة وخمسين'), 'open quran 2:255 marked');
    expect(spokenNumber('مئتان وخمسة وخمسون'), 255);
    expect(spokenNumber('الآية مئة وخمسة وخمسون'), 155);
  });

  test('a surah with no play word opens, it does not play', () {
    expect(of('القرآن سورة البقرة'), 'open quran 2:1');
    expect(of('سورة الكهف'), 'open quran 18:1');
    // A reciter's name still means play.
    expect(of('سورة الكهف بصوت الحصري'), startsWith('play surah 18 by ar.husary'));
  });

  test('play a surah from the ayah that was said', () {
    expect(of('شغل سورة البقرة من آية ٢٥٥'), 'play surah 2 by - from 255');
    expect(of('شغل آية الكرسي'), 'play surah 2 by - from 255');
    expect(of('شغل سورة الكهف من الآية عشرة بصوت الحصري'),
        startsWith('play surah 18 by ar.husary'));
    // Without an ayah the old reading stands.
    expect(of('شغل سورة الكهف'), 'play surah 18 by -');
  });

  test('sunan surah commands use only the real four-surah catalogue', () {
    expect(of('افتح سنن سورة الكهف'), 'sunan surah 18');
    expect(of('وريني سنن سورة الملك'), 'sunan surah 67');
    expect(p.parse('افتح سنن سورة الإخلاص'), isA<UnknownIntent>());
  });

  test('azkar section commands resolve only real database sections', () {
    // Hisn al-Muslim's chapters (2026-09-29): 25 is «الأذكار بعد السلام من
    // الصلاة», 106 is «ذكر الرجوع من السفر».
    expect(of('افتح الأذكار بعد السلام من الصلاة'), 'azkar section 25');
    expect(of('افتح الأذكار بعد الصلاة'), 'azkar section 25');
    expect(of('وريني ذكر الرجوع من السفر'), 'azkar section 106');
    expect(p.parse('افتح ما يقال قبل المذاكرة'), isA<UnknownIntent>());
  });

  test('every Quran word can be asked for by voice (owner, 2026-09-29)', () {
    expect(of('فين كلمة الرحمن في القرآن'), 'quran word الرحمن');
    expect(of('كلمة رحمة ذكرت في ايه'), 'quran word رحمه');
    expect(of('دورلي على كلمة الصبر في القران'), 'quran word الصبر');
    expect(of('اعرضلي آية فيها كلمة عسعس'), 'quran word عسعس');
    expect(of('where is the word mercy in the quran'), 'quran word mercy');
    // Exactly as the recogniser wrote it on emulator-5554 (2026-09-29).
    expect(of('فينكلمة عسعس في القرآن'), 'quran word عسعس');
    expect(of('فينكلمت الصابرين في القرآن'), 'quran word الصابرين');
    // Not a word question: screens and books that merely contain «كلمات».
    expect(of('افتح معاني الكلمات'), isNot(startsWith('quran word')));
    expect(of('فين الاذكار'), 'open azkar');
  });

  test('ayah-by-ayah reciter uses only its verified provider catalogue', () {
    expect(of('افتح تلاوة آية بآية للحصري'), 'ayah reciter ar.husary');
    expect(of('وريني آية بآية بصوت الطبلاوي'),
        'ayah reciter ar.mohamedtablawi');
    // Mohamed Hassan exists in the whole-surah catalogue only. The command
    // may open the picker, but must not invent a per-ayah reciter route.
    expect(of('افتح تلاوة آية بآية لمحمد حسان'), 'open ayahPlayer');
  });

  test('hadeeth encyclopedia category uses only real bundled database rows', () {
    expect(of('افتح قسم العقيدة في موسوعة الأحاديث النبوية'),
        'hadeeth category 3');
    expect(of('وريني الفقه وأصوله'), 'hadeeth category 4');
    expect(p.parse('افتح قسم الطب في موسوعة الأحاديث النبوية'),
        isA<UnknownIntent>());
  });

  test('hadeeth encyclopedia detail stays contextual, not an internal-id command', () {
    expect(p.parse('افتح حديث رقم 1751 من موسوعة الأحاديث النبوية'),
        isA<UnknownIntent>());
    expect(of('افتح الحديث رقم 1751 من صحيح البخاري'),
        'hadith detail 1/1751');
    // Measured ASR output after the spoken ID was swallowed. «رقمه» must
    // never be spelling-corrected to «رقية» and open an unrelated screen.
    expect(p.parse('من موسوعة الأحديث النبوية اذتح الحديث الذي رقمه'),
        isA<UnknownIntent>());
    expect(of('افتح الرقية الشرعية'), 'open ruqyah');
  });

  test('nine-books commands use exact real bundled book names', () {
    expect(of('افتح كتاب صحيح البخاري'), 'hadith book 1');
    expect(of('وريني سنن النسائي'), 'hadith book 5');
    expect(of('افتح كتاب فتح الباري بشرح صحيح البخاري'), 'book fath_al_bari');
    expect(p.parse('افتح سنن البيهقي'), isA<UnknownIntent>());
  });

  test('hadith chapter requires a real chapter and its real parent book', () {
    expect(of('افتح فصل بدء الوحي من صحيح البخاري'),
        'hadith chapter 1/1');
    expect(of('افتح فصل المزارعة من سنن النسائي'),
        'hadith chapter 5/35.2');
    expect(p.parse('افتح فصل الطب البيطري من صحيح البخاري'),
        isA<UnknownIntent>());
  });

  test('nine-books hadith detail requires a real parent book and number', () {
    expect(of('افتح الحديث رقم 1 من صحيح البخاري'), 'hadith detail 1/1');
    // Exact emulator ASR output for the same hands-free command.
    expect(of('افتح الحديث واحد من صحيح البخاري'), 'hadith detail 1/1');
    expect(of('وريني حديث 35 من سنن أبي داود'), 'hadith detail 3/35');
    expect(p.parse('افتح الحديث رقم 1 من سنن البيهقي'),
        isA<UnknownIntent>());
  });

  test('whole-surah reciter uses only the mp3quran catalogue', () {
    expect(of('افتح مشغل التلاوات للحصري'), 'whole surah reciter 118');
    expect(of('وريني مشغل القرآن للطبلاوي'), 'whole surah reciter 106');
    // Parhizgar is verified per-ayah but absent from mp3quran's full-surah
    // catalogue. Keep the catalogues separate and open only the general list.
    expect(of('افتح مشغل التلاوات للقارئ شهریار پرهیزگار'),
        'open recitationPlayer');
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
    expect(of('افتح ضبط المواقيت والتاريخ'), 'open prayerAdjustments');
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
        'open prayerAdjustments');
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
    // As the recogniser wrote the spoken clip on emulator-5554: it dropped
    // the first letter of «رفيق» and glued the command to the remainder.
    const gluedOff = 'يار فيقطفيها فيديو البداية';
    expect(afterWakeWord(gluedOff), 'طفيها فيديو البدايه');
    expect(of(afterWakeWord(gluedOff)!), 'toggle splash off');
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

  // «يا رفيق افتح سورة …» for all 114 surahs, three TTS voices, spoken to
  // the app's own Arabic model (FastConformer, the same file byte for byte)
  // at full quality and through a phone-call band (8 kHz, 300-3400 Hz, what
  // a Bluetooth headset carries): E:/DevEnv/asr/surah_audit.py, 2026-09-30.
  // What the model WROTE must open the surah that was said. The owner's
  // «افتح سورة يوسف» came back «مش لاقي» on his phone.
  test('«صورتي يس», as the model wrote «سورة يس» on the emulator', () {
    final i = p.parse('افتح صورتي يس');
    expect(i, isA<OpenQuranAyahIntent>());
    expect((i as OpenQuranAyahIntent).surah, 36);
  });

  // Owner, 2026-09-30: «افتح سورة كذا آية كذا» must MARK the ayah (and go
  // to it), and «افتح كارت الآية … ع التفسير او الترجمه», in every dialect.
  test('an ayah asked for: marked, and its card on the tab asked for', () {
    final cases = <String, (int, int, bool, int?)>{
      'افتح سورة البقرة آية ٢٥٥': (2, 255, true, null),
      'افتح سورة يوسف': (12, 1, false, null),
      'حل سورة يوسف': (12, 1, false, null),
      'افتح تفسير آية الكرسي': (2, 255, true, 0),
      'ابغى ترجمة آية الكرسي': (2, 255, true, 1),
      'ترجمة الآية خمسة من سورة البقرة': (2, 5, true, 1),
      'اعراب آية ٣ سورة الفاتحة': (1, 3, true, 2),
      'فسرلي آية ١٠ من سورة يس': (36, 10, true, 0),
      'بدي تفسير سورة الملك آية ١': (67, 1, true, 0),
      'افتح كارت الاية ٢٠ من سورة مريم': (19, 20, true, 0),
      'ودني على سورة الكهف آية عشرة': (18, 10, true, null),
      'فرجيني سورة النور آية ٣٥': (24, 35, true, null),
      'عايز معنى آية ٥ من سورة الفاتحة': (1, 5, true, 0),
      'open the tafsir of surah al baqarah verse 255': (2, 255, true, 0),
      'translation of surah yasin ayah 3': (36, 3, true, 1),
    };
    for (final e in cases.entries) {
      final i = p.parse(e.key);
      expect(i, isA<OpenQuranAyahIntent>(), reason: '${e.key} -> $i');
      final o = i as OpenQuranAyahIntent;
      expect((o.surah, o.ayah, o.marked, o.card), e.value, reason: e.key);
    }
  });

  test('every surah, as the Arabic model writes it', () {
    final rows = jsonDecode(
        File('test/fixtures/asr_surah_transcripts.json').readAsStringSync()) as List;
    final missed = <String>[];
    for (final r in rows) {
      for (final k in ['wide', 'phone']) {
        final heard = r[k] as String;
        final rest = afterWakeWord(heard) ?? heard;
        final i = p.parse(rest);
        if (i is! OpenQuranAyahIntent || i.surah != r['surah'] || i.ayah != 1) {
          missed.add('${r['surah']} $k "$heard" -> $i');
        }
      }
    }
    File('build/asr_surah_missed.txt').writeAsStringSync(missed.join('\n'));
    // 247 of 684 missed before «النحل» stopped being "corrected" away and
    // the near-miss match existed. The 29 left are the model's own garble
    // («صورةتهد», «تم» for الزمر) or spell another surah («العلى» is
    // الأعلى); a ceiling, so it can only go down.
    expect(missed.length, lessThanOrEqualTo(29), reason: missed.join('\n'));
  });
}
