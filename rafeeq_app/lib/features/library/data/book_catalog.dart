import 'package:easy_localization/easy_localization.dart';

import '../../../core/i18n/proper_name.dart';

import '../../../core/config/app_config.dart';
import 'book_category.dart';

/// A structured **text** edition of a book (P2-4b) — the companion to the
/// scanned image PDF ([LibraryBook.downloadUrl]).
///
/// Source is always al-Maktaba al-Shamela (`shamela.ws`), the owner's chosen
/// source (2026-09-02). The file is the structured JSON produced by
/// `scripts/build_book_text.py` and hosted on `tito423/rafeeq-api`
/// (`books/text/<id>.json`); [BookText] parses it and
/// `BookTextReaderScreen` renders it (فهرس, in-book search, selectable text,
/// font control, bookmarks).
///
/// Downloaded and cached independently of the image PDF, under the
/// [DownloadManager] id `"<book id>_text"`, so a reader can have one edition,
/// the other, or both offline.
class TextEdition {
  /// Structured JSON URL (raw, not zipped — a few hundred KB per book).
  final String url;

  /// Full printed-edition + editor line, shown in the reader at all times
  /// (e.g. "المكتبة الشاملة — ت. شعيب الأرنؤوط، مؤسسة الرسالة، ط٣ ١٤١٩هـ").
  final String sourceLabel;

  /// True only when the text is machine-extracted (OCR). Never true for a
  /// Shamela edition — Shamela is typed text — but the reader honours it with
  /// an honest "نص مستخرَج آلياً" badge if a future OCR source is ever added.
  final bool isOcr;

  /// Real gzipped size of the hosted file, in bytes, measured from the object
  /// the app actually downloads. 0 means unknown — the card then shows no
  /// size at all rather than a guess. Every card used to claim a hardcoded
  /// "1.0 MB" regardless of the book.
  final int sizeBytes;

  const TextEdition({
    required this.url,
    required this.sourceLabel,
    this.isOcr = false,
    this.sizeBytes = 0,
  });
}

/// Text editions live at `<contentBaseUrl>/books/text/<id>.json` on
/// `tito423/rafeeq-api` — `AppConfig.contentBaseUrl` is a compile-time
/// constant (overridable with `--dart-define=RAFEEQ_CONTENT_BASE=…`, the same
/// seam the hadith DB uses), so the `url:` strings below stay `const`.

/// The Library "Books" catalog (WORK_QUEUE Stage 2's remaining piece).
///
/// Every entry here is a real, classical, public-domain Islamic text (each
/// author died centuries ago) scanned and hosted on archive.org as a PDF.
/// Each `downloadUrl` was checked on 2026-09-02 with a real `curl -L` GET:
/// all four returned HTTP 200, `content-type: application/pdf`, and the
/// `approxSizeBytes` below is that response's measured `Content-Length`.
/// This app never rehosts or repackages these scans; it downloads the
/// original file from archive.org on demand, exactly like the hadith
/// database is downloaded from `rafeeq-api`.
///
/// The owner authorized proceeding directly with real, freely available
/// sources (al-Maktaba al-Shamela or another free Islamic-books source) —
/// archive.org's public-domain scans of these same classical texts satisfy
/// that instruction. This is a starting set, not a claim of completeness;
/// more titles can be added the same way once verified the same way.
class LibraryBook {
  final String id;
  final String titleAr;
  final String titleEn;
  final String authorAr;
  final String authorEn;

  /// The compiler's death year in the Hijri calendar — shown so a reader can
  /// see at a glance that this is a centuries-old, public-domain classical
  /// text and not a modern copyrighted work.
  ///
  /// This used to be a whole Arabic sentence per book («توفي 852 هـ»), which
  /// on a French UI put Arabic prose after a Latin author name. It is a number
  /// now, and [deathLabel] writes the sentence in the reader's language.
  final int? deathYearAh;

  /// True where the sources place the death only approximately.
  final bool deathApprox;

  /// For the one author whose dates are not known to a year: an i18n key
  /// instead of a year.
  final String deathNoteKey;
  /// The printed page count, which used to live inside the generated blurb
  /// sentence and nowhere else. 0 for a book whose blurb is prose.
  final int pages;

  /// `book_desc.<id>` for the 29 books with a written blurb; empty for the
  /// 197 whose blurb was the generated sentence, which [description] writes
  /// from `library.book_desc_generated` instead.
  final String descKey;
  final BookCategory category;

  /// Null for a book that ships **only** as a text edition (P3‑15: the
  /// owner asked for a much larger نص-only catalog expansion, sourced the
  /// same way as the original 5 — Shamela — but without also chasing down
  /// a clean scanned PDF for every new title; a مصوّر edition stays
  /// optional, add one later the same way if a good scan turns up). All of
  /// [downloadUrl] / [fileName] / [approxSizeBytes] / [sourceUrl] describe
  /// that image PDF together and are only meaningful when it's non-null.
  final String? downloadUrl;
  final String? fileName;
  final int? approxSizeBytes;

  /// The archive.org item this came from, e.g. "archive.org/details/rsnawwy"
  /// — kept so provenance is always one tap away from the UI, never buried.
  final String? sourceUrl;

  /// The structured text edition (P2-4b), or null if the book ships only as a
  /// scanned image PDF. When both this and [downloadUrl] are set, the
  /// Library shows a `مصوّر | نص` switch; when only one is, that edition is
  /// the only one offered, no switch shown.
  final TextEdition? textEdition;

  const LibraryBook({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.authorAr,
    required this.authorEn,
    this.deathYearAh,
    this.deathApprox = false,
    this.deathNoteKey = '',
    this.pages = 0,
    this.descKey = '',
    required this.category,
    this.downloadUrl,
    this.fileName,
    this.approxSizeBytes,
    this.sourceUrl,
    this.textEdition,
  }) : assert(
         downloadUrl != null || textEdition != null,
         'a book needs at least one edition',
       );

  /// What the card says about the book.
  ///
  /// 197 of the 226 blurbs were one generated sentence with three slots, and
  /// all three are already translated elsewhere: the author's name is written
  /// in the reader's script by [properName], the category has its own key, and
  /// the page count is a number. So they share one key instead of 197.
  String description() => descKey.isNotEmpty
      ? descKey.tr()
      : 'library.book_desc_generated'.tr(args: [
          properName(authorAr, authorEn),
          '$pages',
          category.labelKey.tr(),
        ]);

  /// «توفي 852 هـ» / "Died 852 AH" / «Умер в 852 г. х.» — empty when the
  /// catalogue records neither a year nor a note.
  String deathLabel() {
    if (deathNoteKey.isNotEmpty) return deathNoteKey.tr();
    if (deathYearAh == null) return '';
    return (deathApprox ? 'library.died_circa_ah' : 'library.died_ah')
        .tr(args: ['$deathYearAh']);
  }

  /// [DownloadManager] id for this book's text edition (distinct from the
  /// image PDF, whose id is just [id]).
  String get textDownloadId => '${id}_text';

  bool get hasText => textEdition != null;
  bool get hasImage => downloadUrl != null;

  /// Arabic-collation-friendly sort handle: drops a leading "ال" so
  /// "الفوائد" files under fā', not alif, and normalises alef forms.
  String get sortKey {
    var s = titleAr.trim();
    if (s.startsWith('ال')) s = s.substring(2);
    return s
        .replaceAll(RegExp('[إأآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }
}

const List<LibraryBook> libraryBookCatalog = [
  // ── Hadith expansion (2026-09-08) ──────────────────────────────────────
  // The well-known hadith books, requested alongside the nine collections.
  // Each Shamela id was checked against its own book card and its
  // pageContent API before the text was fetched, and every edition line
  // below is copied from that card — see scripts/build_book_text.py.
  LibraryBook(
    id: 'bulugh_al_maram',
    titleAr: 'بلوغ المرام من أدلة الأحكام',
    titleEn: 'Bulugh al-Maram',
    authorAr: 'الحافظ أحمد بن علي بن حجر العسقلاني',
    authorEn: 'Al-Hafiz Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    descKey: 'book_desc.bulugh_al_maram',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/bulugh_al_maram.json',
      sizeBytes: 328803,
      sourceLabel:
          'المكتبة الشاملة — بلوغ المرام من أدلة الأحكام، أبو الفضل أحمد بن '
          'علي بن حجر العسقلاني (ت ٨٥٢هـ)، دار الفلق - الرياض، الطبعة '
          'السابعة ١٤٢٤هـ',
    ),
  ),
  LibraryBook(
    id: 'al_adab_al_mufrad',
    titleAr: 'الأدب المفرد',
    titleEn: 'Al-Adab al-Mufrad',
    authorAr: 'الإمام محمد بن إسماعيل البخاري',
    authorEn: 'Imam Muhammad ibn Ismail al-Bukhari',
    deathYearAh: 256,
    descKey: 'book_desc.al_adab_al_mufrad',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_adab_al_mufrad.json',
      sizeBytes: 229674,
      sourceLabel:
          'المكتبة الشاملة — الأدب المفرد، محمد بن إسماعيل البخاري '
          '(ت ٢٥٦هـ)، تحقيق محمد فؤاد عبد الباقي، المطبعة السلفية ومكتبتها - '
          'القاهرة، الطبعة الثانية ١٣٧٩هـ',
    ),
  ),
  LibraryBook(
    id: 'sahih_al_adab_al_mufrad',
    titleAr: 'صحيح الأدب المفرد',
    titleEn: 'Sahih al-Adab al-Mufrad',
    authorAr: 'الإمام البخاري — بأحكام الألباني',
    authorEn: 'Al-Bukhari, graded by al-Albani',
    deathYearAh: 256,
    descKey: 'book_desc.sahih_al_adab_al_mufrad',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/sahih_al_adab_al_mufrad.json',
      sizeBytes: 224236,
      sourceLabel:
          'المكتبة الشاملة — صحيح الأدب المفرد للإمام البخاري، بأحكام محمد '
          'ناصر الدين الألباني، دار الصديق للنشر والتوزيع، الطبعة الرابعة '
          '١٤١٨هـ/١٩٩٧م',
    ),
  ),
  LibraryBook(
    id: 'al_shamail_al_muhammadiyyah',
    titleAr: 'الشمائل المحمدية',
    titleEn: 'Al-Shamail al-Muhammadiyyah',
    authorAr: 'الإمام أبو عيسى محمد بن عيسى الترمذي',
    authorEn: 'Imam Abu Isa Muhammad ibn Isa al-Tirmidhi',
    deathYearAh: 279,
    descKey: 'book_desc.al_shamail_al_muhammadiyyah',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_shamail_al_muhammadiyyah.json',
      sizeBytes: 145861,
      sourceLabel:
          'المكتبة الشاملة — الشمائل المحمدية، أبو عيسى محمد بن سورة '
          'الترمذي (ت ٢٧٩هـ)، إخراج وتعليق محمد أحمد حلاق، دار إحياء التراث '
          'العربي، بيروت',
    ),
  ),
  LibraryBook(
    id: 'mishkat_al_masabih',
    titleAr: 'مشكاة المصابيح',
    titleEn: 'Mishkat al-Masabih',
    authorAr: 'الخطيب وليّ الدين محمد بن عبد الله التبريزي',
    authorEn: 'Wali al-Din al-Khatib al-Tibrizi',
    deathNoteKey: 'library.death_8th_century',
    descKey: 'book_desc.mishkat_al_masabih',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/mishkat_al_masabih.json',
      sizeBytes: 866720,
      sourceLabel:
          'المكتبة الشاملة — مشكاة المصابيح، محمد بن عبد الله الخطيب '
          'التبريزي، تحقيق محمد ناصر الدين الألباني، المكتب الإسلامي - '
          'بيروت، الطبعة الثالثة ١٩٨٥م',
    ),
  ),
  LibraryBook(
    id: 'al_targhib_wal_tarhib',
    titleAr: 'الترغيب والترهيب',
    titleEn: 'Al-Targhib wal-Tarhib',
    authorAr: 'الحافظ زكي الدين عبد العظيم المنذري',
    authorEn: 'Al-Hafiz Zaki al-Din al-Mundhiri',
    deathYearAh: 656,
    descKey: 'book_desc.al_targhib_wal_tarhib',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_targhib_wal_tarhib.json',
      sizeBytes: 904549,
      sourceLabel:
          'المكتبة الشاملة — الترغيب والترهيب من الحديث الشريف، زكي الدين '
          'عبد العظيم المنذري (ت ٦٥٦هـ)، تحقيق إبراهيم شمس الدين، دار الكتب '
          'العلمية - بيروت، الطبعة الأولى ١٤١٧هـ',
    ),
  ),
  LibraryBook(
    id: 'umdat_al_ahkam',
    titleAr: 'عمدة الأحكام',
    titleEn: 'Umdat al-Ahkam',
    authorAr: 'الحافظ عبد الغني بن عبد الواحد المقدسي',
    authorEn: 'Al-Hafiz Abd al-Ghani al-Maqdisi',
    deathYearAh: 600,
    descKey: 'book_desc.umdat_al_ahkam',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/umdat_al_ahkam.json',
      sizeBytes: 234353,
      sourceLabel:
          'المكتبة الشاملة — العمدة في الأحكام، عبد الغني بن عبد الواحد '
          'المقدسي (ت ٦٠٠هـ)، تحقيق عبد المحسن بن محمد القاسم، الطبعة '
          'الثانية ١٤٤٢هـ/٢٠٢١م',
    ),
  ),
  LibraryBook(
    id: 'riyad_as_salihin',
    titleAr: 'رياض الصالحين',
    titleEn: 'Riyad as-Salihin',
    authorAr: 'الإمام أبو زكريا يحيى بن شرف النووي',
    authorEn: 'Imam Yahya ibn Sharaf an-Nawawi',
    deathYearAh: 676,
    descKey: 'book_desc.riyad_as_salihin',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/riyad_as_salihin.json',
      sizeBytes: 414968,
      sourceLabel:
          'المكتبة الشاملة — رياض الصالحين، تحقيق شعيب الأرنؤوط، '
          'مؤسسة الرسالة، بيروت، الطبعة الثالثة ١٤١٩هـ/١٩٩٨م',
    ),
  ),
  LibraryBook(
    id: 'mukhtasar_minhaj_al_qasidin',
    titleAr: 'مختصر منهاج القاصدين',
    titleEn: 'Mukhtasar Minhaj al-Qasidin',
    authorAr: 'الإمام موفق الدين ابن قدامة المقدسي',
    authorEn: 'Imam Ibn Qudamah al-Maqdisi',
    deathYearAh: 689,
    descKey: 'book_desc.mukhtasar_minhaj_al_qasidin',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/mukhtasar_minhaj_al_qasidin.json',
      sizeBytes: 323397,
      sourceLabel:
          'المكتبة الشاملة — مختصر منهاج القاصدين، تقديم محمد أحمد '
          'دهمان وتعليق شعيب وعبد القادر الأرناؤوط، مكتبة دار البيان، دمشق، '
          '١٣٩٨هـ/١٩٧٨م',
    ),
  ),
  LibraryBook(
    id: 'al_fawaid',
    titleAr: 'الفوائد',
    titleEn: 'Al-Fawaid',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    descKey: 'book_desc.al_fawaid',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_fawaid.json',
      sizeBytes: 189505,
      sourceLabel:
          'المكتبة الشاملة — الفوائد لابن القيم، دار الكتب العلمية، '
          'بيروت، الطبعة الثانية ١٣٩٣هـ/١٩٧٣م',
    ),
  ),
  LibraryBook(
    id: 'sayd_al_khatir',
    titleAr: 'صيد الخاطر',
    titleEn: 'Sayd al-Khatir',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    descKey: 'book_desc.sayd_al_khatir',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sayd_al_khatir.json',
      sizeBytes: 441609,
      sourceLabel:
          'المكتبة الشاملة — صيد الخاطر، بعناية حسن المساحي سويدان، '
          'دار القلم، دمشق، الطبعة الأولى ١٤٢٥هـ/٢٠٠٤م',
    ),
  ),
  LibraryBook(
    id: 'al_ubudiyyah',
    titleAr: 'العبودية',
    titleEn: "Al-'Ubudiyyah",
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    descKey: 'book_desc.al_ubudiyyah',
    category: BookCategory.aqidah,
    // Verified with curl -L GET on 2026-09-02: HTTP 200, application/pdf,
    // Content-Length 3382545 (item is an image-container scan; the underlying
    // text is public domain — Ibn Taymiyyah d. 728 AH — and the item carries
    // no license restriction).
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ubudiyyah.json',
      sizeBytes: 57117,
      sourceLabel:
          'المكتبة الشاملة — العبودية لابن تيمية، تحقيق محمد زهير '
          'الشاويش، المكتب الإسلامي، بيروت، الطبعة السابعة ١٤٢٦هـ/٢٠٠٥م',
    ),
  ),

  // --- P3-15 catalog expansion (2026-09-03): the owner asked to grow the
  // نص catalog for the authors originally requested back in P2-4 (Ibn
  // Taymiyyah, al-Hakim al-Tirmidhi, Ibn Abi al-Dunya) using the same
  // Shamela pipeline and reader design as the original 5 — نص-only, no
  // مصوّر hunted for these (owner's explicit call; `hasImage` is false,
  // downloadUrl left null, see the class doc above). Each built +
  // byte-verified on R2 the same way as the original 5's GitHub hosting was
  // (scripts/build_book_text.py -> scripts/r2_upload_new_books.py).
  LibraryBook(
    id: 'al_aqidah_al_wasitiyyah',
    titleAr: 'العقيدة الواسطية',
    titleEn: "Al-'Aqidah al-Wasitiyyah",
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    descKey: 'book_desc.al_aqidah_al_wasitiyyah',
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_aqidah_al_wasitiyyah.json',
      sizeBytes: 25695,
      sourceLabel:
          'المكتبة الشاملة — العقيدة الواسطية لابن تيمية، تحقيق '
          'أشرف بن عبد المقصود، أضواء السلف، الرياض، الطبعة الثانية '
          '١٤٢٠هـ/١٩٩٩م',
    ),
  ),
  LibraryBook(
    id: 'nawadir_al_usul',
    titleAr: 'نوادر الأصول في أحاديث الرسول',
    titleEn: 'Nawadir al-Usul',
    authorAr: 'الحكيم أبو عبد الله محمد بن علي الترمذي',
    authorEn: 'Al-Hakim al-Tirmidhi',
    deathYearAh: 320,
    deathApprox: true,
    descKey: 'book_desc.nawadir_al_usul',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nawadir_al_usul.json',
      sizeBytes: 638530,
      sourceLabel:
          'المكتبة الشاملة — نوادر الأصول في أحاديث الرسول للحكيم '
          'الترمذي، تحقيق عبد الرحمن عميرة، دار الجيل، بيروت (4 أجزاء)',
    ),
  ),
  LibraryBook(
    id: 'al_samt_wa_adab_al_lisan',
    titleAr: 'الصمت وآداب اللسان',
    titleEn: 'Al-Samt wa Adab al-Lisan',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    descKey: 'book_desc.al_samt_wa_adab_al_lisan',
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_samt_wa_adab_al_lisan.json',
      sizeBytes: 95133,
      sourceLabel:
          'المكتبة الشاملة — الصمت وآداب اللسان لابن أبي الدنيا، '
          'تحقيق أبو إسحاق الحويني الأثري، دار الكتاب العربي، بيروت، '
          'الطبعة الأولى ١٤١٠هـ/١٩٩٠م',
    ),
  ),
  // --- P3-43 #16 (2026-09-05): one more real title per already-established
  // author, نص-only — same safe default recorded in PHASE3.md (the owner's
  // "download them all, Shamela-style" ask was open-ended with no scope
  // answer given this round). Each Shamela id/edition verified directly
  // against its own landing page before being added (see
  // build_book_text.py's BOOKS dict comment) — real موافق-للمطبوع editions,
  // not guessed at.
  LibraryBook(
    id: 'qasr_al_amal',
    titleAr: 'قصر الأمل',
    titleEn: 'Qasr al-Amal',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    descKey: 'book_desc.qasr_al_amal',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/qasr_al_amal.json',
      sizeBytes: 66237,
      sourceLabel:
          'المكتبة الشاملة — قصر الأمل لابن أبي الدنيا، تحقيق محمد '
          'خير رمضان يوسف، دار ابن حزم، بيروت، الطبعة الثانية '
          '١٤١٧هـ/١٩٩٧م',
    ),
  ),
  LibraryBook(
    id: 'al_hasanah_wa_al_sayyiah',
    titleAr: 'الحسنة والسيئة',
    titleEn: 'Al-Hasanah wa al-Sayyi\'ah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    descKey: 'book_desc.al_hasanah_wa_al_sayyiah',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_hasanah_wa_al_sayyiah.json',
      sizeBytes: 90060,
      sourceLabel:
          'المكتبة الشاملة — الحسنة والسيئة لابن تيمية، دار الكتب '
          'العلمية، بيروت',
    ),
  ),
  LibraryBook(
    id: 'adab_al_nafs',
    titleAr: 'أدب النفس',
    titleEn: 'Adab al-Nafs',
    authorAr: 'الحكيم أبو عبد الله محمد بن علي الترمذي',
    authorEn: 'Al-Hakim al-Tirmidhi',
    deathYearAh: 320,
    deathApprox: true,
    descKey: 'book_desc.adab_al_nafs',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/adab_al_nafs.json',
      sizeBytes: 41163,
      sourceLabel:
          'المكتبة الشاملة — أدب النفس للحكيم الترمذي، تحقيق د. '
          'أحمد عبد الرحيم السايح، الدار المصرية اللبنانية، مصر، الطبعة '
          'الأولى ١٤١٣هـ/١٩٩٣م',
    ),
  ),
  // --- P3-44 (2026-09-05): 182 more real titles from the same 5
  // established authors (Ibn Abi al-Dunya, al-Hakim al-Tirmidhi, Ibn
  // Taymiyyah, Ibn al-Qayyim, Ibn al-Jawzi), fetched via the exact same
  // build_book_text.py pipeline and verified the same way (printMatches,
  // printReliable, zero empty pages checked for every one before being
  // added here). See scripts/fetch_authors_batch.py for exactly which
  // ids were pulled and which known multi-volume works were
  // deliberately excluded as too large for this per-page-walk pipeline.
  // The blurb here was the generated line (author + category +
  // real page count), not a hand-crafted blurb per title, the way the
  // ~11 already-curated books above have — not practical to write 182
  // individual ones by hand; still zero invented claims about content.
  LibraryBook(
    id: 'al_risalah_al_madaniyyah',
    titleAr:
        'الرسالة المدنية في تحقيق المجاز والحقيقة في صفات الله (مطبوع ضمن الفتوى الحموية الكبرى)',
    titleEn: 'Al Risalah Al Madaniyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 15,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_risalah_al_madaniyyah.json',
      sizeBytes: 14994,
      sourceLabel:
          'المكتبة الشاملة — الرسالة المدنية في تحقيق المجاز والحقيقة في صفات الله (مطبوع ضمن الفتوى الحموية الكبرى)، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، مطبعة المدني، القاهرة، مصر، تحقيق محمد عبد الرزاق حمزة [ت ١٣٩٢ هـ]',
    ),
  ),
  LibraryBook(
    id: 'masalah_fima_idha_kana_fil_abd_mahabbah',
    titleAr: 'مسألة فيما إذا كان في العبد محبة لما هو خير وحق ومحمود في نفسه',
    titleEn: 'Masalah Fima Idha Kana Fil Abd Mahabbah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 8,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/masalah_fima_idha_kana_fil_abd_mahabbah.json',
      sizeBytes: 5923,
      sourceLabel:
          'المكتبة الشاملة — مسألة فيما إذا كان في العبد محبة لما هو خير وحق ومحمود في نفسه، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، تحقيق د. محمد رشاد سالم',
    ),
  ),
  LibraryBook(
    id: 'islah_al_mal',
    titleAr: 'إصلاح المال',
    titleEn: 'Islah Al Mal',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 497,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/islah_al_mal.json',
      sizeBytes: 71787,
      sourceLabel:
          'المكتبة الشاملة — إصلاح المال، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية - بيروت - لبنان، تحقيق محمد عبد القادر عطا',
    ),
  ),
  LibraryBook(
    id: 'istina_al_maruf',
    titleAr: 'اصطناع المعروف',
    titleEn: 'Istina Al Maruf',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 182,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/istina_al_maruf.json',
      sizeBytes: 33566,
      sourceLabel:
          'المكتبة الشاملة — اصطناع المعروف، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم، تحقيق محمد خير رمضان يوسف',
    ),
  ),
  LibraryBook(
    id: 'al_amr_bil_maruf_ibn_abi_al_dunya',
    titleAr: 'الأمر بالمعروف والنهي عن المنكر',
    titleEn: 'Al Amr Bil Maruf Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 122,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_amr_bil_maruf_ibn_abi_al_dunya.json',
      sizeBytes: 32702,
      sourceLabel:
          'المكتبة الشاملة — الأمر بالمعروف والنهي عن المنكر، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مكتبة الغرباء الأثرية، السعودية',
    ),
  ),
  LibraryBook(
    id: 'asma_muallafat_ibn_taymiyyah',
    titleAr: 'أسماء مؤلفات شيخ الإسلام ابن تيمية',
    titleEn: 'Asma Muallafat Ibn Taymiyyah',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 23,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/asma_muallafat_ibn_taymiyyah.json',
      sizeBytes: 10838,
      sourceLabel:
          'المكتبة الشاملة — أسماء مؤلفات شيخ الإسلام ابن تيمية، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار الكتاب الجديد - بيروت، تحقيق د. صلاح الدين المنجد',
    ),
  ),
  LibraryBook(
    id: 'ighathat_al_lahfan_fi_hukm_talaq_al_ghadban',
    titleAr: 'إغاثة اللهفان في حكم طلاق الغضبان - ت الحفيان',
    titleEn: 'Ighathat Al Lahfan Fi Hukm Talaq Al Ghadban',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 111,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/ighathat_al_lahfan_fi_hukm_talaq_al_ghadban.json',
      sizeBytes: 60320,
      sourceLabel:
          'المكتبة الشاملة — إغاثة اللهفان في حكم طلاق الغضبان - ت الحفيان، شمس الدين محمد بن أبي بكر ابن قيم الجوزية (٦٩١ - ٧٥١ هـ)، مؤسسة الرسالة، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_amthal_fil_quran_ibn_al_qayyim',
    titleAr: 'الأمثال في القرآن [من «اعلام الموقعين»]',
    titleEn: 'Al Amthal Fil Quran Ibn Al Qayyim',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 58,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_amthal_fil_quran_ibn_al_qayyim.json',
      sizeBytes: 47368,
      sourceLabel:
          'المكتبة الشاملة — الأمثال في القرآن [من «اعلام الموقعين»]، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، مكتبة الصحابة - مصر، طنطا، تحقيق أبو حذيفة إبراهيم بن محمد',
    ),
  ),
  LibraryBook(
    id: 'al_ahwal',
    titleAr: 'الأهوال.',
    titleEn: 'Al Ahwal',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 271,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ahwal.json',
      sizeBytes: 53649,
      sourceLabel:
          'المكتبة الشاملة — الأهوال.، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، تحقيق مجدي فتحي السيد [ت ١٤٤٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_awliya_ibn_abi_al_dunya',
    titleAr: 'الأولياء',
    titleEn: 'Al Awliya Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 158,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_awliya_ibn_abi_al_dunya.json',
      sizeBytes: 40022,
      sourceLabel:
          'المكتبة الشاملة — الأولياء، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية - بيروت، تحقيق محمد السعيد بن بسيوني زغلول',
    ),
  ),
  LibraryBook(
    id: 'al_ikhlas_wal_niyyah',
    titleAr: 'الإخلاص والنية',
    titleEn: 'Al Ikhlas Wal Niyyah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 52,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ikhlas_wal_niyyah.json',
      sizeBytes: 11000,
      sourceLabel:
          'المكتبة الشاملة — الإخلاص والنية، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار البشائر',
    ),
  ),
  LibraryBook(
    id: 'al_tibyan_fi_aqsam_al_quran',
    titleAr: 'التبيان في أقسام القرآن',
    titleEn: 'Al Tibyan Fi Aqsam Al Quran',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 431,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_tibyan_fi_aqsam_al_quran.json',
      sizeBytes: 215494,
      sourceLabel:
          'المكتبة الشاملة — التبيان في أقسام القرآن، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، دار المعرفة، بيروت، لبنان، تحقيق محمد حامد الفقي [ت ١٣٧٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_ikhwan',
    titleAr: 'الإخوان',
    titleEn: 'Al Ikhwan',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 242,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ikhwan.json',
      sizeBytes: 31448,
      sourceLabel:
          'المكتبة الشاملة — الإخوان، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الكتب العلمية - بيروت، تحقيق مصطفى عبد القادر عطا',
    ),
  ),
  LibraryBook(
    id: 'al_jami_fi_amthal_al_quran',
    titleAr: 'الجامع في أمثال القرآن، للعلامة ابن القيم',
    titleEn: 'Al Jami Fi Amthal Al Quran',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 243,
    category: BookCategory.tafsir,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_jami_fi_amthal_al_quran.json',
      sizeBytes: 160115,
      sourceLabel:
          'المكتبة الشاملة — الجامع في أمثال القرآن، للعلامة ابن القيم، جمعه ورتبه ووثق نصوصه وحققه أبو أويس الكردي، راجعه وقدم له الشيخ مصطفى العدوي، مكتبة ابن تيمية، القاهرة، الطبعة الأولى ١٤٣٠هـ/٢٠٠٩م',
    ),
  ),
  LibraryBook(
    id: 'al_daa_wal_dawa',
    titleAr: 'الجواب الكافي لمن سأل عن الدواء الشافي أو الداء والدواء',
    titleEn: 'Al Daa Wal Dawa',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 237,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_daa_wal_dawa.json',
      sizeBytes: 259321,
      sourceLabel:
          'المكتبة الشاملة — الجواب الكافي لمن سأل عن الدواء الشافي أو الداء والدواء، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار المعرفة - المغرب',
    ),
  ),
  LibraryBook(
    id: 'al_risalah_al_tabukiyyah',
    titleAr: 'الرسالة التبوكية (ضمن مجموع الرسائل)',
    titleEn: 'Al Risalah Al Tabukiyyah',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 109,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_risalah_al_tabukiyyah.json',
      sizeBytes: 55557,
      sourceLabel:
          'المكتبة الشاملة — الرسالة التبوكية (ضمن مجموع الرسائل)، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٥٩ - ٧٥١)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق محمد عزير شمس',
    ),
  ),
  LibraryBook(
    id: 'al_ishraf_fi_manazil_al_ashraf',
    titleAr: 'الإشراف في منازل الأشراف',
    titleEn: 'Al Ishraf Fi Manazil Al Ashraf',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 518,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_ishraf_fi_manazil_al_ashraf.json',
      sizeBytes: 129158,
      sourceLabel:
          'المكتبة الشاملة — الإشراف في منازل الأشراف، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مكتبة الرشد - الرياض - السعودية، تحقيق د نجم عبد الرحمن خلف',
    ),
  ),
  LibraryBook(
    id: 'al_itibar_wa_aqab_al_surur',
    titleAr: 'الاعتبار وأعقاب السرور والأحزان',
    titleEn: 'Al Itibar Wa Aqab Al Surur',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 69,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_itibar_wa_aqab_al_surur.json',
      sizeBytes: 35112,
      sourceLabel:
          'المكتبة الشاملة — الاعتبار وأعقاب السرور والأحزان، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار البشير - عمان، تحقيق د. نجم عبد الرحمن خلف',
    ),
  ),
  LibraryBook(
    id: 'al_tawadu_wal_khumul',
    titleAr: 'التواضع والخمول',
    titleEn: 'Al Tawadu Wal Khumul',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 259,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_tawadu_wal_khumul.json',
      sizeBytes: 37223,
      sourceLabel:
          'المكتبة الشاملة — التواضع والخمول، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الكتب العلمية - بيروت، تحقيق محمد عبد القادر أحمد عطا',
    ),
  ),
  LibraryBook(
    id: 'al_ruh_ibn_al_qayyim',
    titleAr:
        'الروح في الكلام على أرواح الأموات والأحياء بالدلائل من الكتاب والسنة',
    titleEn: 'Al Ruh Ibn Al Qayyim',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 263,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ruh_ibn_al_qayyim.json',
      sizeBytes: 279665,
      sourceLabel:
          'المكتبة الشاملة — الروح في الكلام على أرواح الأموات والأحياء بالدلائل من الكتاب والسنة، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار الكتب العلمية - بيروت',
    ),
  ),
  LibraryBook(
    id: 'al_tawbah_ibn_abi_al_dunya',
    titleAr: 'كتاب التوبة.',
    titleEn: 'Al Tawbah Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 345,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_tawbah_ibn_abi_al_dunya.json',
      sizeBytes: 40663,
      sourceLabel:
          'المكتبة الشاملة — كتاب التوبة.، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)',
    ),
  ),
  LibraryBook(
    id: 'al_tawakkul_ala_allah',
    titleAr: 'مجموعة رسائل بان أبي الدنيا كتاب التوكل على الله',
    titleEn: 'Al Tawakkul Ala Allah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 62,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_tawakkul_ala_allah.json',
      sizeBytes: 16162,
      sourceLabel:
          'المكتبة الشاملة — مجموعة رسائل بان أبي الدنيا كتاب التوكل على الله، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_tibb_al_nabawi',
    titleAr: 'الطب النبوي (جزء من كتاب زاد المعاد لابن القيم)',
    titleEn: 'Al Tibb Al Nabawi',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 318,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_tibb_al_nabawi.json',
      sizeBytes: 306328,
      sourceLabel:
          'المكتبة الشاملة — الطب النبوي (جزء من كتاب زاد المعاد لابن القيم)، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار الهلال - بيروت',
    ),
  ),
  LibraryBook(
    id: 'al_turuq_al_hukmiyyah',
    titleAr: 'الطرق الحكمية',
    titleEn: 'Al Turuq Al Hukmiyyah',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 274,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_turuq_al_hukmiyyah.json',
      sizeBytes: 283198,
      sourceLabel:
          'المكتبة الشاملة — الطرق الحكمية، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، مكتبة دار البيان',
    ),
  ),
  LibraryBook(
    id: 'al_ju',
    titleAr: 'الجوع',
    titleEn: 'Al Ju',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 550,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ju.json',
      sizeBytes: 55006,
      sourceLabel:
          'المكتبة الشاملة — الجوع، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم، بيروت لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_hilm',
    titleAr: 'الحلم',
    titleEn: 'Al Hilm',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 148,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_hilm.json',
      sizeBytes: 23086,
      sourceLabel:
          'المكتبة الشاملة — الحلم، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية - بيروت، تحقيق محمد عبد القادر أحمد عطا',
    ),
  ),
  LibraryBook(
    id: 'al_rida_an_allah_biqadaihi',
    titleAr: 'الرضا عن الله بقضائه',
    titleEn: 'Al Rida An Allah Biqadaihi',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 150,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_rida_an_allah_biqadaihi.json',
      sizeBytes: 23482,
      sourceLabel:
          'المكتبة الشاملة — الرضا عن الله بقضائه، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، الدار السلفية - بومباي، تحقيق ضياء الحسن السلفي',
    ),
  ),
  LibraryBook(
    id: 'al_furusiyyah_al_muhammadiyyah',
    titleAr: 'الفروسية المحمدية',
    titleEn: 'Al Furusiyyah Al Muhammadiyyah',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 530,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_furusiyyah_al_muhammadiyyah.json',
      sizeBytes: 257949,
      sourceLabel:
          'المكتبة الشاملة — الفروسية المحمدية، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٩١ - ٧٥١)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق زائد بن أحمد النشيري',
    ),
  ),
  LibraryBook(
    id: 'al_riqqah_wal_buka',
    titleAr: 'الرقة والبكاء',
    titleEn: 'Al Riqqah Wal Buka',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 446,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_riqqah_wal_buka.json',
      sizeBytes: 74705,
      sourceLabel:
          'المكتبة الشاملة — الرقة والبكاء، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)',
    ),
  ),
  LibraryBook(
    id: 'al_kalam_ala_masalat_al_sama',
    titleAr: 'الكلام على مسألة السماع',
    titleEn: 'Al Kalam Ala Masalat Al Sama',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 508,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_kalam_ala_masalat_al_sama.json',
      sizeBytes: 283113,
      sourceLabel:
          'المكتبة الشاملة — الكلام على مسألة السماع، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٩١ - ٧٥١ هـ)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق محمد عزير شمس',
    ),
  ),
  LibraryBook(
    id: 'al_zuhd_ibn_abi_al_dunya',
    titleAr: 'الزهد لابن أبي الدنيا',
    titleEn: 'Al Zuhd Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 563,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_zuhd_ibn_abi_al_dunya.json',
      sizeBytes: 151171,
      sourceLabel:
          'المكتبة الشاملة — الزهد لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن كثير، دمشق',
    ),
  ),
  LibraryBook(
    id: 'al_manar_al_munif',
    titleAr: 'المنار المنيف في الصحيح والضعيف',
    titleEn: 'Al Manar Al Munif',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 135,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_manar_al_munif.json',
      sizeBytes: 53006,
      sourceLabel:
          'المكتبة الشاملة — المنار المنيف في الصحيح والضعيف، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، مكتبة المطبوعات الإسلامية، حلب، تحقيق عبد الفتاح أبو غدة',
    ),
  ),
  LibraryBook(
    id: 'al_wabil_al_sayyib',
    titleAr: 'الوابل الصيب من الكلم الطيب',
    titleEn: 'Al Wabil Al Sayyib',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 148,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_wabil_al_sayyib.json',
      sizeBytes: 108669,
      sourceLabel:
          'المكتبة الشاملة — الوابل الصيب من الكلم الطيب، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار الحديث - القاهرة',
    ),
  ),
  LibraryBook(
    id: 'al_shukr',
    titleAr: 'الشكر',
    titleEn: 'Al Shukr',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 205,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_shukr.json',
      sizeBytes: 44284,
      sourceLabel:
          'المكتبة الشاملة — الشكر، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، المكتب الإسلامي - الكويت، تحقيق بدر البدر',
    ),
  ),
  LibraryBook(
    id: 'al_sabr_wal_thawab_alayh',
    titleAr: 'الصبر والثواب عليه',
    titleEn: 'Al Sabr Wal Thawab Alayh',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 200,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_sabr_wal_thawab_alayh.json',
      sizeBytes: 52452,
      sourceLabel:
          'المكتبة الشاملة — الصبر والثواب عليه، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'tuhfat_al_mawdud_bi_ahkam_al_mawlud',
    titleAr: 'تحفة المودود بأحكام المولود',
    titleEn: 'Tuhfat Al Mawdud Bi Ahkam Al Mawlud',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 309,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tuhfat_al_mawdud_bi_ahkam_al_mawlud.json',
      sizeBytes: 142798,
      sourceLabel:
          'المكتبة الشاملة — تحفة المودود بأحكام المولود، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، مكتبة دار البيان - دمشق، تحقيق عبد القادر الأرناؤوط [ت ١٤٢٥ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_uzlah_wal_infirad',
    titleAr: 'العزلة والانفراد',
    titleEn: 'Al Uzlah Wal Infirad',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 225,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_uzlah_wal_infirad.json',
      sizeBytes: 71914,
      sourceLabel:
          'المكتبة الشاملة — العزلة والانفراد، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (المتوفى : ٢٨١هـ)',
    ),
  ),
  LibraryBook(
    id: 'al_aql_wa_fadluh',
    titleAr: 'العقل وفضله',
    titleEn: 'Al Aql Wa Fadluh',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 172,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_aql_wa_fadluh.json',
      sizeBytes: 19551,
      sourceLabel:
          'المكتبة الشاملة — العقل وفضله، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مكتبة القرآن - مصر',
    ),
  ),
  LibraryBook(
    id: 'jala_al_afham',
    titleAr: 'جلاء الأفهام في فضل الصلاة على محمد خير الأنام',
    titleEn: 'Jala Al Afham',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 451,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/jala_al_afham.json',
      sizeBytes: 197432,
      sourceLabel:
          'المكتبة الشاملة — جلاء الأفهام في فضل الصلاة على محمد خير الأنام، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، دار العروبة - الكويت، تحقيق شعيب الأرناؤوط [ت ١٤٣٨ هـ]- عبد القادر الأرناؤوط [ت ١٤٢٥ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_uqubat',
    titleAr: 'العقوبات',
    titleEn: 'Al Uqubat',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 426,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_uqubat.json',
      sizeBytes: 86364,
      sourceLabel:
          'المكتبة الشاملة — العقوبات، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_umr_wal_shayb',
    titleAr: 'العمر والشيب',
    titleEn: 'Al Umr Wal Shayb',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 86,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_umr_wal_shayb.json',
      sizeBytes: 16757,
      sourceLabel:
          'المكتبة الشاملة — العمر والشيب، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مكتبة الرشد - الرياض، تحقيق د. نجم عبد الله خلف',
    ),
  ),
  LibraryBook(
    id: 'al_faraj_bad_al_shiddah',
    titleAr: 'الفرج بعد الشدة',
    titleEn: 'Al Faraj Bad Al Shiddah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 115,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_faraj_bad_al_shiddah.json',
      sizeBytes: 38017,
      sourceLabel:
          'المكتبة الشاملة — الفرج بعد الشدة، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الريان للتراث، مصر',
    ),
  ),
  LibraryBook(
    id: 'hadi_al_arwah_ila_bilad_al_afrah',
    titleAr: 'حادي الأرواح إلى بلاد الأفراح',
    titleEn: 'Hadi Al Arwah Ila Bilad Al Afrah',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 415,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/hadi_al_arwah_ila_bilad_al_afrah.json',
      sizeBytes: 253896,
      sourceLabel:
          'المكتبة الشاملة — حادي الأرواح إلى بلاد الأفراح، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، مطبعة المدني، القاهرة',
    ),
  ),
  LibraryBook(
    id: 'risalat_ibn_al_qayyim_ila_ahad_ikhwanih',
    titleAr: 'رسالة ابن القيم إلى أحد إخوانه',
    titleEn: 'Risalat Ibn Al Qayyim Ila Ahad Ikhwanih',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 84,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/risalat_ibn_al_qayyim_ila_ahad_ikhwanih.json',
      sizeBytes: 42711,
      sourceLabel:
          'المكتبة الشاملة — رسالة ابن القيم إلى أحد إخوانه، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٥٩ - ٧٥١)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق عبد الله بن محمد المديفر',
    ),
  ),
  LibraryBook(
    id: 'al_qubur_ibn_abi_al_dunya',
    titleAr: 'القبور لابن أبي الدنيا',
    titleEn: 'Al Qubur Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 275,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_qubur_ibn_abi_al_dunya.json',
      sizeBytes: 46269,
      sourceLabel:
          'المكتبة الشاملة — القبور لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مكتبة الغرباء الأثرية، تحقيق طارق محمد سكلوع العمود',
    ),
  ),
  LibraryBook(
    id: 'al_qanaah_wal_taaffuf',
    titleAr: 'القناعة والتعفف',
    titleEn: 'Al Qanaah Wal Taaffuf',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 64,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_qanaah_wal_taaffuf.json',
      sizeBytes: 36462,
      sourceLabel:
          'المكتبة الشاملة — القناعة والتعفف، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'raf_al_yadayn_fil_salah',
    titleAr: 'رفع اليدين في الصلاة',
    titleEn: 'Raf Al Yadayn Fil Salah',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 343,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/raf_al_yadayn_fil_salah.json',
      sizeBytes: 174034,
      sourceLabel:
          'المكتبة الشاملة — رفع اليدين في الصلاة، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٩١ - ٧٥١)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق علي بن محمد العمران',
    ),
  ),
  LibraryBook(
    id: 'al_mutamannin',
    titleAr: 'المتمنين',
    titleEn: 'Al Mutamannin',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 166,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_mutamannin.json',
      sizeBytes: 32897,
      sourceLabel:
          'المكتبة الشاملة — المتمنين، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم - بيروت - لبنان، تحقيق محمد خير رمضان يوسف',
    ),
  ),
  LibraryBook(
    id: 'al_muhtadirin',
    titleAr: 'المحتضرين',
    titleEn: 'Al Muhtadirin',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 369,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_muhtadirin.json',
      sizeBytes: 70631,
      sourceLabel:
          'المكتبة الشاملة — المحتضرين، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم - بيروت - لبنان، تحقيق محمد خير رمضان يوسف',
    ),
  ),
  LibraryBook(
    id: 'rawdat_al_muhibbin',
    titleAr: 'روضة المحبين ونزهة المشتاقين',
    titleEn: 'Rawdat Al Muhibbin',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 482,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/rawdat_al_muhibbin.json',
      sizeBytes: 253708,
      sourceLabel:
          'المكتبة الشاملة — روضة المحبين ونزهة المشتاقين، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، دار الكتب العلمية، بيروت، لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_marad_wal_kaffarat',
    titleAr: 'المرض والكفارات',
    titleEn: 'Al Marad Wal Kaffarat',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 261,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_marad_wal_kaffarat.json',
      sizeBytes: 53979,
      sourceLabel:
          'المكتبة الشاملة — المرض والكفارات، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، الدار السلفية - بومباي، تحقيق عبد الوكيل الندوي',
    ),
  ),
  LibraryBook(
    id: 'shifa_al_alil',
    titleAr: 'شفاء العليل في مسائل القضاء والقدر والحكمة والتعليل',
    titleEn: 'Shifa Al Alil',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 333,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/shifa_al_alil.json',
      sizeBytes: 430536,
      sourceLabel:
          'المكتبة الشاملة — شفاء العليل في مسائل القضاء والقدر والحكمة والتعليل، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار المعرفة، بيروت، لبنان',
    ),
  ),
  LibraryBook(
    id: 'sifat_al_munafiqin',
    titleAr: 'صفات المنافقين',
    titleEn: 'Sifat Al Munafiqin',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 20,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sifat_al_munafiqin.json',
      sizeBytes: 12998,
      sourceLabel:
          'المكتبة الشاملة — صفات المنافقين، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، الكتاب منشور على موقع وزارة الأوقاف السعودية بدون بيانات',
    ),
  ),
  LibraryBook(
    id: 'sigh_al_hamd',
    titleAr: 'جواب في صيغ الحمد',
    titleEn: 'Sigh Al Hamd',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 48,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sigh_al_hamd.json',
      sizeBytes: 12575,
      sourceLabel:
          'المكتبة الشاملة — جواب في صيغ الحمد، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، دار العاصمة - الرياض، تحقيق محمد بن إبراهيم السعران',
    ),
  ),
  LibraryBook(
    id: 'al_matar_wal_rad_wal_barq',
    titleAr: 'المطر والرعد والبرق',
    titleEn: 'Al Matar Wal Rad Wal Barq',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 185,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_matar_wal_rad_wal_barq.json',
      sizeBytes: 31259,
      sourceLabel:
          'المكتبة الشاملة — المطر والرعد والبرق، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)',
    ),
  ),
  LibraryBook(
    id: 'al_manamat',
    titleAr: 'المنامات',
    titleEn: 'Al Manamat',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 465,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_manamat.json',
      sizeBytes: 80401,
      sourceLabel:
          'المكتبة الشاملة — المنامات، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، مؤسسة الكتب الثقافية - بيروت، تحقيق عبد القادر أحمد عطا [ت ١٤٠٣ هـ]',
    ),
  ),
  LibraryBook(
    id: 'tariq_al_hijratayn',
    titleAr: 'طريق الهجرتين وباب السعادتين',
    titleEn: 'Tariq Al Hijratayn',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 443,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tariq_al_hijratayn.json',
      sizeBytes: 410533,
      sourceLabel:
          'المكتبة الشاملة — طريق الهجرتين وباب السعادتين، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، الدار السلفية، القاهرة، مصر',
    ),
  ),
  LibraryBook(
    id: 'uddat_al_sabirin',
    titleAr: 'عدة الصابرين وذخيرة الشاكرين',
    titleEn: 'Uddat Al Sabirin',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 301,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/uddat_al_sabirin.json',
      sizeBytes: 197679,
      sourceLabel:
          'المكتبة الشاملة — عدة الصابرين وذخيرة الشاكرين، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١ هـ)، دار ابن كثير، دمشق، بيروت/مكتبة دار التراث، المدينة المنورة، المملكة العربية السعودية',
    ),
  ),
  LibraryBook(
    id: 'faidah_jalilah_fi_qawaid_al_asma_al_husna',
    titleAr: 'فائدة جليلة في قواعد الأسماء الحسنى',
    titleEn: 'Faidah Jalilah Fi Qawaid Al Asma Al Husna',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 59,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/faidah_jalilah_fi_qawaid_al_asma_al_husna.json',
      sizeBytes: 19691,
      sourceLabel:
          'المكتبة الشاملة — فائدة جليلة في قواعد الأسماء الحسنى، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، غراس، الكويت، تحقيق عبد الرزاق بن عبد المحسن البدر',
    ),
  ),
  LibraryBook(
    id: 'fatya_fi_sighat_al_hamd',
    titleAr: 'فتيا في صيغة الحمد «الحمد لله حمدا يوافي نعمه ويكافئ مزيده»',
    titleEn: 'Fatya Fi Sighat Al Hamd',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 61,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/fatya_fi_sighat_al_hamd.json',
      sizeBytes: 31592,
      sourceLabel:
          'المكتبة الشاملة — فتيا في صيغة الحمد «الحمد لله حمدا يوافي نعمه ويكافئ مزيده»، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٥٩ - ٧٥١)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)',
    ),
  ),
  LibraryBook(
    id: 'al_nafaqah_ala_al_iyal',
    titleAr: 'العيال ويقع في مجلدين',
    titleEn: 'Al Nafaqah Ala Al Iyal',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 701,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_nafaqah_ala_al_iyal.json',
      sizeBytes: 99663,
      sourceLabel:
          'المكتبة الشاملة — العيال ويقع في مجلدين، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن القيم - السعودية - الدمام، تحقيق د نجم عبد الرحمن خلف',
    ),
  ),
  LibraryBook(
    id: 'al_hamm_wal_huzn',
    titleAr: 'الهم والحزن',
    titleEn: 'Al Hamm Wal Huzn',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 252,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_hamm_wal_huzn.json',
      sizeBytes: 31181,
      sourceLabel:
          'المكتبة الشاملة — الهم والحزن، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، دار السلام - القاهرة، تحقيق مجدي فتحي السيد [ت ١٤٤٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'nuniyyat_ibn_al_qayyim',
    titleAr: 'متن القصيدة النونية',
    titleEn: 'Nuniyyat Ibn Al Qayyim',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 423,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nuniyyat_ibn_al_qayyim.json',
      sizeBytes: 167771,
      sourceLabel:
          'المكتبة الشاملة — متن القصيدة النونية، محمد بن أبي بكر بن أيوب بن سعد شمس الدين ابن قيم الجوزية (ت ٧٥١هـ)، مكتبة ابن تيمية، القاهرة',
    ),
  ),
  LibraryBook(
    id: 'al_hawatif',
    titleAr: 'هواتف الجنان',
    titleEn: 'Al Hawatif',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 178,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_hawatif.json',
      sizeBytes: 65143,
      sourceLabel:
          'المكتبة الشاملة — هواتف الجنان، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، المكتب الإسلامي، تحقيق محمد الزغلي',
    ),
  ),
  LibraryBook(
    id: 'al_wajal_wal_tawthuq_bil_amal',
    titleAr: 'الوجل والتوثق بالعمل',
    titleEn: 'Al Wajal Wal Tawthuq Bil Amal',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 52,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_wajal_wal_tawthuq_bil_amal.json',
      sizeBytes: 21217,
      sourceLabel:
          'المكتبة الشاملة — الوجل والتوثق بالعمل، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الوطن - الرياض، تحقيق مشهور حسن آل سلمان',
    ),
  ),
  LibraryBook(
    id: 'al_wara',
    titleAr: 'الورع',
    titleEn: 'Al Wara',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 243,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_wara.json',
      sizeBytes: 36963,
      sourceLabel:
          'المكتبة الشاملة — الورع، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، الدار السلفية - الكويت، تحقيق أبي عبد الله محمد بن حمد الحمود',
    ),
  ),
  LibraryBook(
    id: 'al_yaqin_ibn_abi_al_dunya',
    titleAr: 'اليقين لابن أبي الدنيا',
    titleEn: 'Al Yaqin Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 42,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_yaqin_ibn_abi_al_dunya.json',
      sizeBytes: 12180,
      sourceLabel:
          'المكتبة الشاملة — اليقين لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار البشائر الإسلامية',
    ),
  ),
  LibraryBook(
    id: 'hidayat_al_hayara',
    titleAr: 'هداية الحيارى في أجوبة اليهود والنصارى',
    titleEn: 'Hidayat Al Hayara',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 517,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/hidayat_al_hayara.json',
      sizeBytes: 317587,
      sourceLabel:
          'المكتبة الشاملة — هداية الحيارى في أجوبة اليهود والنصارى، أبو عبد الله محمد بن أبي بكر بن أيوب ابن قيم الجوزية (٦٩١ - ٧٥١)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)',
    ),
  ),
  LibraryBook(
    id: 'husn_al_zann_billah',
    titleAr: 'حسن الظن بالله',
    titleEn: 'Husn Al Zann Billah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 152,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/husn_al_zann_billah.json',
      sizeBytes: 38472,
      sourceLabel:
          'المكتبة الشاملة — حسن الظن بالله، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار طيبة - الرياض، تحقيق مخلص محمد',
    ),
  ),
  LibraryBook(
    id: 'hilm_muawiyah',
    titleAr: 'حلم معاوية لابن أبي الدنيا',
    titleEn: 'Hilm Muawiyah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 40,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/hilm_muawiyah.json',
      sizeBytes: 9591,
      sourceLabel:
          'المكتبة الشاملة — حلم معاوية لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، دار البشائر',
    ),
  ),
  LibraryBook(
    id: 'dhamm_al_baghy',
    titleAr: 'ذم البغى لابن أبي الدنيا',
    titleEn: 'Dhamm Al Baghy',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 57,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/dhamm_al_baghy.json',
      sizeBytes: 14160,
      sourceLabel:
          'المكتبة الشاملة — ذم البغى لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الراية للنشر والتوزيع، الرياض - السعودية',
    ),
  ),
  LibraryBook(
    id: 'akhbar_al_humqa_wal_mughaffalin',
    titleAr: 'أخبار الحمقى والمغفلين',
    titleEn: 'Akhbar Al Humqa Wal Mughaffalin',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 192,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/akhbar_al_humqa_wal_mughaffalin.json',
      sizeBytes: 104638,
      sourceLabel:
          'المكتبة الشاملة — أخبار الحمقى والمغفلين، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار الفكر اللبناني',
    ),
  ),
  LibraryBook(
    id: 'akhbar_al_zuraf_wal_mutamajinin',
    titleAr: 'أخبار الظراف والمتماجنين',
    titleEn: 'Akhbar Al Zuraf Wal Mutamajinin',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 116,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/akhbar_al_zuraf_wal_mutamajinin.json',
      sizeBytes: 55745,
      sourceLabel:
          'المكتبة الشاملة — أخبار الظراف والمتماجنين، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧ هـ)، دار ابن حزم - بيروت، تحقيق بسام عبد الوهاب الجابي [ت ١٤٣٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'akhbar_al_nisa_ibn_al_jawzi',
    titleAr: 'أخبار النساء',
    titleEn: 'Akhbar Al Nisa Ibn Al Jawzi',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 242,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/akhbar_al_nisa_ibn_al_jawzi.json',
      sizeBytes: 130801,
      sourceLabel:
          'المكتبة الشاملة — أخبار النساء، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ) (منسوب خطأ في المطبوع لابن قيم الجوزية)، دار مكتبة الحياة، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'dhamm_al_dunya',
    titleAr: 'ذم الدنيا',
    titleEn: 'Dhamm Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 503,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/dhamm_al_dunya.json',
      sizeBytes: 75485,
      sourceLabel:
          'المكتبة الشاملة — ذم الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية',
    ),
  ),
  LibraryBook(
    id: 'amar_al_ayan',
    titleAr: 'أعمار الأعيان',
    titleEn: 'Amar Al Ayan',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 191,
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/amar_al_ayan.json',
      sizeBytes: 142955,
      sourceLabel:
          'المكتبة الشاملة — أعمار الأعيان، ابن الجوزي، جمال الدين أبي الفرج عبد الرحمن بن علي بن محمد (٥١٠ هـ - ٥٩٧ هـ)، مكتبة الخانجي، القاهرة، تحقيق د محمود محمد الطناحي',
    ),
  ),
  LibraryBook(
    id: 'ikhbar_ahl_al_rusukh_fil_fiqh',
    titleAr: 'إخبار أهل الرسوخ في الفقه والتحديث بمقدار المنسوخ من الحديث',
    titleEn: 'Ikhbar Ahl Al Rusukh Fil Fiqh',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 38,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/ikhbar_ahl_al_rusukh_fil_fiqh.json',
      sizeBytes: 7716,
      sourceLabel:
          'المكتبة الشاملة — إخبار أهل الرسوخ في الفقه والتحديث بمقدار المنسوخ من الحديث، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مكتبة ابن حجر للنشر والتوزيع، مكة المكرمة',
    ),
  ),
  LibraryBook(
    id: 'dhamm_al_ghibah_wal_namimah',
    titleAr: 'ذم الغيبة والنميمة',
    titleEn: 'Dhamm Al Ghibah Wal Namimah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 171,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/dhamm_al_ghibah_wal_namimah.json',
      sizeBytes: 23125,
      sourceLabel:
          'المكتبة الشاملة — ذم الغيبة والنميمة، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، مكتبة دار البيان، دمشق - سورية، مكتبة المؤيد، الرياض - السعودية',
    ),
  ),
  LibraryBook(
    id: 'dhamm_al_muskir',
    titleAr: 'كتاب ذم المسكر',
    titleEn: 'Dhamm Al Muskir',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 99,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/dhamm_al_muskir.json',
      sizeBytes: 16211,
      sourceLabel:
          'المكتبة الشاملة — كتاب ذم المسكر، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الراية - الرياض، تحقيق د. نجم عبد الرحمن خلف',
    ),
  ),
  LibraryBook(
    id: 'dhamm_al_malahi',
    titleAr: 'ذم الملاهي لابن أبي الدنيا',
    titleEn: 'Dhamm Al Malahi',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 183,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/dhamm_al_malahi.json',
      sizeBytes: 27880,
      sourceLabel:
          'المكتبة الشاملة — ذم الملاهي لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مكتبة ابن تيمية، القاهرة- مصر، مكتبة العلم، جدة - السعودية',
    ),
  ),
  LibraryBook(
    id: 'ilam_al_alim_bi_naskh_al_hadith',
    titleAr: 'إعلام العالم بعد رسوخه بناسخ الحديث ومنسوخه',
    titleEn: 'Ilam Al Alim Bi Naskh Al Hadith',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 386,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/ilam_al_alim_bi_naskh_al_hadith.json',
      sizeBytes: 70892,
      sourceLabel:
          'المكتبة الشاملة — إعلام العالم بعد رسوخه بناسخ الحديث ومنسوخه، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، ابن حزم، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'sifat_al_jannah_ibn_abi_al_dunya',
    titleAr: 'صفة الجنة وما أعد الله لأهلها من النعيم',
    titleEn: 'Sifat Al Jannah Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 366,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/sifat_al_jannah_ibn_abi_al_dunya.json',
      sizeBytes: 72807,
      sourceLabel:
          'المكتبة الشاملة — صفة الجنة وما أعد الله لأهلها من النعيم، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار البشير - مؤسسة الرسالة، تحقيق عبد الرحيم أحمد عبد الرحيم العساسلة',
    ),
  ),
  LibraryBook(
    id: 'al_adhkiya',
    titleAr: 'كتاب الأذكياء',
    titleEn: 'Al Adhkiya',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 241,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_adhkiya.json',
      sizeBytes: 199882,
      sourceLabel:
          'المكتبة الشاملة — كتاب الأذكياء، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مكتبة الغزالي',
    ),
  ),
  LibraryBook(
    id: 'sifat_al_nar',
    titleAr: 'صفة النار',
    titleEn: 'Sifat Al Nar',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 268,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sifat_al_nar.json',
      sizeBytes: 47617,
      sourceLabel:
          'المكتبة الشاملة — صفة النار، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم - لبنان / بيروت، تحقيق محمد خير رمضان يوسف',
    ),
  ),
  LibraryBook(
    id: 'fadail_ramadan_ibn_abi_al_dunya',
    titleAr: 'فضائل رمضان',
    titleEn: 'Fadail Ramadan Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 66,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/fadail_ramadan_ibn_abi_al_dunya.json',
      sizeBytes: 13063,
      sourceLabel:
          'المكتبة الشاملة — فضائل رمضان، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار السلف، الرياض - السعودية',
    ),
  ),
  LibraryBook(
    id: 'al_birr_wal_silah_ibn_al_jawzi',
    titleAr: 'البر والصلة لابن الجوزي',
    titleEn: 'Al Birr Wal Silah Ibn Al Jawzi',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 225,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_birr_wal_silah_ibn_al_jawzi.json',
      sizeBytes: 121041,
      sourceLabel:
          'المكتبة الشاملة — البر والصلة لابن الجوزي، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مؤسسة الكتب الثقافية، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'qira_al_dayf',
    titleAr: 'قرى الضيف',
    titleEn: 'Qira Al Dayf',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 67,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/qira_al_dayf.json',
      sizeBytes: 22640,
      sourceLabel:
          'المكتبة الشاملة — قرى الضيف، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، أضواء السلف، الرياض - السعودية',
    ),
  ),
  LibraryBook(
    id: 'qada_al_hawaij',
    titleAr: 'قضاء الحوائج',
    titleEn: 'Qada Al Hawaij',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 118,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/qada_al_hawaij.json',
      sizeBytes: 23359,
      sourceLabel:
          'المكتبة الشاملة — قضاء الحوائج، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، مكتبة القرآن - القاهرة، تحقيق مجدي السيد إبراهيم [ت ١٤٤٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'kalam_al_layali_wal_ayyam',
    titleAr: 'كلام الليالي والأيام',
    titleEn: 'Kalam Al Layali Wal Ayyam',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 65,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/kalam_al_layali_wal_ayyam.json',
      sizeBytes: 17461,
      sourceLabel:
          'المكتبة الشاملة — كلام الليالي والأيام، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_tadhkirah_fil_waz',
    titleAr: 'التذكرة في الوعظ',
    titleEn: 'Al Tadhkirah Fil Waz',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 214,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_tadhkirah_fil_waz.json',
      sizeBytes: 117016,
      sourceLabel:
          'المكتبة الشاملة — التذكرة في الوعظ، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار المعرفة - بيروت، تحقيق أحمد عبد الوهاب فتيح',
    ),
  ),
  LibraryBook(
    id: 'mujabu_al_dawah',
    titleAr: 'مجابو الدعوة (مطبوع ضمن مجموعة رسائل ابن أبي الدنيا)',
    titleEn: 'Mujabu Al Dawah',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 194,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/mujabu_al_dawah.json',
      sizeBytes: 44041,
      sourceLabel:
          'المكتبة الشاملة — مجابو الدعوة (مطبوع ضمن مجموعة رسائل ابن أبي الدنيا)، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_thabat_ind_al_mamat',
    titleAr: 'الثبات عند الممات',
    titleEn: 'Al Thabat Ind Al Mamat',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 157,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_thabat_ind_al_mamat.json',
      sizeBytes: 65536,
      sourceLabel:
          'المكتبة الشاملة — الثبات عند الممات، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مؤسسة الكتب الثقافية - بيروت، تحقيق عبد الله الليثي الأنصاري',
    ),
  ),
  LibraryBook(
    id: 'al_hathth_ala_hifz_al_ilm',
    titleAr: 'الحث على حفظ العلم وذكر كبار الحفاظ',
    titleEn: 'Al Hathth Ala Hifz Al Ilm',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 72,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_hathth_ala_hifz_al_ilm.json',
      sizeBytes: 30455,
      sourceLabel:
          'المكتبة الشاملة — الحث على حفظ العلم وذكر كبار الحفاظ، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مؤسسة شباب الجامعة، الاسكندرية',
    ),
  ),
  LibraryBook(
    id: 'muhasabat_al_nafs',
    titleAr: 'محاسبة النفس لابن أبي الدنيا',
    titleEn: 'Muhasabat Al Nafs',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 155,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/muhasabat_al_nafs.json',
      sizeBytes: 32473,
      sourceLabel:
          'المكتبة الشاملة — محاسبة النفس لابن أبي الدنيا، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار الكتب العلمية، بيروت',
    ),
  ),
  LibraryBook(
    id: 'mudarat_al_nas',
    titleAr: 'مداراة الناس',
    titleEn: 'Mudarat Al Nas',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 187,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/mudarat_al_nas.json',
      sizeBytes: 27689,
      sourceLabel:
          'المكتبة الشاملة — مداراة الناس، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، دار ابن حزم - بيروت - لبنان، تحقيق محمد خير رمضان يوسف',
    ),
  ),
  LibraryBook(
    id: 'al_qussas_wal_mudhakkirin',
    titleAr: 'القصاص والمذكرين',
    titleEn: 'Al Qussas Wal Mudhakkirin',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 209,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_qussas_wal_mudhakkirin.json',
      sizeBytes: 85876,
      sourceLabel:
          'المكتبة الشاملة — القصاص والمذكرين، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، المكتب الإسلامي - بيروت، تحقيق د. محمد لطفي الصباغ',
    ),
  ),
  LibraryBook(
    id: 'maqtal_ali',
    titleAr: 'مقتل أمير المؤمنين علي بن أبي طالب عليه السلام',
    titleEn: 'Maqtal Ali',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 143,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/maqtal_ali.json',
      sizeBytes: 26728,
      sourceLabel:
          'المكتبة الشاملة — مقتل أمير المؤمنين علي بن أبي طالب عليه السلام، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، دار البشائر - دمشق، تحقيق إبراهيم صالح [ت ١٤٤٣ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_mujtaba_min_al_mujtana',
    titleAr: 'المجتبى من المجتنى',
    titleEn: 'Al Mujtaba Min Al Mujtana',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 97,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_mujtaba_min_al_mujtana.json',
      sizeBytes: 60233,
      sourceLabel:
          'المكتبة الشاملة — المجتبى من المجتنى، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، :دار الآفاق العربية - القاهرة، تحقيق أيمن عبد الجابر البحيري',
    ),
  ),
  LibraryBook(
    id: 'makaid_al_shaytan',
    titleAr: 'مكائد الشيطان',
    titleEn: 'Makaid Al Shaytan',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 129,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/makaid_al_shaytan.json',
      sizeBytes: 23743,
      sourceLabel:
          'المكتبة الشاملة — مكائد الشيطان، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)',
    ),
  ),
  LibraryBook(
    id: 'makarim_al_akhlaq_ibn_abi_al_dunya',
    titleAr: 'مكارم الأخلاق',
    titleEn: 'Makarim Al Akhlaq Ibn Abi Al Dunya',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 490,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/makarim_al_akhlaq_ibn_abi_al_dunya.json',
      sizeBytes: 97004,
      sourceLabel:
          'المكتبة الشاملة — مكارم الأخلاق، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١ هـ)، مكتبة القرآن - القاهرة، تحقيق مجدي السيد إبراهيم [ت ١٤٤٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'man_asha_bad_al_mawt',
    titleAr: 'كتاب من عاش بعد الموت',
    titleEn: 'Man Asha Bad Al Mawt',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    deathYearAh: 281,
    pages: 56,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/man_asha_bad_al_mawt.json',
      sizeBytes: 31772,
      sourceLabel:
          'المكتبة الشاملة — كتاب من عاش بعد الموت، أبو بكر عبد الله بن محمد بن عبيد بن سفيان بن قيس البغدادي الأموي القرشي المعروف بابن أبي الدنيا (ت ٢٨١هـ)، مؤسسة الكتب الثقافية - بيروت، تحقيق محمد حسام بيضون',
    ),
  ),
  LibraryBook(
    id: 'riyadat_al_nafs',
    titleAr: 'رياضة النفس',
    titleEn: 'Riyadat Al Nafs',
    authorAr: 'الحكيم أبو عبد الله محمد بن علي الترمذي',
    authorEn: 'Al-Hakim al-Tirmidhi',
    deathYearAh: 320,
    deathApprox: true,
    pages: 48,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/riyadat_al_nafs.json',
      sizeBytes: 28891,
      sourceLabel:
          'المكتبة الشاملة — رياضة النفس، محمد بن علي بن الحسن بن بشر، أبو عبد الله، الحكيم الترمذي (ت نحو ٣٢٠هـ)، دار الكتب العلمية، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_mudhish',
    titleAr: 'المدهش',
    titleEn: 'Al Mudhish',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 530,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_mudhish.json',
      sizeBytes: 350507,
      sourceLabel:
          'المكتبة الشاملة — المدهش، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار الكتب العلمية - بيروت - لبنان، تحقيق الدكتور مروان قباني',
    ),
  ),
  LibraryBook(
    id: 'al_musaffa_bi_akuff_ahl_al_rusukh',
    titleAr: 'المصفى بأكف أهل الرسوخ من علم الناسخ والمنسوخ',
    titleEn: 'Al Musaffa Bi Akuff Ahl Al Rusukh',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 50,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_musaffa_bi_akuff_ahl_al_rusukh.json',
      sizeBytes: 27559,
      sourceLabel:
          'المكتبة الشاملة — المصفى بأكف أهل الرسوخ من علم الناسخ والمنسوخ، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧ هـ)، مؤسسة الرسالة، تحقيق حاتم صالح الضامن [ت ١٤٣٤ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_manahi',
    titleAr: 'المنهيات',
    titleEn: 'Al Manahi',
    authorAr: 'الحكيم أبو عبد الله محمد بن علي الترمذي',
    authorEn: 'Al-Hakim al-Tirmidhi',
    deathYearAh: 320,
    deathApprox: true,
    pages: 233,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_manahi.json',
      sizeBytes: 87037,
      sourceLabel:
          'المكتبة الشاملة — المنهيات، محمد بن علي بن الحسن بن بشر، أبو عبد الله، الحكيم الترمذي (ت نحو ٣٢٠هـ)، مكتبة القرآن للطبع والنشر والتوزيع -القاهرة، مصر، تحقيق محمد عثمان الخشت',
    ),
  ),
  LibraryBook(
    id: 'al_muqliq_ibn_al_jawzi',
    titleAr: 'المقلق',
    titleEn: 'Al Muqliq Ibn Al Jawzi',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 122,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_muqliq_ibn_al_jawzi.json',
      sizeBytes: 25680,
      sourceLabel:
          'المكتبة الشاملة — المقلق، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧ هـ)، دار الصحابة للتراث بطنطا، تحقيق مجدي فتحي السيد [ت ١٤٤٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'bahr_al_dumu',
    titleAr: 'بحر الدموع',
    titleEn: 'Bahr Al Dumu',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 150,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/bahr_al_dumu.json',
      sizeBytes: 93452,
      sourceLabel:
          'المكتبة الشاملة — بحر الدموع، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار الفجر للتراث، تحقيق جمال محمود مصطفى',
    ),
  ),
  LibraryBook(
    id: 'al_amthal_min_al_kitab_wal_sunnah',
    titleAr: 'الأمثال من الكتاب والسنة',
    titleEn: 'Al Amthal Min Al Kitab Wal Sunnah',
    authorAr: 'الحكيم أبو عبد الله محمد بن علي الترمذي',
    authorEn: 'Al-Hakim al-Tirmidhi',
    deathYearAh: 320,
    deathApprox: true,
    pages: 318,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_amthal_min_al_kitab_wal_sunnah.json',
      sizeBytes: 152312,
      sourceLabel:
          'المكتبة الشاملة — الأمثال من الكتاب والسنة، محمد بن علي بن الحسن بن بشر، أبو عبد الله، الحكيم الترمذي (ت نحو ٣٢٠هـ)، دار ابن زيدون / دار أسامة - بيروت - دمشق، تحقيق د. السيد الجميلي',
    ),
  ),
  LibraryBook(
    id: 'ahadith_al_qusas',
    titleAr: 'أحاديث القصاص',
    titleEn: 'Ahadith Al Qusas',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 44,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/ahadith_al_qusas.json',
      sizeBytes: 12703,
      sourceLabel:
          'المكتبة الشاملة — أحاديث القصاص، شيخ الإسلام تقي الدين أحمد بن عبد الحليم ابن تيمية، المكتب الإسلامي، بيروت - لبنان، تحقيق د. محمد بن لطفي الصباغ',
    ),
  ),
  LibraryBook(
    id: 'amrad_al_qulub_wa_shifauha',
    titleAr: 'أمراض القلب وشفاؤها',
    titleEn: 'Amrad Al Qulub Wa Shifauha',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 78,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/amrad_al_qulub_wa_shifauha.json',
      sizeBytes: 80052,
      sourceLabel:
          'المكتبة الشاملة — أمراض القلب وشفاؤها، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المطبعة السلفية - القاهرة',
    ),
  ),
  LibraryBook(
    id: 'al_arbaun_al_taymiyyah',
    titleAr: 'الأربعون التيمية',
    titleEn: 'Al Arbaun Al Taymiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 58,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_arbaun_al_taymiyyah.json',
      sizeBytes: 16212,
      sourceLabel:
          'المكتبة الشاملة — الأربعون التيمية، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مؤسسة الريان للتراث، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'bustan_al_waizin',
    titleAr: 'بستان الواعظين ورياض السامعين',
    titleEn: 'Bustan Al Waizin',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 301,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/bustan_al_waizin.json',
      sizeBytes: 259973,
      sourceLabel:
          'المكتبة الشاملة — بستان الواعظين ورياض السامعين، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مؤسسة الكتب الثقافية - بيروت - لبنان، تحقيق أيمن البحيري',
    ),
  ),
  LibraryBook(
    id: 'al_amr_bil_maruf_ibn_taymiyyah',
    titleAr: 'الأمر بالمعروف والنهي عن المنكر',
    titleEn: 'Al Amr Bil Maruf Ibn Taymiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 58,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_amr_bil_maruf_ibn_taymiyyah.json',
      sizeBytes: 34739,
      sourceLabel:
          'المكتبة الشاملة — الأمر بالمعروف والنهي عن المنكر، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، وزارة الشئون الإسلامية والأوقاف والدعوة والإرشاد - المملكة العربية السعودية',
    ),
  ),
  LibraryBook(
    id: 'tarikh_bayt_al_maqdis',
    titleAr: 'تاريخ بيت المقدس',
    titleEn: 'Tarikh Bayt Al Maqdis',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 40,
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tarikh_bayt_al_maqdis.json',
      sizeBytes: 15476,
      sourceLabel:
          'المكتبة الشاملة — تاريخ بيت المقدس، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مكتبة الثقافة الدينية، تحقيق محمد زينهم محمد عزب',
    ),
  ),
  LibraryBook(
    id: 'al_ikhnaiyyah',
    titleAr: 'الرد على الأخنائي قاضي المالكية',
    titleEn: 'Al Ikhnaiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 247,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ikhnaiyyah.json',
      sizeBytes: 237090,
      sourceLabel:
          'المكتبة الشاملة — الرد على الأخنائي قاضي المالكية، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المكتبة العصرية - بيروت، تحقيق الداني بن منير آل زهوي',
    ),
  ),
  LibraryBook(
    id: 'al_iklil_fi_al_mutashabih_wal_tawil',
    titleAr: 'الإكليل في المتشابه والتأويل',
    titleEn: 'Al Iklil Fi Al Mutashabih Wal Tawil',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 48,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_iklil_fi_al_mutashabih_wal_tawil.json',
      sizeBytes: 21022,
      sourceLabel:
          'المكتبة الشاملة — الإكليل في المتشابه والتأويل، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار الإيمان للطبع والنشر والتوزيع، الإسكندرية - مصر',
    ),
  ),
  LibraryBook(
    id: 'tadhkirat_al_arib_fi_tafsir_al_gharib',
    titleAr: 'تذكرة الأريب في تفسير الغريب (غريب القرآن الكريم)',
    titleEn: 'Tadhkirat Al Arib Fi Tafsir Al Gharib',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 466,
    category: BookCategory.tafsir,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tadhkirat_al_arib_fi_tafsir_al_gharib.json',
      sizeBytes: 153045,
      sourceLabel:
          'المكتبة الشاملة — تذكرة الأريب في تفسير الغريب (غريب القرآن الكريم)، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار الكتب العلمية، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'tazim_al_fatya',
    titleAr: 'تعظيم الفتيا',
    titleEn: 'Tazim Al Fatya',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 63,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tazim_al_fatya.json',
      sizeBytes: 12467,
      sourceLabel:
          'المكتبة الشاملة — تعظيم الفتيا، جمال الدين أبو الفرج عبد الرحمن بن محمد بن علي الشهير بـ ابن الجوزي (٥١٠ - ٥٩٧ هـ)، الدار الأثرية، عمان - الأردن، تحقيق أبو عبيدة مشهور بن حسن آل سلمان',
    ),
  ),
  LibraryBook(
    id: 'al_iman_ibn_taymiyyah',
    titleAr: 'الإيمان',
    titleEn: 'Al Iman Ibn Taymiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 357,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_iman_ibn_taymiyyah.json',
      sizeBytes: 269015,
      sourceLabel:
          'المكتبة الشاملة — الإيمان، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المكتب الإسلامي، عمان، الأردن، تحقيق محمد ناصر الدين الألباني',
    ),
  ),
  LibraryBook(
    id: 'taqwim_al_lisan',
    titleAr: 'تقويم اللسان',
    titleEn: 'Taqwim Al Lisan',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 140,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/taqwim_al_lisan.json',
      sizeBytes: 40196,
      sourceLabel:
          'المكتبة الشاملة — تقويم اللسان، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧ هـ)، دار المعارف، تحقيق د. عبد العزيز مطر (أستاذ علم اللغة بجامعتي عين شمس وقطر)',
    ),
  ),
  LibraryBook(
    id: 'al_intisar_li_ahl_al_athar',
    titleAr: 'الانتصار لأهل الأثر المطبوع باسم «نقض المنطق»',
    titleEn: 'Al Intisar Li Ahl Al Athar',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 390,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_intisar_li_ahl_al_athar.json',
      sizeBytes: 256986,
      sourceLabel:
          'المكتبة الشاملة — الانتصار لأهل الأثر المطبوع باسم «نقض المنطق»، شيخ الإسلام أحمد بن عبد الحليم بن عبد السلام ابن تيمية (٦٦١ - ٧٢٨ هـ)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق عبد الرحمن بن حسن قائد',
    ),
  ),
  LibraryBook(
    id: 'al_tuhfah_al_iraqiyyah',
    titleAr: 'التحفة العراقية في الأعمال القلبية',
    titleEn: 'Al Tuhfah Al Iraqiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 44,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_tuhfah_al_iraqiyyah.json',
      sizeBytes: 49042,
      sourceLabel:
          'المكتبة الشاملة — التحفة العراقية في الأعمال القلبية، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المطبعة السلفية - القاهرة',
    ),
  ),
  LibraryBook(
    id: 'talbis_iblis',
    titleAr: 'تلبيس إبليس',
    titleEn: 'Talbis Iblis',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 419,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/talbis_iblis.json',
      sizeBytes: 329697,
      sourceLabel:
          'المكتبة الشاملة — تلبيس إبليس، عبد الرحمن بن علي بن محمد ابن الجوزي (ت ٥٩٧ هـ)، دار الفكر، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_tadmuriyyah',
    titleAr:
        'التدمرية: تحقيق الإثبات للأسماء والصفات وحقيقة الجمع بين القدر والشرع',
    titleEn: 'Al Tadmuriyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 242,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_tadmuriyyah.json',
      sizeBytes: 75727,
      sourceLabel:
          'المكتبة الشاملة — التدمرية: تحقيق الإثبات للأسماء والصفات وحقيقة الجمع بين القدر والشرع، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، مكتبة العبيكان - الرياض، تحقيق د. محمد بن عودة السعوي',
    ),
  ),
  LibraryBook(
    id: 'al_hisbah_fil_islam',
    titleAr: 'الحسبة في الإسلام، أو وظيفة الحكومة الإسلامية',
    titleEn: 'Al Hisbah Fil Islam',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 56,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_hisbah_fil_islam.json',
      sizeBytes: 39558,
      sourceLabel:
          'المكتبة الشاملة — الحسبة في الإسلام، أو وظيفة الحكومة الإسلامية، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار الكتب العلمية',
    ),
  ),
  LibraryBook(
    id: 'al_radd_ala_man_qala_bi_fana_al_jannah_wal_nar',
    titleAr: 'الرد على من قال بفناء الجنة والنار وبيان الأقوال في ذلك',
    titleEn: 'Al Radd Ala Man Qala Bi Fana Al Jannah Wal Nar',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 80,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_radd_ala_man_qala_bi_fana_al_jannah_wal_nar.json',
      sizeBytes: 46073,
      sourceLabel:
          'المكتبة الشاملة — الرد على من قال بفناء الجنة والنار وبيان الأقوال في ذلك، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار بلنسية - الرياض، تحقيق محمد بن عبد الله السمهري',
    ),
  ),
  LibraryBook(
    id: 'al_risalah_al_akmaliyyah',
    titleAr: 'الرسالة الأكملية في ما يجب لله من صفات الكمال',
    titleEn: 'Al Risalah Al Akmaliyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 71,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_risalah_al_akmaliyyah.json',
      sizeBytes: 33846,
      sourceLabel:
          'المكتبة الشاملة — الرسالة الأكملية في ما يجب لله من صفات الكمال، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مطبعة المدني، المؤسسة السعودية، القاهرة، مصر',
    ),
  ),
  LibraryBook(
    id: 'al_risalah_al_arshiyyah',
    titleAr: 'الرسالة العرشية',
    titleEn: 'Al Risalah Al Arshiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 38,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_risalah_al_arshiyyah.json',
      sizeBytes: 28109,
      sourceLabel:
          'المكتبة الشاملة — الرسالة العرشية، تقي الدين أبو العَباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، المطبعة السلفية، القاهرة، مصر',
    ),
  ),
  LibraryBook(
    id: 'al_zuhd_wal_wara_wal_ibadah',
    titleAr: 'الزهد والورع والعبادة',
    titleEn: 'Al Zuhd Wal Wara Wal Ibadah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 186,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_zuhd_wal_wara_wal_ibadah.json',
      sizeBytes: 102997,
      sourceLabel:
          'المكتبة الشاملة — الزهد والورع والعبادة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مكتبة المنار - الأردن، تحقيق حماد سلامة , محمد عويضة',
    ),
  ),
  LibraryBook(
    id: 'al_siyasah_al_shariyyah',
    titleAr: 'السياسة الشرعية',
    titleEn: 'Al Siyasah Al Shariyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 130,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_siyasah_al_shariyyah.json',
      sizeBytes: 104720,
      sourceLabel:
          'المكتبة الشاملة — السياسة الشرعية، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، وزارة الشئون الإسلامية والأوقاف والدعوة والإرشاد - المملكة العربية السعودية',
    ),
  ),
  LibraryBook(
    id: 'al_furqan_bayn_awliya_al_rahman_wa_awliya_al_shaytan',
    titleAr: 'الفرقان بين أولياء الرحمن وأولياء الشيطان',
    titleEn: 'Al Furqan Bayn Awliya Al Rahman Wa Awliya Al Shaytan',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 196,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_furqan_bayn_awliya_al_rahman_wa_awliya_al_shaytan.json',
      sizeBytes: 78625,
      sourceLabel: 'المكتبة الشاملة',
    ),
  ),
  LibraryBook(
    id: 'talqih_fuhum_ahl_al_athar',
    titleAr: 'تلقيح فهوم أهل الأثر في عيون التاريخ والسير',
    titleEn: 'Talqih Fuhum Ahl Al Athar',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 521,
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/talqih_fuhum_ahl_al_athar.json',
      sizeBytes: 359234,
      sourceLabel:
          'المكتبة الشاملة — تلقيح فهوم أهل الأثر في عيون التاريخ والسير، جمال الدين أبي الفرج عبد الرحمن ابن الجوزي [٥٠٨هـ - ٥٩٧هـ]، شركة دار الأرقم بن أبي الأرقم - بيروت',
    ),
  ),
  LibraryBook(
    id: 'al_qasidah_al_taiyyah_fil_qadar',
    titleAr: 'القصيدة التائية في القدر',
    titleEn: 'Al Qasidah Al Taiyyah Fil Qadar',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 51,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_qasidah_al_taiyyah_fil_qadar.json',
      sizeBytes: 8827,
      sourceLabel:
          'المكتبة الشاملة — القصيدة التائية في القدر، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار ابن خزيمة - الرياض',
    ),
  ),
  LibraryBook(
    id: 'tanbih_al_naim_al_ghamr',
    titleAr: 'تنبيه النائم الغمر على مواسم العمر',
    titleEn: 'Tanbih Al Naim Al Ghamr',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 41,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tanbih_al_naim_al_ghamr.json',
      sizeBytes: 9734,
      sourceLabel:
          'المكتبة الشاملة — تنبيه النائم الغمر على مواسم العمر، جمال الدين أبو الفرج عبد الرحمن بن علي ابن الجوزي، دار ابن حزم للطباعة والنشر والتوزيع، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_kalim_al_tayyib',
    titleAr: 'الكلم الطيب',
    titleEn: 'Al Kalim Al Tayyib',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 88,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_kalim_al_tayyib.json',
      sizeBytes: 29129,
      sourceLabel:
          'المكتبة الشاملة — الكلم الطيب، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار الفكر اللبناني للطباعة والنشر، بيروت',
    ),
  ),
  LibraryBook(
    id: 'tanwir_al_ghabash',
    titleAr: 'تنوير الغبش في فضل السودان والحبش',
    titleEn: 'Tanwir Al Ghabash',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 233,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tanwir_al_ghabash.json',
      sizeBytes: 94872,
      sourceLabel:
          'المكتبة الشاملة — تنوير الغبش في فضل السودان والحبش، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار الشريف - الرياض / السعودية، تحقيق مرزوق علي إبراهيم',
    ),
  ),
  LibraryBook(
    id: 'hifz_al_umr',
    titleAr: 'حفظ العمر',
    titleEn: 'Hifz Al Umr',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 42,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/hifz_al_umr.json',
      sizeBytes: 19319,
      sourceLabel:
          'المكتبة الشاملة — حفظ العمر، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار البشائر الإسلامية، تحقيق محمد بن ناصر العجمي',
    ),
  ),
  LibraryBook(
    id: 'takhrij_al_kalim_al_tayyib',
    titleAr: 'الكلم الطيب',
    titleEn: 'Takhrij Al Kalim Al Tayyib',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 311,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/takhrij_al_kalim_al_tayyib.json',
      sizeBytes: 28670,
      sourceLabel:
          'المكتبة الشاملة — الكلم الطيب، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المكتب الإسلامي - بيروت',
    ),
  ),
  LibraryBook(
    id: 'fadail_bayt_al_maqdis',
    titleAr: 'فضائل بيت المقدس',
    titleEn: 'Fadail Bayt Al Maqdis',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 119,
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/fadail_bayt_al_maqdis.json',
      sizeBytes: 62170,
      sourceLabel:
          'المكتبة الشاملة — فضائل بيت المقدس، أبو الفرج جمال الدين ابن الجوزي (٥٠٨ - ٥٩٧ هـ)، مكتبة الإمام البخاري للنشر والتوزيع، القاهرة - مصر',
    ),
  ),
  LibraryBook(
    id: 'al_masail_al_maridiniyyah',
    titleAr:
        'المسَائِلُ الماردينيَّةِ - وهي مسائل يكثر وقوعها ويحصل الابتلاء بها',
    titleEn: 'Al Masail Al Maridiniyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 252,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_masail_al_maridiniyyah.json',
      sizeBytes: 134184,
      sourceLabel:
          'المكتبة الشاملة — المسَائِلُ الماردينيَّةِ - وهي مسائل يكثر وقوعها ويحصل الابتلاء بها، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، دار الفلاح، مصر',
    ),
  ),
  LibraryBook(
    id: 'al_nusayriyyah_tughat_suriya',
    titleAr: 'النصيرية طغاة سورية أو العلويون كما سماهم الفرنسيون',
    titleEn: 'Al Nusayriyyah Tughat Suriya',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 27,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_nusayriyyah_tughat_suriya.json',
      sizeBytes: 10436,
      sourceLabel:
          'المكتبة الشاملة — النصيرية طغاة سورية أو العلويون كما سماهم الفرنسيون، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار الافتاء، الرياض، المملكة العربية السعودية',
    ),
  ),
  LibraryBook(
    id: 'al_wasitah_bayn_al_haqq_wal_khalq',
    titleAr: 'الواسطة بين الحق والخلق',
    titleEn: 'Al Wasitah Bayn Al Haqq Wal Khalq',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 34,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_wasitah_bayn_al_haqq_wal_khalq.json',
      sizeBytes: 13930,
      sourceLabel:
          'المكتبة الشاملة — الواسطة بين الحق والخلق، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مطابع الجامعة الإسلامية، المدينة النبوية، المملكة العربية السعودية، تحقيق محمد بن جميل زينو',
    ),
  ),
  LibraryBook(
    id: 'funun_al_afnan_fi_uyun_ulum_al_quran',
    titleAr: 'فنون الأفنان في عيون علوم القرآن',
    titleEn: 'Funun Al Afnan Fi Uyun Ulum Al Quran',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 341,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/funun_al_afnan_fi_uyun_ulum_al_quran.json',
      sizeBytes: 64893,
      sourceLabel:
          'المكتبة الشاملة — فنون الأفنان في عيون علوم القرآن، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)',
    ),
  ),
  LibraryBook(
    id: 'tahqiq_al_iman',
    titleAr: 'الإيمان',
    titleEn: 'Tahqiq Al Iman',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 167,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tahqiq_al_iman.json',
      sizeBytes: 10488,
      sourceLabel:
          'المكتبة الشاملة — الإيمان، تقي الدين أبو العباس أحمد بن عبد الحليم بن تيمية (ت ٧٢٨هـ)، المكتب الإسلامي - بيروت',
    ),
  ),
  LibraryBook(
    id: 'tahqiq_al_ihtijaj_bil_qadar',
    titleAr: 'الاحتجاج بالقدر',
    titleEn: 'Tahqiq Al Ihtijaj Bil Qadar',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 27,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tahqiq_al_ihtijaj_bil_qadar.json',
      sizeBytes: 3577,
      sourceLabel:
          'المكتبة الشاملة — الاحتجاج بالقدر، تقي الدين أبو العباس أحمد بن عبد الحليم بن تيمية (ت ٧٢٨هـ)، المكتب الإسلامي - بيروت',
    ),
  ),
  LibraryBook(
    id: 'tahqiq_al_qawl_fi_isa_kalimat_allah',
    titleAr: 'تحقيق القول في مسألة: عيسى كلمة الله والقرآن كلام الله',
    titleEn: 'Tahqiq Al Qawl Fi Isa Kalimat Allah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 47,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tahqiq_al_qawl_fi_isa_kalimat_allah.json',
      sizeBytes: 12988,
      sourceLabel:
          'المكتبة الشاملة — تحقيق القول في مسألة: عيسى كلمة الله والقرآن كلام الله، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار الصحابة للتراث - طنطا (مصر)، تحقيق قسم التحقيق بدار النشر',
    ),
  ),
  LibraryBook(
    id: 'jawab_al_itiradat_al_misriyyah',
    titleAr: 'جواب الاعتراضات المصرية على الفتيا الحموية',
    titleEn: 'Jawab Al Itiradat Al Misriyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 194,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/jawab_al_itiradat_al_misriyyah.json',
      sizeBytes: 135382,
      sourceLabel:
          'المكتبة الشاملة — جواب الاعتراضات المصرية على الفتيا الحموية، شيخ الإسلام أحمد بن عبد الحليم بن عبد السلام بن تيمية (٦٦١ - ٧٢٨ هـ)، دار عطاءات العلم (الرياض) - دار ابن حزم (بيروت)، تحقيق محمد عزير شمس',
    ),
  ),
  LibraryBook(
    id: 'jawab_fi_al_half_bighayr_allah',
    titleAr:
        'جواب في الحلف بغير الله والصلاة إلى القبور، ويليه: فصل في الاستغاثة',
    titleEn: 'Jawab Fi Al Half Bighayr Allah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 27,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/jawab_fi_al_half_bighayr_allah.json',
      sizeBytes: 10137,
      sourceLabel:
          'المكتبة الشاملة — جواب في الحلف بغير الله والصلاة إلى القبور، ويليه: فصل في الاستغاثة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، (طبع في الكويت)',
    ),
  ),
  LibraryBook(
    id: 'hijab_al_marah_wa_libasuha_fil_salah',
    titleAr: 'حجاب المرأة ولباسها في الصلاة',
    titleEn: 'Hijab Al Marah Wa Libasuha Fil Salah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 46,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/hijab_al_marah_wa_libasuha_fil_salah.json',
      sizeBytes: 23557,
      sourceLabel:
          'المكتبة الشاملة — حجاب المرأة ولباسها في الصلاة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المكتب الإسلامي، تحقيق محمد ناصر الدين الألباني',
    ),
  ),
  LibraryBook(
    id: 'muthir_al_gharam_al_sakin',
    titleAr: 'مثير الغرام الساكن إلى أشرف الأماكن لابن الجوزي',
    titleEn: 'Muthir Al Gharam Al Sakin',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 465,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/muthir_al_gharam_al_sakin.json',
      sizeBytes: 267942,
      sourceLabel:
          'المكتبة الشاملة — مثير الغرام الساكن إلى أشرف الأماكن لابن الجوزي، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، دار الحديث، القاهرة',
    ),
  ),
  LibraryBook(
    id: 'huquq_al_al_al_bayt',
    titleAr: 'حقوق آل البيت',
    titleEn: 'Huquq Al Al Al Bayt',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 65,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/huquq_al_al_al_bayt.json',
      sizeBytes: 37826,
      sourceLabel:
          'المكتبة الشاملة — حقوق آل البيت، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، دار الكتب العلمية بيروت ـ لبنان، تحقيق عبد القادر أحمد عطا [ت ١٤٠٣ هـ]',
    ),
  ),
  LibraryBook(
    id: 'ras_al_husayn',
    titleAr: 'رأس الحسين',
    titleEn: 'Ras Al Husayn',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 38,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/ras_al_husayn.json',
      sizeBytes: 28581,
      sourceLabel:
          'المكتبة الشاملة — رأس الحسين، تقي الدين أبو العباس أحمد بن عبد الحليم بن تيمية الحراني (ت ٧٢٨ هـ)',
    ),
  ),
  LibraryBook(
    id: 'risalah_fi_usul_al_din',
    titleAr: 'رسالة في أصول الدين',
    titleEn: 'Risalah Fi Usul Al Din',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 34,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/risalah_fi_usul_al_din.json',
      sizeBytes: 21433,
      sourceLabel:
          'المكتبة الشاملة — رسالة في أصول الدين، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، -',
    ),
  ),
  LibraryBook(
    id: 'mashyakhat_ibn_al_jawzi',
    titleAr: 'مشيخة ابن الجوزي',
    titleEn: 'Mashyakhat Ibn Al Jawzi',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 150,
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/mashyakhat_ibn_al_jawzi.json',
      sizeBytes: 46300,
      sourceLabel:
          'المكتبة الشاملة — مشيخة ابن الجوزي، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧ هـ)، دار الغرب الإسلامي، بيروت',
    ),
  ),
  LibraryBook(
    id: 'risalah_fi_fadl_al_khulafa_al_rashidin',
    titleAr:
        'رسالة في فضل الخلفاء الراشدين (طبعت مفردة، ومنها نسخة مختصرة في مجموع الفتاوى)',
    titleEn: 'Risalah Fi Fadl Al Khulafa Al Rashidin',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 30,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/risalah_fi_fadl_al_khulafa_al_rashidin.json',
      sizeBytes: 7568,
      sourceLabel:
          'المكتبة الشاملة — رسالة في فضل الخلفاء الراشدين (طبعت مفردة، ومنها نسخة مختصرة في مجموع الفتاوى)، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار الصحابة للتراث، مصر',
    ),
  ),
  LibraryBook(
    id: 'mawaiz_ibn_al_jawzi_al_yaqutah',
    titleAr: 'الياقوتة - مواعظ ابن الجوزي',
    titleEn: 'Mawaiz Ibn Al Jawzi Al Yaqutah',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 27,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/mawaiz_ibn_al_jawzi_al_yaqutah.json',
      sizeBytes: 30404,
      sourceLabel:
          'المكتبة الشاملة — الياقوتة - مواعظ ابن الجوزي، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)',
    ),
  ),
  LibraryBook(
    id: 'raf_al_malam_an_al_aimmah_al_alam',
    titleAr: 'رفع الملام عن الأئمة الأعلام',
    titleEn: 'Raf Al Malam An Al Aimmah Al Alam',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 87,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/raf_al_malam_an_al_aimmah_al_alam.json',
      sizeBytes: 54019,
      sourceLabel:
          'المكتبة الشاملة — رفع الملام عن الأئمة الأعلام، تقي الدين أبو العَباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)',
    ),
  ),
  LibraryBook(
    id: 'ziyarat_al_qubur_wal_istinjad_bil_maqbur',
    titleAr: 'زيارة القبور والاستنجاد بالمقبور',
    titleEn: 'Ziyarat Al Qubur Wal Istinjad Bil Maqbur',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 78,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/ziyarat_al_qubur_wal_istinjad_bil_maqbur.json',
      sizeBytes: 24672,
      sourceLabel:
          'المكتبة الشاملة — زيارة القبور والاستنجاد بالمقبور، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار طيبة، الرياض، المملكة العربية السعودية',
    ),
  ),
  LibraryBook(
    id: 'sujud_al_tilawah',
    titleAr: 'سجود التلاوة معانيه وأحكامه',
    titleEn: 'Sujud Al Tilawah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 82,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sujud_al_tilawah.json',
      sizeBytes: 20841,
      sourceLabel:
          'المكتبة الشاملة — سجود التلاوة معانيه وأحكامه، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار ابن حزم، بيروت، لبنان، تحقيق فواز أحمد زمرلي',
    ),
  ),
  LibraryBook(
    id: 'nawasikh_al_quran',
    titleAr: 'نواسخ القرآن = ناسخ القرآن ومنسوخه',
    titleEn: 'Nawasikh Al Quran',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 211,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nawasikh_al_quran.json',
      sizeBytes: 148074,
      sourceLabel:
          'المكتبة الشاملة — نواسخ القرآن = ناسخ القرآن ومنسوخه، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، شركه أبناء شريف الأنصارى - بيروت، تحقيق أبو عبد الله العاملي السّلفي الداني بن منير آل زهوي',
    ),
  ),
  LibraryBook(
    id: 'sunnat_al_jumuah',
    titleAr: 'سنة الجمعة',
    titleEn: 'Sunnat Al Jumuah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 64,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sunnat_al_jumuah.json',
      sizeBytes: 8392,
      sourceLabel:
          'المكتبة الشاملة — سنة الجمعة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار ابن حزم، بيروت، لبنان، تحقيق أبو عبد الله سعد المزعل',
    ),
  ),
  LibraryBook(
    id: 'sharh_al_aqidah_al_isfahaniyyah',
    titleAr: 'شرح العقيدة الأصفهانية',
    titleEn: 'Sharh Al Aqidah Al Isfahaniyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 224,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/sharh_al_aqidah_al_isfahaniyyah.json',
      sizeBytes: 205581,
      sourceLabel:
          'المكتبة الشاملة — شرح العقيدة الأصفهانية، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، المكتبة العصرية - بيروت، تحقيق محمد بن رياض الأحمد',
    ),
  ),
  LibraryBook(
    id: 'sharh_hadith_al_nuzul',
    titleAr: 'شرح حديث النزول',
    titleEn: 'Sharh Hadith Al Nuzul',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 188,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sharh_hadith_al_nuzul.json',
      sizeBytes: 137735,
      sourceLabel:
          'المكتبة الشاملة — شرح حديث النزول، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، المكتب الإسلامي، بيروت، لبنان',
    ),
  ),
  LibraryBook(
    id: 'sharh_umdat_al_fiqh_sifat_al_salah',
    titleAr: 'كتاب صفة الصلاة من شرح العمدة للإمام موفق الدين ابن قدامة',
    titleEn: 'Sharh Umdat Al Fiqh Sifat Al Salah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 190,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/sharh_umdat_al_fiqh_sifat_al_salah.json',
      sizeBytes: 55672,
      sourceLabel:
          'المكتبة الشاملة — كتاب صفة الصلاة من شرح العمدة للإمام موفق الدين ابن قدامة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، دار العاصمة - الرياض، تحقيق عبد العزيز بن أحمد بن محمد بن حمود المشيقح',
    ),
  ),
  LibraryBook(
    id: 'fasl_fi_tazkiyat_al_nafs',
    titleAr: 'فصل في تزكية النفس [الطبعة الكاملة للرسالة]',
    titleEn: 'Fasl Fi Tazkiyat Al Nafs',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 60,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/fasl_fi_tazkiyat_al_nafs.json',
      sizeBytes: 28538,
      sourceLabel:
          'المكتبة الشاملة — فصل في تزكية النفس [الطبعة الكاملة للرسالة]، شيخ الإسلام أبو العباس أحمد بن عبد الحليم ابن تيمية الحراني (٦٦١ - ٧٢٨ هـ)، مكتبة النهج الواضح - الكويت',
    ),
  ),
  LibraryBook(
    id: 'fadl_abi_bakr_al_siddiq',
    titleAr: 'فضل أبي بكر الصديق رضي الله عنه',
    titleEn: 'Fadl Abi Bakr Al Siddiq',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 33,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/fadl_abi_bakr_al_siddiq.json',
      sizeBytes: 29841,
      sourceLabel:
          'المكتبة الشاملة — فضل أبي بكر الصديق رضي الله عنه، تقي الدين أبو العَباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مجلة جامعة أم القرى لعلوم الشريعة، تحقيق د. عبد العزيز بن محمد الفريح',
    ),
  ),
  LibraryBook(
    id: 'qaidah_dhikr_malabis_al_nabi',
    titleAr:
        'قاعدة تتضمن ذكر ملابس النبي صلى الله عليه وسلم وسلاحه ودوابه - القرمانية - جواب فتيا في لبس النبي صلى الله عليه وسلم',
    titleEn: 'Qaidah Dhikr Malabis Al Nabi',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 59,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_dhikr_malabis_al_nabi.json',
      sizeBytes: 28711,
      sourceLabel:
          'المكتبة الشاملة — قاعدة تتضمن ذكر ملابس النبي صلى الله عليه وسلم وسلاحه ودوابه - القرمانية - جواب فتيا في لبس النبي صلى الله عليه وسلم، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، أضواء السلف، تحقيق أبو محمد أشرف بن عبد المقصود',
    ),
  ),
  LibraryBook(
    id: 'qaidah_jamiah_fi_tawhid_allah',
    titleAr: 'قاعدة جامعة في توحيد الله وإخلاص الوجه والعمل له عبادة واستعانة',
    titleEn: 'Qaidah Jamiah Fi Tawhid Allah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 69,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_jamiah_fi_tawhid_allah.json',
      sizeBytes: 28947,
      sourceLabel:
          'المكتبة الشاملة — قاعدة جامعة في توحيد الله وإخلاص الوجه والعمل له عبادة واستعانة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار العاصمة، الرياض، المملكة العربية السعودية، تحقيق عبد الله بن محمد البصيري',
    ),
  ),
  LibraryBook(
    id: 'qaidah_hasanah_fil_baqiyat_al_salihat',
    titleAr: 'قاعدة حسنة في الباقيات الصالحات',
    titleEn: 'Qaidah Hasanah Fil Baqiyat Al Salihat',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 48,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_hasanah_fil_baqiyat_al_salihat.json',
      sizeBytes: 23063,
      sourceLabel:
          'المكتبة الشاملة — قاعدة حسنة في الباقيات الصالحات، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مكتبة أضواء السلف، تحقيق أبو محمد أشرف بن عبد المقصود',
    ),
  ),
  LibraryBook(
    id: 'qaidah_azimah_fil_farq_bayn_ibadat_ahl_al_islam',
    titleAr:
        'قاعدة عظيمة في الفرق بين عبادات أهل الإسلام والإيمان وعبادات أهل الشرك والنفاق',
    titleEn: 'Qaidah Azimah Fil Farq Bayn Ibadat Ahl Al Islam',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 145,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_azimah_fil_farq_bayn_ibadat_ahl_al_islam.json',
      sizeBytes: 87998,
      sourceLabel:
          'المكتبة الشاملة — قاعدة عظيمة في الفرق بين عبادات أهل الإسلام والإيمان وعبادات أهل الشرك والنفاق، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار العاصمة - الرياض، تحقيق سليمان بن صالح الغصن',
    ),
  ),
  LibraryBook(
    id: 'qaidah_fil_inghimas_fil_aduw',
    titleAr: 'قاعدة في الانغماس في العدو وهل يباح',
    titleEn: 'Qaidah Fil Inghimas Fil Aduw',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 62,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_fil_inghimas_fil_aduw.json',
      sizeBytes: 36578,
      sourceLabel:
          'المكتبة الشاملة — قاعدة في الانغماس في العدو وهل يباح، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، أضواء السلف، تحقيق أبو محمد أشرف بن عبد المقصود',
    ),
  ),
  LibraryBook(
    id: 'qaidah_fil_sabr',
    titleAr: 'قاعدة في الصبر',
    titleEn: 'Qaidah Fil Sabr',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 51,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/qaidah_fil_sabr.json',
      sizeBytes: 18146,
      sourceLabel:
          'المكتبة الشاملة — قاعدة في الصبر، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، الجامعة الإسلامية بالمدينة المنورة، تحقيق محمد بن خليفة بن علي التميمي',
    ),
  ),
  LibraryBook(
    id: 'qaidah_fil_mahabbah',
    titleAr: 'قاعدة في المحبة',
    titleEn: 'Qaidah Fil Mahabbah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 208,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/qaidah_fil_mahabbah.json',
      sizeBytes: 99107,
      sourceLabel:
          'المكتبة الشاملة — قاعدة في المحبة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مكتبة التراث الإسلامي، القاهرة، مصر، تحقيق محمد رشاد سالم',
    ),
  ),
  LibraryBook(
    id: 'qaidah_mukhtasarah_fi_qital_al_kuffar',
    titleAr: 'قاعدة مختصرة في قتال الكفار ومهادنتهم وتحريم قتلهم لمجرد كفرهم',
    titleEn: 'Qaidah Mukhtasarah Fi Qital Al Kuffar',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 214,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_mukhtasarah_fi_qital_al_kuffar.json',
      sizeBytes: 81883,
      sourceLabel:
          'المكتبة الشاملة — قاعدة مختصرة في قتال الكفار ومهادنتهم وتحريم قتلهم لمجرد كفرهم، شيخ الإسلام أحمد بن عبد الحليم ابن تيمية الحراني (٦٦١ - ٧٢٨ هـ)، (المحقق)',
    ),
  ),
  LibraryBook(
    id: 'qaidah_mukhtasarah_fi_wujub_taat_allah',
    titleAr: 'قاعدة مختصرة في وجوب طاعة الله ورسوله وولاة الأمور',
    titleEn: 'Qaidah Mukhtasarah Fi Wujub Taat Allah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 50,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_mukhtasarah_fi_wujub_taat_allah.json',
      sizeBytes: 18917,
      sourceLabel:
          'المكتبة الشاملة — قاعدة مختصرة في وجوب طاعة الله ورسوله وولاة الأمور، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، جهاز الإرشاد والتوجيه بالحرس الوطني، المملكة العربية السعودية، تحقيق عبد الرزاق بن عبد المحسن البدر',
    ),
  ),
  LibraryBook(
    id: 'masalah_fil_murabatah_bil_thughur',
    titleAr: 'مسألة فى المرابطة بالثغور أفضل أم المجاورة بمكة شرفها الله تعالى',
    titleEn: 'Masalah Fil Murabatah Bil Thughur',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 85,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/masalah_fil_murabatah_bil_thughur.json',
      sizeBytes: 39538,
      sourceLabel:
          'المكتبة الشاملة — مسألة فى المرابطة بالثغور أفضل أم المجاورة بمكة شرفها الله تعالى، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، أضواء السلف',
    ),
  ),
  LibraryBook(
    id: 'masalah_fil_kanais',
    titleAr: 'مسألة في الكنائس',
    titleEn: 'Masalah Fil Kanais',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 48,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/masalah_fil_kanais.json',
      sizeBytes: 45487,
      sourceLabel:
          'المكتبة الشاملة — مسألة في الكنائس، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، مكتبة العبيكان - الرياض، تحقيق علي بن عبدالعزيز الشبل',
    ),
  ),
  LibraryBook(
    id: 'masalah_fi_tawhid_al_falasifah',
    titleAr: 'مسألة في توحيد الفلاسفة',
    titleEn: 'Masalah Fi Tawhid Al Falasifah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 98,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/masalah_fi_tawhid_al_falasifah.json',
      sizeBytes: 59608,
      sourceLabel:
          'المكتبة الشاملة — مسألة في توحيد الفلاسفة، الإمام أحمد بن عبد الحليم ابن تيمية (ت ٧٢٨ هـ)، دار الفتح للدراسات والنشر، تحقيق مبارك بن راشد الحثلان',
    ),
  ),
  LibraryBook(
    id: 'muqaddimah_fi_usul_al_tafsir',
    titleAr: 'مقدمة في أصول التفسير',
    titleEn: 'Muqaddimah Fi Usul Al Tafsir',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 56,
    category: BookCategory.tafsir,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/muqaddimah_fi_usul_al_tafsir.json',
      sizeBytes: 27228,
      sourceLabel:
          'المكتبة الشاملة — مقدمة في أصول التفسير، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨هـ)، دار مكتبة الحياة، بيروت، لبنان',
    ),
  ),
  LibraryBook(
    id: 'manasik_al_hajj_ibn_taymiyyah',
    titleAr: 'مناسك الحج',
    titleEn: 'Manasik Al Hajj Ibn Taymiyyah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 178,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/manasik_al_hajj_ibn_taymiyyah.json',
      sizeBytes: 90830,
      sourceLabel:
          'المكتبة الشاملة — مناسك الحج، شيخ الإسلام أحمد بن عبد الحليم ابن تيمية الحراني (ت ٧٢٨ هـ)، دار ركائز للنشر والتوزيع، الكويت، تحقيق د. أنس بن عادل اليتامى',
    ),
  ),
  LibraryBook(
    id: 'naqd_maratib_al_ijma',
    titleAr: 'نقد مراتب الإجماع',
    titleEn: 'Naqd Maratib Al Ijma',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 25,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/naqd_maratib_al_ijma.json',
      sizeBytes: 19478,
      sourceLabel:
          'المكتبة الشاملة — نقد مراتب الإجماع، تقي الدين أبو العَباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (المتوفى : ٧٢٨هـ)',
    ),
  ),
  LibraryBook(
    id: 'qaidah_jalilah_fil_tawassul_wal_wasilah',
    titleAr: 'قاعدة جليلة في التوسل والوسيلة',
    titleEn: 'Qaidah Jalilah Fil Tawassul Wal Wasilah',
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    deathYearAh: 728,
    pages: 455,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qaidah_jalilah_fil_tawassul_wal_wasilah.json',
      sizeBytes: 255704,
      sourceLabel:
          'المكتبة الشاملة — قاعدة جليلة في التوسل والوسيلة، تقي الدين أبو العباس أحمد بن عبد الحليم بن عبد السلام بن عبد الله بن أبي القاسم بن محمد ابن تيمية الحراني الحنبلي الدمشقي (ت ٧٢٨ هـ)، مكتبة الفرقان - عجمان، تحقيق ربيع بن هادي عمير المدخلي [ت ١٤٤٧ هـ]',
    ),
  ),
  LibraryBook(
    id: 'adab_al_fatwa_wal_mufti',
    titleAr: 'آداب الفتوى والمفتي والمستفتي',
    titleEn: 'Adab Al Fatwa Wal Mufti',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 74,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/adab_al_fatwa_wal_mufti.json',
      sizeBytes: 27240,
      sourceLabel:
          'المكتبة الشاملة — آداب الفتوى والمفتي والمستفتي، أبو زكريا يحيى بن شرف النووي (٦٣١ - ٦٧٦ هـ)، دار الفكر، دمشق - سوريا، تحقيق بسام عبد الوهاب الجابي [ت ١٤٣٨ هـ]',
    ),
  ),
  LibraryBook(
    id: 'al_adhkar_lil_nawawi',
    titleAr: 'الأذكار',
    titleEn: 'Al Adhkar Lil Nawawi',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 411,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_adhkar_lil_nawawi.json',
      sizeBytes: 390619,
      sourceLabel:
          'المكتبة الشاملة — الأذكار، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦ هـ)، دار الفكر للطباعة والنشر والتوزيع، بيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'al_arbaun_al_nawawiyyah',
    titleAr: 'الأربعون النووية',
    titleEn: 'Al Arbaun Al Nawawiyyah',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 81,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_arbaun_al_nawawiyyah.json',
      sizeBytes: 10048,
      sourceLabel:
          'المكتبة الشاملة — الأربعون النووية، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار المنهاج للنشر والتوزيع، لبنان - بيروت',
    ),
  ),
  LibraryBook(
    id: 'al_usul_wal_dawabit',
    titleAr: 'الأصول والضوابط',
    titleEn: 'Al Usul Wal Dawabit',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 27,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_usul_wal_dawabit.json',
      sizeBytes: 6700,
      sourceLabel:
          'المكتبة الشاملة — الأصول والضوابط، أبو زكريا يحيى بن شرف النووي (ت ٦٧٦ هـ)، دار البشائر الإسلامية - بيروت',
    ),
  ),
  LibraryBook(
    id: 'al_ijaz_fi_sharh_sunan_abi_dawud',
    titleAr: 'الإيجاز في شرح سنن أبي داود السجستاني رحمه الله تعالى',
    titleEn: 'Al Ijaz Fi Sharh Sunan Abi Dawud',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 398,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_ijaz_fi_sharh_sunan_abi_dawud.json',
      sizeBytes: 247838,
      sourceLabel:
          'المكتبة الشاملة — الإيجاز في شرح سنن أبي داود السجستاني رحمه الله تعالى، محيي الدين يحيى بن شرف النووي (ت ٦٧٦ هـ)، الدار الأثرية، عمان - الأردن',
    ),
  ),
  LibraryBook(
    id: 'al_idah_fi_manasik_al_hajj_wal_umrah',
    titleAr: 'الإيضاح في مناسك الحج والعمرة',
    titleEn: 'Al Idah Fi Manasik Al Hajj Wal Umrah',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 519,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_idah_fi_manasik_al_hajj_wal_umrah.json',
      sizeBytes: 445183,
      sourceLabel:
          'المكتبة الشاملة — الإيضاح في مناسك الحج والعمرة، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار البشائر الإسلامية، بيروت - المكتبة الأمدادية، مكة المكرمة',
    ),
  ),
  LibraryBook(
    id: 'al_tibyan_fi_adab_hamalat_al_quran',
    titleAr: 'التبيان في آداب حملة القرآن',
    titleEn: 'Al Tibyan Fi Adab Hamalat Al Quran',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 224,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_tibyan_fi_adab_hamalat_al_quran.json',
      sizeBytes: 64098,
      sourceLabel:
          'المكتبة الشاملة — التبيان في آداب حملة القرآن، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار ابن حزم للطباعة والنشر والتوزيع - بيروت - لبنان - ص ب: ٦٣٦٦ / ١٤ - تلفون: ٨٣١٣٣١',
    ),
  ),
  LibraryBook(
    id: 'al_taqrib_wal_taysir',
    titleAr: 'التقريب والتيسير لمعرفة سنن البشير النذير في أصول الحديث',
    titleEn: 'Al Taqrib Wal Taysir',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 100,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_taqrib_wal_taysir.json',
      sizeBytes: 47554,
      sourceLabel:
          'المكتبة الشاملة — التقريب والتيسير لمعرفة سنن البشير النذير في أصول الحديث، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار الكتاب العربي، بيروت',
    ),
  ),
  LibraryBook(
    id: 'bustan_al_arifin',
    titleAr: 'بستان العارفين',
    titleEn: 'Bustan Al Arifin',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 72,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/bustan_al_arifin.json',
      sizeBytes: 43469,
      sourceLabel:
          'المكتبة الشاملة — بستان العارفين، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار الريان للتراث',
    ),
  ),
  LibraryBook(
    id: 'tahrir_alfaz_al_tanbih',
    titleAr: 'تحرير ألفاظ التنبيه',
    titleEn: 'Tahrir Alfaz Al Tanbih',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 303,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tahrir_alfaz_al_tanbih.json',
      sizeBytes: 137261,
      sourceLabel:
          'المكتبة الشاملة — تحرير ألفاظ التنبيه، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار القلم - دمشق، تحقيق عبد الغني الدقر',
    ),
  ),
  LibraryBook(
    id: 'tahqiq_riyad_al_salihin_lil_albani',
    titleAr: 'رياض الصالحين',
    titleEn: 'Tahqiq Riyad Al Salihin Lil Albani',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 98,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tahqiq_riyad_al_salihin_lil_albani.json',
      sizeBytes: 17337,
      sourceLabel:
          'المكتبة الشاملة — رياض الصالحين، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، المكتب الإسلامي - بيروت',
    ),
  ),
  LibraryBook(
    id: 'juz_fih_dhikr_iiqad_al_salaf_fil_huruf_wal_aswat',
    titleAr: 'جزء فيه ذكر اعتقاد السلف في الحروف والأصوات',
    titleEn: 'Juz Fih Dhikr Iiqad Al Salaf Fil Huruf Wal Aswat',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 86,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/juz_fih_dhikr_iiqad_al_salaf_fil_huruf_wal_aswat.json',
      sizeBytes: 47299,
      sourceLabel:
          'المكتبة الشاملة — جزء فيه ذكر اعتقاد السلف في الحروف والأصوات، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، مكتبة الأنصار للنشر والتوزيع، تحقيق أحمد بن على الدمياطي',
    ),
  ),
  LibraryBook(
    id: 'daqaiq_al_minhaj',
    titleAr: 'دقائق المنهاج',
    titleEn: 'Daqaiq Al Minhaj',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 52,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/daqaiq_al_minhaj.json',
      sizeBytes: 22588,
      sourceLabel:
          'المكتبة الشاملة — دقائق المنهاج، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار ابن حزم - بيروت، تحقيق إياد أحمد الغوج',
    ),
  ),
  LibraryBook(
    id: 'fatawa_al_nawawi',
    titleAr:
        'فَتَّاوَى الإِمامِ النَّوَوَيِ المُسمَّاةِ: "بالمَسَائِل المنْثورَةِ"',
    titleEn: 'Fatawa Al Nawawi',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 278,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/fatawa_al_nawawi.json',
      sizeBytes: 180153,
      sourceLabel:
          'المكتبة الشاملة — فَتَّاوَى الإِمامِ النَّوَوَيِ المُسمَّاةِ: "بالمَسَائِل المنْثورَةِ"، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دَارُ البشائرِ الإسلاميَّة للطبَاعَة وَالنشرَ والتوزيع، بَيروت - لبنان',
    ),
  ),
  LibraryBook(
    id: 'minhaj_al_talibin',
    titleAr: 'منهاج الطالبين وعمدة المفتين في الفقه',
    titleEn: 'Minhaj Al Talibin',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 406,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/minhaj_al_talibin.json',
      sizeBytes: 195468,
      sourceLabel:
          'المكتبة الشاملة — منهاج الطالبين وعمدة المفتين في الفقه، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار الفكر، تحقيق عوض قاسم أحمد عوض',
    ),
  ),
  LibraryBook(
    id: 'ar_raheeq_al_makhtum',
    titleAr: 'الرحيق المختوم',
    titleEn: 'Ar-Raheeq Al-Makhtum (The Sealed Nectar)',
    authorAr: 'صفي الرحمن المباركفوري',
    authorEn: 'Safi-ur-Rahman al-Mubarakpuri',
    deathYearAh: 1427,
    descKey: 'book_desc.ar_raheeq_al_makhtum',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/ar_raheeq_al_makhtum.json',
      sizeBytes: 386968,
      sourceLabel:
          'المكتبة الشاملة — الرحيق المختوم، صفي الرحمن المباركفوري (ت ١٤٢٧هـ)، '
          'دار الفكر (طبعة خاصة بدار ومكتبة الهلال) - بيروت، ٢٠٠٢م',
    ),
  ),
  LibraryBook(
    id: 'seerat_ibn_hisham',
    titleAr: 'السيرة النبوية لابن هشام',
    titleEn: 'The Prophetic Biography of Ibn Hisham',
    authorAr: 'ابن هشام',
    authorEn: 'Ibn Hisham',
    deathYearAh: 213,
    descKey: 'book_desc.seerat_ibn_hisham',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/seerat_ibn_hisham.json',
      sizeBytes: 605696,
      sourceLabel:
          'المكتبة الشاملة — السيرة النبوية لابن هشام (ت ٢١٣هـ)، قدّم لها وعلّق '
          'عليها وضبطها طه عبد الرؤوف سعد، شركة الطباعة الفنية المتحدة — النسخة '
          'الإلكترونية تقتصر على الجزأين الأولين',
    ),
  ),
  LibraryBook(
    id: 'zad_al_maad',
    titleAr: 'زاد المعاد في هَدي خير العباد',
    titleEn: 'Zad al-Ma\'ad',
    authorAr: 'شمس الدين، أبو عبد الله، محمد بن أبي بكر الزرعي الدمشقي، ابن قيم الجوزية (٦٩١ - ٧٥١ هـ)',
    authorEn: 'Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    descKey: 'book_desc.zad_al_maad',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/zad_al_maad.json',
      sizeBytes: 1868002,
      sourceLabel:
          'المكتبة الشاملة — زاد المعاد في هدي خير العباد، ابن قيم الجوزية (ت '
          '٧٥١هـ)، تحقيق شعيب الأرنؤوط وعبد القادر الأرنؤوط، مؤسسة الرسالة - '
          'بيروت، الإصدار الثاني المنقّح المزيد، الطبعة الأولى ١٤١٧هـ/١٩٩٦م',
    ),
  ),
  LibraryBook(
    id: 'sahih_as_seerah_albani',
    titleAr: 'صحيح السيرة النبوية [من «البداية والنهاية» لابن كثير]',
    titleEn: 'Sahih as-Seerah an-Nabawiyyah',
    // Shamela's بطاقة الكتاب for book 592 carries no «المؤلف:» line — it names
    // him on a «لَخّصه ... وعَلّق عليه:» line instead, because he abridged the
    // book rather than wrote it — so the crawl's `meta.authorAr` came back
    // empty and this shipped as a blank author name in the "المؤلفون" list.
    // Taken from that line, not invented.
    authorAr: 'محمد ناصر الدين الألباني',
    authorEn: 'Abridged by Muhammad Nasir ad-Din al-Albani',
    deathYearAh: 1420,
    descKey: 'book_desc.sahih_as_seerah_albani',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/sahih_as_seerah_albani.json',
      sizeBytes: 124141,
      sourceLabel:
          'المكتبة الشاملة — صحيح السيرة النبوية (من البداية والنهاية لابن '
          'كثير)، لخّصه وعلّق عليه محمد ناصر الدين الألباني (ت ١٤٢٠هـ)، المكتبة '
          'الإسلامية - عمّان، الطبعة الأولى ١٤٢١هـ — توفي الشيخ قبل إتمامه',
    ),
  ),
  LibraryBook(
    id: 'uyun_al_athar',
    titleAr: 'عيون الأثر في فنون المغازي والشمائل والسير',
    titleEn: 'Uyun al-Athar',
    authorAr: 'محمد بن محمد بن محمد بن أحمد، ابن سيد الناس، اليعمري الربعي، أبو الفتح، فتح الدين (ت ٧٣٤هـ)',
    authorEn: 'Ibn Sayyid an-Nas',
    deathYearAh: 734,
    descKey: 'book_desc.uyun_al_athar',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/uyun_al_athar.json',
      sizeBytes: 763255,
      sourceLabel:
          'المكتبة الشاملة — عيون الأثر في فنون المغازي والشمائل والسير، ابن '
          'سيد الناس (ت ٧٣٤هـ)، تعليق إبراهيم محمد رمضان، دار القلم - بيروت، '
          'الطبعة الأولى ١٤١٤هـ/١٩٩٣م',
    ),
  ),
  LibraryBook(
    id: 'nur_al_yaqin',
    titleAr: 'نور اليقين في سيرة سيد المرسلين',
    titleEn: 'Nur al-Yaqin',
    authorAr: 'محمد بن عفيفي الباجوري، المعروف بالشيخ الخضري (ت ١٣٤٥هـ)',
    authorEn: 'Muhammad al-Khudari',
    deathYearAh: 1345,
    descKey: 'book_desc.nur_al_yaqin',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/nur_al_yaqin.json',
      sizeBytes: 268494,
      sourceLabel:
          'المكتبة الشاملة — نور اليقين في سيرة سيد المرسلين، محمد بن عفيفي '
          'الباجوري المعروف بالشيخ الخضري (ت ١٣٤٥هـ)، دار الفيحاء - دمشق، '
          'الطبعة الثانية ١٤٢٥هـ',
    ),
  ),
  LibraryBook(
    id: 'as_seerah_nadwi',
    titleAr: 'السيرة النبوية لأبي الحسن الندوي',
    titleEn: 'The Prophetic Biography',
    authorAr: 'أبو الحسن علي الحسني الندوي (١٣٣٣ - ١٤٢٠ هـ)',
    authorEn: 'Abul Hasan Ali an-Nadwi',
    deathYearAh: 1420,
    descKey: 'book_desc.as_seerah_nadwi',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/as_seerah_nadwi.json',
      sizeBytes: 429415,
      sourceLabel:
          'المكتبة الشاملة — السيرة النبوية، أبو الحسن علي الحسني الندوي (ت '
          '١٤٢٠هـ)، تحقيق وتعليق سيد عبد الماجد الغوري، دار ابن كثير - دمشق '
          'وبيروت، الطبعة الثانية عشرة ١٤٢٥هـ/٢٠٠٤م',
    ),
  ),
  LibraryBook(
    id: 'fiqh_as_seerah_ghazali',
    titleAr: 'فقه السيرة',
    titleEn: 'Fiqh as-Seerah',
    authorAr: 'محمد الغزالي السقا (ت ١٤١٦هـ)',
    authorEn: 'Muhammad al-Ghazali',
    deathYearAh: 1416,
    descKey: 'book_desc.fiqh_as_seerah_ghazali',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/fiqh_as_seerah_ghazali.json',
      sizeBytes: 379706,
      sourceLabel:
          'المكتبة الشاملة — فقه السيرة، محمد الغزالي السقا (ت ١٤١٦هـ)، تخريج '
          'الأحاديث محمد ناصر الدين الألباني، دار القلم - دمشق، الطبعة الأولى '
          '١٤٢٧هـ',
    ),
  ),
  LibraryBook(
    id: 'as_seerah_ibn_kathir',
    titleAr: 'السيرة النبوية',
    titleEn: 'The Prophetic Biography of Ibn Kathir',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.as_seerah_ibn_kathir',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/as_seerah_ibn_kathir.json',
      sizeBytes: 1880427,
      sourceLabel:
          'المكتبة الشاملة — السيرة النبوية، ابن كثير (ت ٧٧٤هـ)، مستلًّا من '
          'البداية والنهاية، تحقيق د. مصطفى عبد الواحد، عيسى البابي الحلبي - '
          'القاهرة، ١٣٩٥هـ/١٩٧٦م',
    ),
  ),
  LibraryBook(
    id: 'rijal_hawl_ar_rasul',
    titleAr: 'رجال حول الرسول',
    titleEn: 'Men Around the Messenger',
    authorAr: 'خالد محمد خالد ثابت (ت ١٤١٦هـ)',
    authorEn: 'Khalid Muhammad Khalid',
    deathYearAh: 1416,
    descKey: 'book_desc.rijal_hawl_ar_rasul',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/rijal_hawl_ar_rasul.json',
      sizeBytes: 293158,
      sourceLabel:
          'المكتبة الشاملة — رجال حول الرسول، خالد محمد خالد ثابت (ت ١٤١٦هـ)، '
          'دار الفكر - بيروت، الطبعة الأولى ١٤٢١هـ/٢٠٠٠م',
    ),
  ),
  LibraryBook(
    id: 'la_tahzan',
    titleAr: 'لا تحزن',
    titleEn: 'Don\'t Be Sad',
    authorAr: 'عائض بن عبد الله القرني',
    authorEn: 'Aid al-Qarni',
    descKey: 'book_desc.la_tahzan',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/la_tahzan.json',
      sizeBytes: 344210,
      sourceLabel:
          'المكتبة الشاملة — لا تحزن، عائض بن عبد الله القرني، مكتبة العبيكان',
    ),
  ),
  // Added 2026-09-10 because the owner named them as the sources for the
  // Islamic-quote notifications and neither was in the catalogue. Both are
  // Shamela text editions built by `build_book_text.py` from a local crawl
  // and uploaded by `r2_upload_book_text.py`; `sizeBytes` is the byte count
  // the bucket answered with, not an estimate.
  LibraryBook(
    id: 'rawdat_al_uqala',
    titleAr: 'روضة العقلاء ونزهة الفضلاء',
    titleEn: 'Rawdat al-Uqala wa Nuzhat al-Fudala',
    authorAr: 'أبو حاتم محمد بن حبان البستي',
    authorEn: 'Ibn Hibban al-Busti',
    deathYearAh: 354,
    descKey: 'book_desc.rawdat_al_uqala',
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/rawdat_al_uqala.json',
      sizeBytes: 177994,
      sourceLabel:
          'المكتبة الشاملة — روضة العقلاء ونزهة الفضلاء، لأبي حاتم محمد بن '
          'حبان البستي، تحقيق محمد محيي الدين عبد الحميد وآخرين، دار الكتب '
          'العلمية، بيروت',
    ),
  ),
  LibraryBook(
    id: 'hilyat_al_awliya',
    titleAr: 'حلية الأولياء وطبقات الأصفياء',
    titleEn: 'Hilyat al-Awliya wa Tabaqat al-Asfiya',
    authorAr: 'أبو نعيم أحمد بن عبد الله الأصبهاني',
    authorEn: 'Abu Nuaym al-Isbahani',
    deathYearAh: 430,
    descKey: 'book_desc.hilyat_al_awliya',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/hilyat_al_awliya.json',
      sizeBytes: 2498616,
      sourceLabel:
          'المكتبة الشاملة — حلية الأولياء وطبقات الأصفياء، لأبي نعيم '
          'الأصبهاني، مطبعة السعادة، مصر، الطبعة الأولى ١٣٩٤هـ/١٩٧٤م '
          '(١٠ أجزاء)',
    ),
  ),
];
