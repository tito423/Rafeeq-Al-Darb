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

  /// True when a modern muhaqqiq's own apparatus — his footnotes, takhrij,
  /// introduction and indexes — was filtered out of the hosted file, so what
  /// the reader gets is the author's text from that printing and nothing of
  /// the editor's.
  ///
  /// 47 books carry this as of 2026-09-17. [sourceLabel] still names the
  /// muhaqqiq, because naming the printing the text came from is what §1.2
  /// requires — but on its own that line reads as «this is his edition», and
  /// it is not. The reader prints a second line saying so; without it the card
  /// would be true and misleading at the same time, which is the harder kind
  /// of wrong to notice. See `CONTENT-LICENSES.md`.
  final bool editorNotesRemoved;

  const TextEdition({
    required this.url,
    required this.sourceLabel,
    this.isOcr = false,
    this.sizeBytes = 0,
    this.editorNotesRemoved = false,
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
    this.shelfOrder = 0,
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

  /// Where this book sits on its shelf, when the shelf is a **path** rather
  /// than a list. 0 — the default, and what every other shelf uses — means
  /// «no opinion, sort me alphabetically with the rest».
  ///
  /// It exists for `BookCategory.talibIlm`. The owner asked for «الكتب
  /// المتدرجة … بتدرج», and a graduated shelf sorted by title is not a path:
  /// الآجرومية would open the shelf and جامع بيان العلم وفضله, which is what a
  /// student reads first, would sit in the middle. The four stages are
  /// آداب الطلب (1), المتون الأولى (2), التوسّع (3) and المقاصد (4); books
  /// inside a stage still sort by [sortKey].
  ///
  /// `books_tab.dart` sorts on `(shelfOrder, sortKey)` and
  /// `test/talib_ilm_shelf_test.dart` holds the result, because the ordering
  /// is invisible in the data — every id is a valid `int` and nothing else
  /// would notice it being wrong.
  final int shelfOrder;

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
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    descKey: 'book_desc.bulugh_al_maram',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/bulugh_al_maram.json',
      sizeBytes: 315763,
      editorNotesRemoved: true,
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
      sizeBytes: 206314,
      editorNotesRemoved: true,
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
    authorAr: 'الإمام محيي الدين النووي',
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
      sizeBytes: 320479,
      editorNotesRemoved: true,
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
      sizeBytes: 441432,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — صيد الخاطر، بعناية حسن المساحي سويدان، '
          'دار القلم، دمشق، الطبعة الأولى ١٤٢٥هـ/٢٠٠٤م',
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
      sizeBytes: 59028,
      editorNotesRemoved: true,
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
      sizeBytes: 39120,
      editorNotesRemoved: true,
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
    pages: 238,
    category: BookCategory.tafsir,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_jami_fi_amthal_al_quran.json',
      sizeBytes: 141610,
      editorNotesRemoved: true,
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
      sizeBytes: 53526,
      editorNotesRemoved: true,
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
    pages: 529,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_furusiyyah_al_muhammadiyyah.json',
      sizeBytes: 239721,
      editorNotesRemoved: true,
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
    pages: 502,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_kalam_ala_masalat_al_sama.json',
      sizeBytes: 273105,
      editorNotesRemoved: true,
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
    pages: 222,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_uzlah_wal_infirad.json',
      sizeBytes: 69961,
      editorNotesRemoved: true,
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
      sizeBytes: 39218,
      editorNotesRemoved: true,
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
    pages: 327,
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/raf_al_yadayn_fil_salah.json',
      sizeBytes: 162439,
      editorNotesRemoved: true,
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
      sizeBytes: 29051,
      editorNotesRemoved: true,
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
    pages: 516,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/hidayat_al_hayara.json',
      sizeBytes: 309131,
      editorNotesRemoved: true,
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
    pages: 184,
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/amar_al_ayan.json',
      sizeBytes: 116960,
      editorNotesRemoved: true,
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
      sizeBytes: 27399,
      editorNotesRemoved: true,
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
    id: 'tarikh_bayt_al_maqdis',
    titleAr: 'تاريخ بيت المقدس',
    titleEn: 'Tarikh Bayt Al Maqdis',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 40,
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/tarikh_bayt_al_maqdis.json',
      sizeBytes: 15476,
      sourceLabel:
          'المكتبة الشاملة — تاريخ بيت المقدس، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، مكتبة الثقافة الدينية، تحقيق محمد زينهم محمد عزب',
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
      sizeBytes: 153862,
      editorNotesRemoved: true,
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
      sizeBytes: 328913,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — تلبيس إبليس، عبد الرحمن بن علي بن محمد ابن الجوزي (ت ٥٩٧ هـ)، دار الفكر، بيروت - لبنان',
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
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/talqih_fuhum_ahl_al_athar.json',
      sizeBytes: 359234,
      sourceLabel:
          'المكتبة الشاملة — تلقيح فهوم أهل الأثر في عيون التاريخ والسير، جمال الدين أبي الفرج عبد الرحمن ابن الجوزي [٥٠٨هـ - ٥٩٧هـ]، شركة دار الأرقم بن أبي الأرقم - بيروت',
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
  // `takhrij_al_kalim_al_tayyib` (Shamela 327) removed: it is al-Albani's
  // edition of al-Kalim at-Tayyib — every entry is numbered and prefixed with
  // HIS grading, «٢٥٤ - (ضعيف جدا) …» — catalogued under Ibn Taymiyyah's name
  // with no mention of him. al-Albani died 1999, so the v3.29.0 purge took
  // every other book of his; this one survived only because the card said
  // «ابن تيمية». Ibn Taymiyyah's own text stays in the library as
  // `al_kalim_al_tayyib` (Shamela 21578, دار الفكر اللبناني).
  LibraryBook(
    id: 'fadail_bayt_al_maqdis',
    titleAr: 'فضائل بيت المقدس',
    titleEn: 'Fadail Bayt Al Maqdis',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 119,
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/fadail_bayt_al_maqdis.json',
      sizeBytes: 56732,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — فضائل بيت المقدس، أبو الفرج جمال الدين ابن الجوزي (٥٠٨ - ٥٩٧ هـ)، مكتبة الإمام البخاري للنشر والتوزيع، القاهرة - مصر',
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
    id: 'mashyakhat_ibn_al_jawzi',
    titleAr: 'مشيخة ابن الجوزي',
    titleEn: 'Mashyakhat Ibn Al Jawzi',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 150,
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/mashyakhat_ibn_al_jawzi.json',
      sizeBytes: 46300,
      sourceLabel:
          'المكتبة الشاملة — مشيخة ابن الجوزي، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧ هـ)، دار الغرب الإسلامي، بيروت',
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
      sizeBytes: 30397,
      sourceLabel:
          'المكتبة الشاملة — الياقوتة - مواعظ ابن الجوزي، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)',
    ),
  ),
  LibraryBook(
    id: 'nawasikh_al_quran',
    titleAr: 'نواسخ القرآن = ناسخ القرآن ومنسوخه',
    titleEn: 'Nawasikh Al Quran',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    deathYearAh: 597,
    pages: 210,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nawasikh_al_quran.json',
      sizeBytes: 146389,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — نواسخ القرآن = ناسخ القرآن ومنسوخه، جمال الدين أبو الفرج عبد الرحمن بن علي بن محمد الجوزي (ت ٥٩٧هـ)، شركه أبناء شريف الأنصارى - بيروت، تحقيق أبو عبد الله العاملي السّلفي الداني بن منير آل زهوي',
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
  // «الأذكار» and «الأربعون النووية» were each catalogued twice, under two
  // ids pointing at two uploads of the SAME Shamela book (1956 and 12836).
  // Both copies were fetched and compared page by page — 411/411 and 81/81
  // byte-identical, TOC included — so these two entries were removed and the
  // ones carrying a translated descKey kept. See the duplicate test.
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
  // `al_ijaz_fi_sharh_sunan_abi_dawud` removed 2026-09-17, and it is the only
  // one of the 48 books carrying a modern editor's apparatus that could not be
  // saved by filtering it out.
  //
  // The book is an-Nawawi's, but the file is أبو عبيدة مشهور بن حسن آل سلمان's
  // — he is alive, the Dar al-Athariyyah printing is 2007, and he did not
  // merely annotate it: he reconstructed it from a manuscript. Measured by
  // `scripts/strip_editor_apparatus.py`: filtering his work out leaves
  // **47.7 %** of the text, **83 pages empty inside the book** and a run of
  // **20 consecutive blank pages**; the printing's own page 51 is a row of
  // dots because that whole leaf is his footnote; and the pages that do
  // survive still speak in his voice — «النسخة التي اعتمدناها في التحقيق».
  // A book that has to lose half of itself is not that book any more, so it
  // goes the way the v3.29.0 purge sent the other 23.
  //
  // an-Nawawi keeps his other fifteen titles in the library.
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
      sizeBytes: 272191,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — الإيضاح في مناسك الحج والعمرة، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار البشائر الإسلامية، بيروت - المكتبة الأمدادية، مكة المكرمة',
    ),
  ),
  // «التبيان في آداب حملة القرآن» was the third book catalogued twice
  // (Shamela 1969, 224/224 identical pages). The surviving entry is
  // `at_tibyan_hamalat_al_quran`, filed under adab.
  // `al_taqrib_wal_taysir` was the SEVENTH copy of a book already in the
  // library, and the one the title test could not see: the other entry calls
  // it «التقريب والتيسير لمعرفة سنن البشير النذير» and this one added the
  // book's tail «في أصول الحديث», so the two keys differed by four words and
  // the comparison passed. Same Shamela 5586, 100/100 identical pages,
  // identical TOC. It was found by scrolling al-Nawawi's shelf on the
  // emulator and seeing the title twice — which is the only reason the other
  // six were found too. The test now also compares one title against the
  // other as a prefix.
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
      sizeBytes: 43483,
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
      sizeBytes: 137454,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — تحرير ألفاظ التنبيه، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، دار القلم - دمشق، تحقيق عبد الغني الدقر',
    ),
  ),
  // `tahqiq_riyad_al_salihin_lil_albani` (Shamela 512) removed, and it was the
  // worst of the three: 98 pages scattered across a 639-page printing — only
  // the pages that carry al-Albani's own comment — every one a grading plus
  // «قلت: … كما بينته في (الضعيفة)». So it was neither Riyad as-Salihin nor a
  // complete book, catalogued as «رياض الصالحين» by an-Nawawi with `pages: 98`.
  // The real book is `riyad_as_salihin` (810 pages, ت شعيب الأرنؤوط).
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
      sizeBytes: 45499,
      editorNotesRemoved: true,
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
      sizeBytes: 139740,
      editorNotesRemoved: true,
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
      sizeBytes: 597441,
      editorNotesRemoved: true,
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
    authorAr: 'الإمام ابن قيّم الجوزية',
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
      sizeBytes: 1774650,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — السيرة النبوية، ابن كثير (ت ٧٧٤هـ)، مستلًّا من '
          'البداية والنهاية، تحقيق د. مصطفى عبد الواحد، عيسى البابي الحلبي - '
          'القاهرة، ١٣٩٥هـ/١٩٧٦م',
    ),
  ),
  // Added 2026-09-10 because the owner named them as the sources for the
  // Islamic-quote notifications and neither was in the catalogue. Both are
  // Shamela text editions built by `build_book_text.py` from a local crawl
  // and uploaded by `r2_upload_book_text.py`; `sizeBytes` is the byte count
  // the bucket answered with, not an estimate.
  // «حطلي لكل واحد فيهم ١٠ كتب … من الشاملة». The first of that batch: its
  // author id came from the book this Library already ships of his, not from
  // Shamela's search (trap #17). Its own card says the numbering is مرقم آليًا
  // and NOT موافق للمطبوع, so the reader is told that rather than the opposite
  // - a plain «"موافق للمطبوع" in card» test had been reading «غير موافق
  // للمطبوع» as a match.
  // Five more of al-Nawawi's best-known books (2026-09-12). «أشهر كتاب
  // مش أقصر كتاب» - chosen by reading his title list, not by sorting it
  // by page count, which had produced hadith fragments nobody asks for.
  LibraryBook(
    id: 'al_adhkar_nawawi',
    titleAr: 'الأذكار',
    titleEn: 'Al-Adhkar',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 411,
    descKey: 'book_desc.al_adhkar_nawawi',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_adhkar_nawawi.json',
      sizeBytes: 320674,
      editorNotesRemoved: true,
      // The muhaqqiq was WRONG here: this label named شعيب الأرنؤوط. Shamela
      // 1956's own book card — and the editionCard inside the hosted file —
      // says عبد القادر الأرنؤوط [ت ١٤٢٥ هـ]. Two different scholars.
      sourceLabel:
          'المكتبة الشاملة — الأذكار، أبو زكريا محيي الدين يحيى بن شرف '
          'النووي (ت ٦٧٦هـ)، تحقيق عبد القادر الأرنؤوط (ت ١٤٢٥هـ)، دار '
          'الفكر للطباعة والنشر والتوزيع، بيروت - لبنان، طبعة جديدة منقحة '
          '١٤١٤هـ/١٩٩٤م',
    ),
  ),
  LibraryBook(
    id: 'at_tibyan_hamalat_al_quran',
    titleAr: 'التبيان في آداب حملة القرآن',
    titleEn: 'At-Tibyan fi Adab Hamalat al-Quran',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 213,
    descKey: 'book_desc.at_tibyan_hamalat_al_quran',
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/at_tibyan_hamalat_al_quran.json',
      sizeBytes: 63236,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — التبيان في آداب حملة القرآن، أبو زكريا محيي '
          'الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، حققه وعلق عليه محمد الحجار، '
          'دار ابن حزم، بيروت، الطبعة الثالثة مزيدة ومنقحة، ١٤١٤هـ/١٩٩٤م',
    ),
  ),
  LibraryBook(
    id: 'al_arbaun_an_nawawiyyah',
    titleAr: 'الأربعون النووية',
    titleEn: 'The Forty Hadith of an-Nawawi',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 81,
    descKey: 'book_desc.al_arbaun_an_nawawiyyah',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_arbaun_an_nawawiyyah.json',
      sizeBytes: 10058,
      sourceLabel:
          'المكتبة الشاملة — الأربعون النووية، أبو زكريا محيي الدين يحيى بن '
          'شرف النووي (ت ٦٧٦هـ)، عُني به قصي محمد نورس الحلاق وأنور بن أبي '
          'بكر الشيخي، دار المنهاج للنشر والتوزيع، لبنان - بيروت، الطبعة '
          'الأولى ١٤٣٠هـ/٢٠٠٩م',
    ),
  ),
  LibraryBook(
    id: 'at_taqrib_wat_taysir',
    // The book's full title, as Shamela 5586's card prints it. The short form
    // this entry used to carry is why the duplicate went unseen.
    titleAr: 'التقريب والتيسير لمعرفة سنن البشير النذير في أصول الحديث',
    titleEn: 'At-Taqrib wat-Taysir',
    authorAr: 'الإمام محيي الدين النووي',
    authorEn: 'Imam al-Nawawi',
    deathYearAh: 676,
    pages: 100,
    descKey: 'book_desc.at_taqrib_wat_taysir',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/at_taqrib_wat_taysir.json',
      sizeBytes: 47579,
      sourceLabel:
          'المكتبة الشاملة — التقريب والتيسير لمعرفة سنن البشير النذير في '
          'أصول الحديث، أبو زكريا محيي الدين يحيى بن شرف النووي (ت ٦٧٦هـ)، '
          'تقديم وتحقيق وتعليق محمد عثمان الخشت، دار الكتاب العربي، بيروت، '
          'الطبعة الأولى ١٤٠٥هـ/١٩٨٥م',
    ),
  ),
  // Nine of Ibn Kathir's, chosen for fame from his Shamela list
  // (2026-09-12). His seerah was the Library's only book of his.
  LibraryBook(
    id: 'fadail_al_quran_ibn_kathir',
    titleAr: 'فضائل القرآن',
    titleEn: 'Fadail al-Quran',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.fadail_al_quran_ibn_kathir',
    category: BookCategory.tafsir,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/fadail_al_quran_ibn_kathir.json',
      sizeBytes: 142747,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — فضائل القرآن لابن كثير، مكتبة ابن تيمية، الطبعة الأولى ١٤١٦هـ',
    ),
  ),
  LibraryBook(
    id: 'al_baith_al_hathith',
    titleAr: 'الباعث الحثيث إلى اختصار علوم الحديث',
    titleEn: 'Al-Baith al-Hathith',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.al_baith_al_hathith',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_baith_al_hathith.json',
      sizeBytes: 62448,
      sourceLabel:
          'المكتبة الشاملة — الباعث الحثيث إلى اختصار علوم الحديث لابن كثير',
    ),
  ),
  LibraryBook(
    id: 'al_fusul_fi_seerat_ar_rasul',
    titleAr: 'الفصول في سيرة الرسول ﷺ',
    titleEn: 'Al-Fusul fi Seerat ar-Rasul',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.al_fusul_fi_seerat_ar_rasul',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_fusul_fi_seerat_ar_rasul.json',
      sizeBytes: 99903,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — الفصول في سيرة الرسول ﷺ لابن كثير، مؤسسة علوم القرآن، دمشق - بيروت، الطبعة الثالثة ١٤٠٣هـ',
    ),
  ),
  LibraryBook(
    id: 'mujizat_an_nabi',
    titleAr: 'معجزات النبي ﷺ من البداية والنهاية',
    titleEn: 'Mujizat an-Nabi',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.mujizat_an_nabi',
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/mujizat_an_nabi.json',
      sizeBytes: 358168,
      sourceLabel:
          'المكتبة الشاملة — معجزات النبي ﷺ من البداية والنهاية لابن كثير، تحقيق السيد إبراهيم',
    ),
  ),
  LibraryBook(
    id: 'musnad_abi_bakr',
    titleAr: 'مسند أبي بكر الصديق رضي الله عنه',
    titleEn: 'Musnad Abi Bakr as-Siddiq',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.musnad_abi_bakr',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/musnad_abi_bakr.json',
      sizeBytes: 409494,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — مسند أبي بكر الصديق لابن كثير',
    ),
  ),
  LibraryBook(
    id: 'tabaqat_ash_shafiiyyin',
    titleAr: 'طبقات الشافعيين',
    titleEn: 'Tabaqat ash-Shafiiyyin',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.tabaqat_ash_shafiiyyin',
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tabaqat_ash_shafiiyyin.json',
      sizeBytes: 477012,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — طبقات الشافعيين لابن كثير، مكتبة الثقافة الدينية',
    ),
  ),
  LibraryBook(
    id: 'adab_dukhul_al_hammam',
    titleAr: 'الآداب والأحكام المتعلقة بدخول الحمّام',
    titleEn: 'Adab Dukhul al-Hammam',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.adab_dukhul_al_hammam',
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/adab_dukhul_al_hammam.json',
      sizeBytes: 26633,
      sourceLabel:
          'المكتبة الشاملة — الآداب والأحكام المتعلقة بدخول الحمّام لابن كثير',
    ),
  ),
  LibraryBook(
    id: 'juz_bay_ummahat_al_awlad',
    titleAr: 'جزء في بيع أمهات الأولاد',
    titleEn: 'Juz fi Bay Ummahat al-Awlad',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.juz_bay_ummahat_al_awlad',
    category: BookCategory.fiqh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/juz_bay_ummahat_al_awlad.json',
      sizeBytes: 68056,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — جزء في بيع أمهات الأولاد لابن كثير',
    ),
  ),
  // Al-Nadwi's five — everything Shamela holds of his besides the
  // seerah already here, so this author is complete at what exists.
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
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
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
  LibraryBook(
    id: 'taqrib_al_tahdhib',
    titleAr: 'تقريب التهذيب',
    titleEn: 'Taqrib al-Tahdhib',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 765,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/taqrib_al_tahdhib.json',
      sizeBytes: 391881,
      sourceLabel:
          'المكتبة الشاملة — تقريب التهذيب، للحافظ ابن حجر العسقلاني، '
          'محمد عوامة، دار الرشيد - سوريا، الأولى، ١٤٠٦ - ١٩٨٦',
    ),
  ),
  LibraryBook(
    id: 'nuzhat_al_nazar',
    titleAr: 'نزهة النظر في توضيح نخبة الفكر',
    titleEn: 'Nuzhat al-Nazar',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 154,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nuzhat_al_nazar.json',
      sizeBytes: 119754,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — نزهة النظر في توضيح نخبة الفكر - ت عتر، '
          'للحافظ ابن حجر العسقلاني، مطبعة الصباح، دمشق - سوريا، '
          'الثالثة، ١٤٢١ هـ - ٢٠٠٠ م',
    ),
  ),
  LibraryBook(
    id: 'hady_al_sari',
    titleAr: 'هدي الساري مقدمة فتح الباري',
    titleEn: 'Hady al-Sari',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 493,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/hady_al_sari.json',
      sizeBytes: 590400,
      sourceLabel:
          'المكتبة الشاملة — هدي الساري مقدمة فتح الباري - ط السلفية، '
          'للحافظ ابن حجر العسقلاني، المكتبة السلفية - مصر، «السلفية '
          'الأولى» ١٣٨٠ هـ',
    ),
  ),
  LibraryBook(
    id: 'al_amali_al_mutlaqah',
    titleAr: 'الأمالي المطلقة',
    titleEn: 'Al-Amali al-Mutlaqah',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 258,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_amali_al_mutlaqah.json',
      sizeBytes: 133961,
      sourceLabel:
          'المكتبة الشاملة — الأمالي المطلقة، للحافظ ابن حجر '
          'العسقلاني، حمدي بن عبد المجيد بن إسماعيل السلفي [ت ١٤٣٣ '
          'هـ]، المكتب الإسلامي - بيروت، الأولى، ١٤١٦ هـ -١٩٩٥ م',
    ),
  ),
  LibraryBook(
    id: 'al_mujam_al_mufahras',
    titleAr: 'المعجم المفهرس',
    titleEn: 'Al-Mujam al-Mufahras',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 420,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_mujam_al_mufahras.json',
      sizeBytes: 346686,
      sourceLabel:
          'المكتبة الشاملة — المعجم المفهرس = تجريد أسانيد الكتب '
          'المشهورة والأجزاء المنثورة، للحافظ ابن حجر العسقلاني، محمد '
          'شكور المياديني، مؤسسة الرسالة - بيروت، الأولى، '
          '١٤١٨هـ-١٩٩٨م',
    ),
  ),
  LibraryBook(
    id: 'raf_al_isr_an_qudat_misr',
    titleAr: 'رفع الإصر عن قضاة مصر',
    titleEn: 'Raf al-Isr an Qudat Misr',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 485,
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/raf_al_isr_an_qudat_misr.json',
      sizeBytes: 346550,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — رفع الإصر عن قضاة مصر، للحافظ ابن حجر '
          'العسقلاني، مكتبة الخانجي، القاهرة، الأولى، ١٤١٨ هـ - ١٩٩٨ '
          'م',
    ),
  ),
  LibraryBook(
    id: 'al_ithar_bi_marifat_ruwat_al_athar',
    titleAr: 'الإيثار بمعرفة رواة الآثار',
    titleEn: 'Al-Ithar bi Marifat Ruwat al-Athar',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 222,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ithar_bi_marifat_ruwat_al_athar.json',
      sizeBytes: 22431,
      sourceLabel:
          'المكتبة الشاملة — الإيثار بمعرفة رواة الآثار، للحافظ ابن '
          'حجر العسقلاني، سيد كسروي حسن، دار الكتب العلمية - بيروت، '
          'الأولى، ١٤١٣',
    ),
  ),
  LibraryBook(
    id: 'nataij_al_afkar',
    titleAr: 'قطعة من نتائج الأفكار في تخريج أحاديث الأذكار',
    titleEn: 'Nataij al-Afkar',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 362,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nataij_al_afkar.json',
      sizeBytes: 183742,
      sourceLabel:
          'المكتبة الشاملة — قطعة من نتائج الأفكار في تخريج أحاديث '
          'الأذكار، للحافظ ابن حجر العسقلاني، وائل بكر زهران، الفاروق '
          'الحديثة للطباعة والنشر، القاهرة - مصر، الأولى، ١٤٣٦ هـ - '
          '٢٠١٥ م',
    ),
  ),
  LibraryBook(
    id: 'al_wuquf_ala_al_mawquf',
    titleAr: 'الوقوف على الموقوف',
    titleEn: 'Al-Wuquf ala al-Mawquf',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 144,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_wuquf_ala_al_mawquf.json',
      sizeBytes: 33350,
      sourceLabel:
          'المكتبة الشاملة — الوقوف على الموقوف، للحافظ ابن حجر '
          'العسقلاني، عبد الله الليثي الأنصاري، مؤسسة الكتب الثقافية '
          '- بيروت، الأولى، ١٤٠٦',
    ),
  ),
  LibraryBook(
    id: 'silsilat_al_dhahab',
    titleAr: 'سلسلة الذهب',
    titleEn: 'Silsilat al-Dhahab',
    authorAr: 'الحافظ ابن حجر العسقلاني',
    authorEn: 'Ibn Hajar al-Asqalani',
    deathYearAh: 852,
    pages: 102,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/silsilat_al_dhahab.json',
      sizeBytes: 8493,
      sourceLabel:
          'المكتبة الشاملة — سلسلة الذهب، للحافظ ابن حجر العسقلاني، '
          'د. عبد المعطي أمين قلعه جي',
    ),
  ),
  LibraryBook(
    id: 'dalail_al_nubuwwah_abu_nuaym',
    titleAr: 'دلائل النبوة',
    titleEn: 'Dalail al-Nubuwwah',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 640,
    category: BookCategory.seerah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/dalail_al_nubuwwah_abu_nuaym.json',
      sizeBytes: 373423,
      sourceLabel:
          'المكتبة الشاملة — دلائل النبوة - أبو نعيم الأصبهاني، '
          'للحافظ أبو نعيم الأصبهاني، دار النفائس، بيروت، الثانية، '
          '١٤٠٦ هـ - ١٩٨٦ م',
    ),
  ),
  LibraryBook(
    id: 'al_imamah_wal_radd_ala_al_rafidah',
    titleAr: 'الإمامة والرد على الرافضة',
    titleEn: 'Al-Imamah wal-Radd ala al-Rafidah',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 382,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_imamah_wal_radd_ala_al_rafidah.json',
      sizeBytes: 77381,
      sourceLabel:
          'المكتبة الشاملة — الإمامة والرد على الرافضة، للحافظ أبو '
          'نعيم الأصبهاني، د. علي بن محمد بن ناصر الفقيهي [ت ١٤٤٦ '
          'هـ]، مكتبة العلوم والحكم - المدينة المنورة / السعودية، '
          'الثالثة، ١٤١٥ هـ - ١٩٩٤ م',
    ),
  ),
  LibraryBook(
    id: 'musnad_abi_hanifah_abu_nuaym',
    titleAr: 'مسند أبي حنيفة رواية أبي نعيم',
    titleEn: 'Musnad Abi Hanifah',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 278,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/musnad_abi_hanifah_abu_nuaym.json',
      sizeBytes: 108427,
      sourceLabel:
          'المكتبة الشاملة — مسند أبي حنيفة رواية أبي نعيم، للحافظ '
          'أبو نعيم الأصبهاني، نظر محمد الفاريابي، مكتبة الكوثر - '
          'الرياض، الأولى، ١٤١٥ هـ',
    ),
  ),
  LibraryBook(
    id: 'sifat_al_nifaq',
    titleAr: 'صفة النفاق ونعت المنافقين',
    titleEn: 'Sifat al-Nifaq',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 191,
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sifat_al_nifaq.json',
      sizeBytes: 44829,
      sourceLabel:
          'المكتبة الشاملة — صفة النفاق ونعت المنافقين لأبي نعيم، '
          'للحافظ أبو نعيم الأصبهاني، البشائر الإسلامية، بيروت - '
          'لبنان، الأولى، ١٤٢٢ هـ - ٢٠٠١ م',
    ),
  ),
  LibraryBook(
    id: 'fadail_al_khulafa_al_rashidin',
    titleAr: 'فضائل الخلفاء الراشدين',
    titleEn: 'Fadail al-Khulafa al-Rashidin',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 184,
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/fadail_al_khulafa_al_rashidin.json',
      sizeBytes: 60646,
      sourceLabel:
          'المكتبة الشاملة — فضائل الخلفاء الراشدين لأبي نعيم '
          'الأصبهاني، للحافظ أبو نعيم الأصبهاني، دار البخاري للنشر '
          'والتوزيع، المدينة المنورة، الأولى، ١٤١٧ هـ - ١٩٩٧ م',
    ),
  ),
  LibraryBook(
    id: 'riyadat_al_abdan',
    titleAr: 'رياضة الأبدان',
    titleEn: 'Riyadat al-Abdan',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 67,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/riyadat_al_abdan.json',
      sizeBytes: 6696,
      sourceLabel:
          'المكتبة الشاملة — رياضة الأبدان لأبي نعيم الأصبهاني، '
          'للحافظ أبو نعيم الأصبهاني، دار العاصمة - الرياض، الأولى، '
          '١٤٠٨ هـ',
    ),
  ),
  LibraryBook(
    id: 'al_arbaun_ala_madhhab_al_mutahaqqiqin',
    titleAr: 'الأربعون على مذهب المتحققين من الصوفية',
    titleEn: 'Al-Arbaun ala Madhhab al-Mutahaqqiqin',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 112,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_arbaun_ala_madhhab_al_mutahaqqiqin.json',
      sizeBytes: 18380,
      sourceLabel:
          'المكتبة الشاملة — الأربعون على مذهب المتحققين من الصوفية '
          'لأبي نعيم الأصبهاني، للحافظ أبو نعيم الأصبهاني، دار ابن '
          'حزم، بيروت - لبنان، الأولى، ١٤١٤ هـ - ١٩٩٣ م',
    ),
  ),
  LibraryBook(
    id: 'hadith_asma_allah_al_husna',
    titleAr: 'حديث إن لله تسعة وتسعين اسمًا',
    titleEn: 'Hadith Asma Allah al-Husna',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 170,
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/hadith_asma_allah_al_husna.json',
      sizeBytes: 11928,
      sourceLabel:
          'المكتبة الشاملة — حديث إن لله تسعة وتسعين اسما لأبي نعيم '
          'الأصبهاني، للحافظ أبو نعيم الأصبهاني، مكتبة الغرباء '
          'الأثرية - المدينة المنورة، الأولى، ١٤١٣',
    ),
  ),
  LibraryBook(
    id: 'fadilat_al_adilin_min_al_wulat',
    titleAr: 'فضيلة العادلين من الولاة',
    titleEn: 'Fadilat al-Adilin min al-Wulat',
    authorAr: 'الحافظ أبو نعيم الأصبهاني',
    authorEn: 'Abu Nuaym al-Asbahani',
    deathYearAh: 430,
    pages: 172,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/fadilat_al_adilin_min_al_wulat.json',
      sizeBytes: 14881,
      sourceLabel:
          'المكتبة الشاملة — فضيلة العادلين من الولاة لأبي نعيم، '
          'للحافظ أبو نعيم الأصبهاني، دار الوطن - الرياض، الأولى، '
          '١٤١٨ هـ - ١٩٩٧ م',
    ),
  ),
  LibraryBook(
    id: 'al_bidaya_wan_nihaya',
    titleAr: 'البداية والنهاية',
    titleEn: 'The Beginning and the End',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.al_bidaya_wan_nihaya',
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_bidaya_wan_nihaya.json',
      sizeBytes: 5187917,
      editorNotesRemoved: true,
      // The 1348–1358 AH Cairo printing, which has NO modern muhaqqiq: the
      // two editions in print today (دار هجر 1996, دار ابن كثير 2013) carry
      // apparatus that belongs to living editors, and this one carries the
      // publisher's own تنبيه about the manuscripts instead.
      sourceLabel:
          'المكتبة الشاملة — البداية والنهاية، لابن كثير (ت ٧٧٤ هـ)، '
          'مطبعة السعادة - القاهرة، الطبعة الأولى ١٣٤٨ - ١٣٥٨ هـ، '
          '١٤ جزءًا',
    ),
  ),
  LibraryBook(
    id: 'qisas_al_anbiya_ibn_kathir',
    titleAr: 'قصص الأنبياء',
    titleEn: 'Stories of the Prophets',
    authorAr: 'أبو الفداء، إسماعيل بن كثير (٧٠١ - ٧٧٤ هـ)',
    authorEn: 'Ibn Kathir',
    deathYearAh: 774,
    descKey: 'book_desc.qisas_al_anbiya_ibn_kathir',
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qisas_al_anbiya_ibn_kathir.json',
      sizeBytes: 601004,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — قصص الأنبياء، لابن كثير (ت ٧٧٤ هـ)، '
          'مستلًّا من البداية والنهاية، تحقيق د. مصطفى عبد الواحد، '
          'مطبعة دار التأليف - القاهرة، الأولى ١٣٨٨هـ - ١٩٦٨م',
    ),
  ),
  LibraryBook(
    id: 'futuh_al_buldan',
    titleAr: 'فتوح البلدان',
    titleEn: 'The Conquests of the Lands',
    authorAr: 'أحمد بن يحيى بن جابر البَلَاذُري (ت ٢٧٩ هـ)',
    authorEn: 'al-Baladhuri',
    deathYearAh: 279,
    pages: 456,
    descKey: 'book_desc.futuh_al_buldan',
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/futuh_al_buldan.json',
      sizeBytes: 319705,
      sourceLabel:
          'المكتبة الشاملة — فتوح البلدان، لأحمد بن يحيى البَلاذُري '
          '(ت ٢٧٩هـ)، دار ومكتبة الهلال - بيروت، ١٩٨٨م',
    ),
  ),
  LibraryBook(
    id: 'tarikh_al_khulafa_suyuti',
    titleAr: 'تاريخ الخلفاء',
    titleEn: 'History of the Caliphs',
    authorAr: 'جلال الدين عبد الرحمن السيوطي (ت ٩١١ هـ)',
    authorEn: 'Jalal al-Din al-Suyuti',
    deathYearAh: 911,
    pages: 782,
    descKey: 'book_desc.tarikh_al_khulafa_suyuti',
    category: BookCategory.tarikh,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tarikh_al_khulafa_suyuti.json',
      sizeBytes: 449120,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — تاريخ الخلفاء، لجلال الدين السيوطي (ت ٩١١ هـ)، '
          'اعتنى به مركز دار المنهاج، دار المنهاج - جدة، '
          'الثانية ١٤٣٤هـ - ٢٠١٣م',
    ),
  ),
  // ══════════════════════════════════════════════════════════════════════
  // 2026-09-17 — «اشهر وافضل الكتب في تنمية الذات واداب النفس» و«قسم
  // وتسميه طالب العلم … الكتب المتدرجة … المنهج الوسطي المعتدل بتدرج».
  //
  // The library held 99 tazkiyah books and not one by الغزالي، ابن رجب،
  // الشاطبي، الماوردي، ابن حزم، المحاسبي، الخطيب البغدادي or ابن عبد البر —
  // measured by grepping each name over this file and getting zero. It was
  // almost entirely ابن أبي الدنيا and ابن الجوزي.
  //
  // Every id came from the LOCAL Shamela title index, never from Shamela's
  // own search, which searches inside books and returns a commentary above
  // the book it comments on (trap #17). Every `sizeBytes` is what R2
  // answered on a HEAD after the upload, not what the local file measured.
  //
  // الاعتصام للشاطبي is deliberately absent while الموافقات is here: he asked
  // to stay far from تشدد, and الموافقات is the مقاصد book.
  // ══════════════════════════════════════════════════════════════════════
  LibraryBook(
    id: 'ihya_ulum_al_din',
    titleAr: 'إحياء علوم الدين',
    titleEn: 'Ihya Ulum al-Din',
    authorAr: 'الإمام أبو حامد الغزالي',
    authorEn: 'Imam Abu Hamid al-Ghazali',
    deathYearAh: 505,
    pages: 547,
    descKey: 'book_desc.ihya_ulum_al_din',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/ihya_ulum_al_din.json',
      sizeBytes: 2616190,
      sourceLabel:
          'المكتبة الشاملة — إحياء علوم الدين، لأبي حامد الغزالي (ت ٥٠٥ '
              'هـ)، دار المعرفة، بيروت',
    ),
  ),
  LibraryBook(
    id: 'madarij_al_salikin',
    titleAr: 'مدارج السالكين بين منازل إياك نعبد وإياك نستعين',
    titleEn: 'Madarij al-Salikin',
    authorAr: 'الإمام ابن قيّم الجوزية',
    authorEn: 'Imam Ibn Qayyim al-Jawziyyah',
    deathYearAh: 751,
    pages: 526,
    descKey: 'book_desc.madarij_al_salikin',
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/madarij_al_salikin.json',
      sizeBytes: 1372508,
      sourceLabel:
          'المكتبة الشاملة — مدارج السالكين بين منازل إياك نعبد وإياك '
              'نستعين، لابن قيم الجوزية (ت ٧٥١ هـ)، تحقيق محمد المعتصم '
              'بالله البغدادي، دار الكتاب العربي',
    ),
  ),
  LibraryBook(
    id: 'jami_al_ulum_wal_hikam',
    titleAr: 'جامع العلوم والحكم في شرح خمسين حديثاً من جوامع الكلم',
    titleEn: 'Jami al-Ulum wal-Hikam',
    authorAr: 'الحافظ ابن رجب الحنبلي',
    authorEn: 'al-Hafiz Ibn Rajab al-Hanbali',
    deathYearAh: 795,
    pages: 950,
    descKey: 'book_desc.jami_al_ulum_wal_hikam',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/jami_al_ulum_wal_hikam.json',
      sizeBytes: 707821,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — جامع العلوم والحكم، لابن رجب الحنبلي (ت '
              '٧٩٥ هـ)، تحقيق ماهر ياسين الفحل',
    ),
  ),
  LibraryBook(
    id: 'adab_al_dunya_wal_din',
    titleAr: 'أدب الدنيا والدين',
    titleEn: 'Adab al-Dunya wal-Din',
    authorAr: 'الإمام أبو الحسن الماوردي',
    authorEn: 'Imam Abu al-Hasan al-Mawardi',
    deathYearAh: 450,
    pages: 358,
    descKey: 'book_desc.adab_al_dunya_wal_din',
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/adab_al_dunya_wal_din.json',
      sizeBytes: 327167,
      sourceLabel:
          'المكتبة الشاملة — أدب الدنيا والدين، للماوردي (ت ٤٥٠ هـ)',
    ),
  ),
  LibraryBook(
    id: 'al_akhlaq_wal_siyar',
    titleAr: 'الأخلاق والسير في مداواة النفوس',
    titleEn: 'Al-Akhlaq wal-Siyar',
    authorAr: 'الإمام ابن حزم الأندلسي',
    authorEn: 'Imam Ibn Hazm al-Andalusi',
    deathYearAh: 456,
    pages: 95,
    descKey: 'book_desc.al_akhlaq_wal_siyar',
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_akhlaq_wal_siyar.json',
      sizeBytes: 52464,
      sourceLabel:
          'المكتبة الشاملة — الأخلاق والسير في مداواة النفوس، لابن حزم '
              'الأندلسي (ت ٤٥٦ هـ)',
    ),
  ),
  LibraryBook(
    id: 'bidayat_al_hidayah',
    titleAr: 'بداية الهداية',
    titleEn: 'Bidayat al-Hidayah',
    authorAr: 'الإمام أبو حامد الغزالي',
    authorEn: 'Imam Abu Hamid al-Ghazali',
    deathYearAh: 505,
    pages: 70,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/bidayat_al_hidayah.json',
      sizeBytes: 42066,
      sourceLabel:
          'المكتبة الشاملة — بداية الهداية، لأبي حامد الغزالي (ت ٥٠٥ هـ)',
    ),
  ),
  LibraryBook(
    id: 'lataif_al_maarif',
    titleAr: 'لطائف المعارف فيما لمواسم العام من الوظائف',
    titleEn: 'Lataif al-Maarif',
    authorAr: 'الحافظ ابن رجب الحنبلي',
    authorEn: 'al-Hafiz Ibn Rajab al-Hanbali',
    deathYearAh: 795,
    pages: 348,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/lataif_al_maarif.json',
      sizeBytes: 301296,
      sourceLabel:
          'المكتبة الشاملة — لطائف المعارف فيما لمواسم العام من '
              'الوظائف، لابن رجب الحنبلي (ت ٧٩٥ هـ)، دار ابن حزم',
    ),
  ),
  LibraryBook(
    id: 'risalat_al_mustarshidin',
    titleAr: 'رسالة المسترشدين',
    titleEn: 'Risalat al-Mustarshidin',
    authorAr: 'الإمام الحارث المحاسبي',
    authorEn: 'Imam al-Harith al-Muhasibi',
    deathYearAh: 243,
    pages: 183,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/risalat_al_mustarshidin.json',
      sizeBytes: 17849,
      sourceLabel:
          'المكتبة الشاملة — رسالة المسترشدين، للحارث المحاسبي (ت ٢٤٣ هـ)',
    ),
  ),
  LibraryBook(
    id: 'maqasid_al_riayah',
    titleAr: 'مقاصد الرعاية لحقوق الله عز وجل أو مختصر رعاية المحاسبي',
    titleEn: 'Maqasid al-Riayah',
    authorAr: 'العز بن عبد السلام',
    authorEn: 'al-Izz ibn Abd al-Salam',
    deathYearAh: 660,
    pages: 175,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/maqasid_al_riayah.json',
      sizeBytes: 73215,
      sourceLabel:
          'المكتبة الشاملة — مقاصد الرعاية لحقوق الله عز وجل، للعز بن '
              'عبد السلام (ت ٦٦٠ هـ)، وهو اختصاره لكتاب «الرعاية» للحارث '
              'المحاسبي، تحقيق إياد خالد الطباع',
    ),
  ),
  LibraryBook(
    id: 'tahdhib_al_akhlaq',
    titleAr: 'تهذيب الأخلاق وتطهير الأعراق',
    titleEn: 'Tahdhib al-Akhlaq',
    authorAr: 'ابن مسكويه',
    authorEn: 'Ibn Miskawayh',
    deathYearAh: 421,
    pages: 228,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tahdhib_al_akhlaq.json',
      sizeBytes: 116940,
      sourceLabel:
          'المكتبة الشاملة — تهذيب الأخلاق وتطهير الأعراق، لابن مسكويه '
              '(ت ٤٢١ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 1 — آداب الطلب — ما يُقرأ قبل أي متن
  LibraryBook(
    id: 'jami_bayan_al_ilm',
    titleAr: 'جامع بيان العلم وفضله',
    titleEn: 'Jami Bayan al-Ilm wa Fadlih',
    authorAr: 'الحافظ ابن عبد البر',
    authorEn: 'al-Hafiz Ibn Abd al-Barr',
    deathYearAh: 463,
    pages: 1227,
    descKey: 'book_desc.jami_bayan_al_ilm',
    category: BookCategory.talibIlm,
    shelfOrder: 1,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/jami_bayan_al_ilm.json',
      sizeBytes: 409010,
      sourceLabel:
          'المكتبة الشاملة — جامع بيان العلم وفضله، لابن عبد البر (ت '
              '٤٦٣ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 1 — آداب الطلب — ما يُقرأ قبل أي متن
  LibraryBook(
    id: 'tadhkirat_al_sami_wal_mutakallim',
    titleAr: 'تذكرة السامعِ والمتكلم في أَدب العالم والمتعلم',
    titleEn: 'Tadhkirat al-Sami wal-Mutakallim',
    authorAr: 'بدر الدين ابن جماعة',
    authorEn: 'Badr al-Din Ibn Jamaah',
    deathYearAh: 733,
    pages: 236,
    descKey: 'book_desc.tadhkirat_al_sami_wal_mutakallim',
    category: BookCategory.talibIlm,
    shelfOrder: 1,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/tadhkirat_al_sami_wal_mutakallim.json',
      sizeBytes: 57173,
      sourceLabel:
          'المكتبة الشاملة — تذكرة السامع والمتكلم في أدب العالم '
              'والمتعلم، لابن جماعة (ت ٧٣٣ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 1 — آداب الطلب — ما يُقرأ قبل أي متن
  LibraryBook(
    id: 'adab_al_imla_wal_istimla',
    titleAr: 'أدب الاملاء والاستملاء',
    titleEn: 'Adab al-Imla wal-Istimla',
    authorAr: 'الإمام أبو سعد السمعاني',
    authorEn: 'Imam Abu Sad al-Samani',
    deathYearAh: 562,
    pages: 180,
    category: BookCategory.talibIlm,
    shelfOrder: 1,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/adab_al_imla_wal_istimla.json',
      sizeBytes: 123373,
      sourceLabel:
          'المكتبة الشاملة — أدب الإملاء والاستملاء، لأبي سعد السمعاني '
              '(ت ٥٦٢ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 2 — المتون الأولى — الآلة التي يُقرأ بها
  LibraryBook(
    id: 'al_waraqat',
    titleAr: 'الورقات',
    titleEn: 'Al-Waraqat',
    authorAr: 'إمام الحرمين الجويني',
    authorEn: 'Imam al-Haramayn al-Juwayni',
    deathYearAh: 478,
    pages: 31,
    descKey: 'book_desc.al_waraqat',
    category: BookCategory.talibIlm,
    shelfOrder: 2,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_waraqat.json',
      sizeBytes: 6768,
      sourceLabel:
          'المكتبة الشاملة — الورقات في أصول الفقه، لإمام الحرمين '
              'الجويني (ت ٤٧٨ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 2 — المتون الأولى — الآلة التي يُقرأ بها
  LibraryBook(
    id: 'al_ajurrumiyyah',
    titleAr: 'متن الآجرومية',
    titleEn: 'Al-Ajurrumiyyah',
    authorAr: 'ابن آجُرُّوم الصنهاجي',
    authorEn: 'Ibn Ajurrum al-Sanhaji',
    deathYearAh: 723,
    pages: 23,
    descKey: 'book_desc.al_ajurrumiyyah',
    category: BookCategory.talibIlm,
    shelfOrder: 2,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_ajurrumiyyah.json',
      sizeBytes: 7150,
      sourceLabel:
          'المكتبة الشاملة — الآجرومية، لابن آجروم الصنهاجي (ت ٧٢٣ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 3 — التوسّع — الأصول وعلوم القرآن
  LibraryBook(
    id: 'al_luma_fi_usul_al_fiqh',
    titleAr: 'اللمع في أصول الفقه',
    titleEn: 'Al-Luma fi Usul al-Fiqh',
    authorAr: 'الإمام أبو إسحاق الشيرازي',
    authorEn: 'Imam Abu Ishaq al-Shirazi',
    deathYearAh: 476,
    pages: 134,
    category: BookCategory.talibIlm,
    shelfOrder: 3,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_luma_fi_usul_al_fiqh.json',
      sizeBytes: 73953,
      sourceLabel:
          'المكتبة الشاملة — اللمع في أصول الفقه، لأبي إسحاق الشيرازي '
              '(ت ٤٧٦ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 3 — التوسّع — الأصول وعلوم القرآن
  LibraryBook(
    id: 'al_faqih_wal_mutafaqqih',
    titleAr: 'الفقيه و المتفقه',
    titleEn: 'Al-Faqih wal-Mutafaqqih',
    authorAr: 'الخطيب البغدادي',
    authorEn: 'al-Khatib al-Baghdadi',
    deathYearAh: 463,
    pages: 562,
    category: BookCategory.talibIlm,
    shelfOrder: 3,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_faqih_wal_mutafaqqih.json',
      sizeBytes: 389556,
      sourceLabel:
          'المكتبة الشاملة — الفقيه والمتفقه، للخطيب البغدادي (ت ٤٦٣ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 4 — المقاصد — لماذا شُرع الحكم
  LibraryBook(
    id: 'qawaid_al_ahkam',
    titleAr: 'قواعد الأحكام في مصالح الأنام',
    titleEn: 'Qawaid al-Ahkam fi Masalih al-Anam',
    authorAr: 'العز بن عبد السلام',
    authorEn: 'al-Izz ibn Abd al-Salam',
    deathYearAh: 660,
    pages: 255,
    descKey: 'book_desc.qawaid_al_ahkam',
    category: BookCategory.talibIlm,
    shelfOrder: 4,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qawaid_al_ahkam.json',
      sizeBytes: 398215,
      sourceLabel:
          'المكتبة الشاملة — قواعد الأحكام في مصالح الأنام، للعز بن عبد '
              'السلام (ت ٦٦٠ هـ)',
    ),
  ),
  // ══════════════════════════════════════════════════════════════════════
  // 2026-09-17 — «اشهر وافضل الكتب في تنمية الذات واداب النفس» و«قسم
  // وتسميه طالب العلم … الكتب المتدرجة … المنهج الوسطي المعتدل بتدرج».
  //
  // The library held 99 tazkiyah books and not one by الغزالي، ابن رجب،
  // الشاطبي، الماوردي، ابن حزم، المحاسبي، الخطيب البغدادي or ابن عبد البر —
  // measured by grepping each name over this file and getting zero. It was
  // almost entirely ابن أبي الدنيا and ابن الجوزي.
  //
  // Every id came from the LOCAL Shamela title index, never from Shamela's
  // own search, which searches inside books and returns a commentary above
  // the book it comments on (trap #17). Every `sizeBytes` is what R2
  // answered on a HEAD after the upload, not what the local file measured.
  //
  // الاعتصام للشاطبي is deliberately absent while الموافقات is here: he asked
  // to stay far from تشدد, and الموافقات is the مقاصد book.
  // ══════════════════════════════════════════════════════════════════════
  LibraryBook(
    id: 'qut_al_qulub',
    titleAr: 'قوت القلوب في معاملة المحبوب ووصف طريق المريد إلى مقام التوحيد',
    titleEn: 'Qut al-Qulub',
    authorAr: 'الإمام أبو طالب المكي',
    authorEn: 'Imam Abu Talib al-Makki',
    deathYearAh: 386,
    pages: 488,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/qut_al_qulub.json',
      sizeBytes: 1020942,
      sourceLabel:
          'المكتبة الشاملة — قوت القلوب في معاملة المحبوب، لأبي طالب '
              'المكي (ت ٣٨٦ هـ)، تحقيق د. عاصم إبراهيم الكيالي',
    ),
  ),
  LibraryBook(
    id: 'al_adab_al_shariyyah',
    titleAr: 'الآداب الشرعية والمنح المرعية',
    titleEn: 'Al-Adab al-Shariyyah',
    authorAr: 'الإمام ابن مفلح المقدسي',
    authorEn: 'Imam Ibn Muflih al-Maqdisi',
    deathYearAh: 763,
    pages: 613,
    category: BookCategory.adab,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_adab_al_shariyyah.json',
      sizeBytes: 1182599,
      sourceLabel:
          'المكتبة الشاملة — الآداب الشرعية والمنح المرعية، لابن مفلح '
              'المقدسي (ت ٧٦٣ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 1 — آداب الطلب — ما يُقرأ قبل أي متن
  LibraryBook(
    id: 'al_jami_li_akhlaq_al_rawi',
    titleAr: 'الجامع لأخلاق الراوي وآداب السامع',
    titleEn: 'Al-Jami li-Akhlaq al-Rawi',
    authorAr: 'الخطيب البغدادي',
    authorEn: 'al-Khatib al-Baghdadi',
    deathYearAh: 463,
    pages: 416,
    category: BookCategory.talibIlm,
    shelfOrder: 1,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_jami_li_akhlaq_al_rawi.json',
      sizeBytes: 414145,
      sourceLabel:
          'المكتبة الشاملة — الجامع لأخلاق الراوي وآداب السامع، للخطيب '
              'البغدادي (ت ٤٦٣ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 2 — المتون الأولى — الآلة التي يُقرأ بها
  LibraryBook(
    id: 'muqaddimat_ibn_al_salah',
    titleAr: 'معرفة أنواع علوم الحديث، ويُعرف بمقدمة ابن الصلاح',
    titleEn: 'Muqaddimat Ibn al-Salah',
    authorAr: 'الإمام ابن الصلاح',
    authorEn: 'Imam Ibn al-Salah',
    deathYearAh: 643,
    pages: 408,
    descKey: 'book_desc.muqaddimat_ibn_al_salah',
    category: BookCategory.talibIlm,
    shelfOrder: 2,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/muqaddimat_ibn_al_salah.json',
      sizeBytes: 188725,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — معرفة أنواع علوم الحديث (مقدمة ابن '
              'الصلاح)، لابن الصلاح (ت ٦٤٣ هـ)، تحقيق نور الدين عتر',
    ),
  ),
  // طالب العلم، المرحلة 3 — التوسّع — الأصول وعلوم القرآن
  LibraryBook(
    id: 'al_risalah_lil_shafii',
    titleAr: 'الرسالة',
    titleEn: 'Al-Risalah',
    authorAr: 'الإمام محمد بن إدريس الشافعي',
    authorEn: 'Imam Muhammad ibn Idris al-Shafii',
    deathYearAh: 204,
    pages: 601,
    descKey: 'book_desc.al_risalah_lil_shafii',
    category: BookCategory.talibIlm,
    shelfOrder: 3,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_risalah_lil_shafii.json',
      sizeBytes: 399713,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — الرسالة، للإمام الشافعي (ت ٢٠٤ هـ)',
    ),
  ),
  // ══════════════════════════════════════════════════════════════════════
  // 2026-09-17 — «اشهر وافضل الكتب في تنمية الذات واداب النفس» و«قسم
  // وتسميه طالب العلم … الكتب المتدرجة … المنهج الوسطي المعتدل بتدرج».
  //
  // The library held 99 tazkiyah books and not one by الغزالي، ابن رجب،
  // الشاطبي، الماوردي، ابن حزم، المحاسبي، الخطيب البغدادي or ابن عبد البر —
  // measured by grepping each name over this file and getting zero. It was
  // almost entirely ابن أبي الدنيا and ابن الجوزي.
  //
  // Every id came from the LOCAL Shamela title index, never from Shamela's
  // own search, which searches inside books and returns a commentary above
  // the book it comments on (trap #17). Every `sizeBytes` is what R2
  // answered on a HEAD after the upload, not what the local file measured.
  //
  // الاعتصام للشاطبي is deliberately absent while الموافقات is here: he asked
  // to stay far from تشدد, and الموافقات is the مقاصد book.
  // ══════════════════════════════════════════════════════════════════════
  LibraryBook(
    id: 'al_risalah_al_qushayriyyah',
    titleAr: 'الرسالة القشيرية',
    titleEn: 'Al-Risalah al-Qushayriyyah',
    authorAr: 'الإمام أبو القاسم القشيري',
    authorEn: 'Imam Abu al-Qasim al-Qushayri',
    deathYearAh: 465,
    pages: 585,
    category: BookCategory.tazkiyah,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_risalah_al_qushayriyyah.json',
      sizeBytes: 317802,
      sourceLabel:
          'المكتبة الشاملة — الرسالة القشيرية، لأبي القاسم القشيري (ت '
              '٤٦٥ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 3 — التوسّع — الأصول وعلوم القرآن
  LibraryBook(
    id: 'al_burhan_fi_ulum_al_quran',
    titleAr: 'البرهان في علوم القرآن',
    titleEn: 'Al-Burhan fi Ulum al-Quran',
    authorAr: 'الإمام بدر الدين الزركشي',
    authorEn: 'Imam Badr al-Din al-Zarkashi',
    deathYearAh: 794,
    pages: 516,
    category: BookCategory.talibIlm,
    shelfOrder: 3,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_burhan_fi_ulum_al_quran.json',
      sizeBytes: 1170450,
      sourceLabel:
          'المكتبة الشاملة — البرهان في علوم القرآن، لبدر الدين الزركشي '
              '(ت ٧٩٤ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 3 — التوسّع — الأصول وعلوم القرآن
  LibraryBook(
    id: 'al_itqan_fi_ulum_al_quran',
    titleAr: 'الإتقان في علوم القرآن',
    titleEn: 'Al-Itqan fi Ulum al-Quran',
    authorAr: 'الحافظ جلال الدين السيوطي',
    authorEn: 'al-Hafiz Jalal al-Din al-Suyuti',
    deathYearAh: 911,
    pages: 396,
    descKey: 'book_desc.al_itqan_fi_ulum_al_quran',
    category: BookCategory.talibIlm,
    shelfOrder: 3,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_itqan_fi_ulum_al_quran.json',
      sizeBytes: 852806,
      sourceLabel:
          'المكتبة الشاملة — الإتقان في علوم القرآن، لجلال الدين '
              'السيوطي (ت ٩١١ هـ)',
    ),
  ),
  // طالب العلم، المرحلة 4 — المقاصد — لماذا شُرع الحكم
  LibraryBook(
    id: 'al_muwafaqat',
    titleAr: 'الموافقات',
    titleEn: 'Al-Muwafaqat',
    authorAr: 'الإمام أبو إسحاق الشاطبي',
    authorEn: 'Imam Abu Ishaq al-Shatibi',
    deathYearAh: 790,
    pages: 606,
    descKey: 'book_desc.al_muwafaqat',
    category: BookCategory.talibIlm,
    shelfOrder: 4,
    textEdition: TextEdition(
      url:
          '${AppConfig.contentBaseUrl}/books/text/al_muwafaqat.json',
      sizeBytes: 2280034,
      editorNotesRemoved: true,
      sourceLabel:
          'المكتبة الشاملة — الموافقات، لأبي إسحاق الشاطبي (ت ٧٩٠ هـ)',
    ),
  ),
];

/// One book by its id, or null.
///
/// Built once and cached: `isBookDownloaded` asks for it on every library card
/// and a linear scan of the whole catalogue per card is a scan nobody needs.
final Map<String, LibraryBook> _byId = {
  for (final b in libraryBookCatalog) b.id: b,
};

LibraryBook? bookById(String id) => _byId[id];
