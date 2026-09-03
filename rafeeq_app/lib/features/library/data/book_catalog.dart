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
  final String fileName;
  final int approxSizeBytes;

  /// Full printed-edition + editor line, shown in the reader at all times
  /// (e.g. "المكتبة الشاملة — ت. شعيب الأرنؤوط، مؤسسة الرسالة، ط٣ ١٤١٩هـ").
  final String sourceLabel;

  /// True only when the text is machine-extracted (OCR). Never true for a
  /// Shamela edition — Shamela is typed text — but the reader honours it with
  /// an honest "نص مستخرَج آلياً" badge if a future OCR source is ever added.
  final bool isOcr;

  const TextEdition({
    required this.url,
    required this.fileName,
    required this.approxSizeBytes,
    required this.sourceLabel,
    this.isOcr = false,
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

  /// e.g. "676 هـ" — shown so a reader can see at a glance this is a
  /// centuries-old, public-domain classical text, not a modern copyrighted
  /// work.
  final String authorDeathAr;
  final String descriptionAr;
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
    required this.authorDeathAr,
    required this.descriptionAr,
    required this.category,
    this.downloadUrl,
    this.fileName,
    this.approxSizeBytes,
    this.sourceUrl,
    this.textEdition,
  }) : assert(downloadUrl != null || textEdition != null,
            'a book needs at least one edition');

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
  LibraryBook(
    id: 'riyad_as_salihin',
    titleAr: 'رياض الصالحين',
    titleEn: 'Riyad as-Salihin',
    authorAr: 'الإمام أبو زكريا يحيى بن شرف النووي',
    authorEn: 'Imam Yahya ibn Sharaf an-Nawawi',
    authorDeathAr: 'توفي 676 هـ',
    descriptionAr:
        'أشهر مختصرات الحديث في الأخلاق والآداب والرقائق، جمعه الإمام النووي '
        'من أحاديث الصحيحين وغيرهما من كتب السنة.',
    category: BookCategory.hadith,
    downloadUrl: 'https://archive.org/download/rsnawwy/rs-mohaqaq.pdf',
    fileName: 'riyad_as_salihin.pdf',
    approxSizeBytes: 15770224, // measured with curl 2026-09-02: 15.77 MB
    sourceUrl: 'https://archive.org/details/rsnawwy',
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/riyad_as_salihin.json',
      fileName: 'riyad_as_salihin_text.json',
      approxSizeBytes: 1840046, // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — رياض الصالحين، تحقيق شعيب الأرنؤوط، '
          'مؤسسة الرسالة، بيروت، الطبعة الثالثة ١٤١٩هـ/١٩٩٨م',
    ),
  ),
  LibraryBook(
    id: 'mukhtasar_minhaj_al_qasidin',
    titleAr: 'مختصر منهاج القاصدين',
    titleEn: 'Mukhtasar Minhaj al-Qasidin',
    authorAr: 'الإمام موفق الدين ابن قدامة المقدسي',
    authorEn: 'Imam Ibn Qudamah al-Maqdisi',
    authorDeathAr: 'توفي 689 هـ',
    descriptionAr:
        'اختصار ابن قدامة المقدسي لكتاب "منهاج القاصدين" لابن الجوزي في '
        'التزكية والأخلاق والزهد، من أهم كتب السلوك عند أهل السنة.',
    category: BookCategory.tazkiyah,
    downloadUrl:
        'https://archive.org/download/menhaj-alkasdeen-dar-alhejaz/'
        '%D9%85%D8%AE%D8%AA%D8%B5%D8%B1%20%D9%85%D9%86%D9%87%D8%A7%D8%AC%20'
        '%D8%A7%D9%84%D9%82%D8%A7%D8%B5%D8%AF%D9%8A%D9%86%20-%20%D8%B7%20'
        '%D8%A7%D9%84%D8%AD%D8%AC%D8%A7%D8%B2.pdf',
    fileName: 'mukhtasar_minhaj_al_qasidin.pdf',
    approxSizeBytes: 29648193, // measured with curl 2026-09-02: 29.65 MB
    sourceUrl: 'https://archive.org/details/menhaj-alkasdeen-dar-alhejaz',
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/mukhtasar_minhaj_al_qasidin.json',
      fileName: 'mukhtasar_minhaj_al_qasidin_text.json',
      approxSizeBytes: 1214930,  // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — مختصر منهاج القاصدين، تقديم محمد أحمد '
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
    authorDeathAr: 'توفي 751 هـ',
    descriptionAr:
        'من أنفس كتب ابن القيم، فوائد ومواعظ وحكم متفرقة في العقيدة والسلوك '
        'والتربية، غير مرتبة على أبواب بل على خواطر الإيمان.',
    category: BookCategory.tazkiyah,
    downloadUrl: 'https://archive.org/download/fawaeedIbnqaem/fawaeed.pdf',
    fileName: 'al_fawaid.pdf',
    approxSizeBytes: 6285456, // measured with curl 2026-09-02: 6.29 MB
    sourceUrl: 'https://archive.org/details/fawaeedIbnqaem',
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_fawaid.json',
      fileName: 'al_fawaid_text.json',
      approxSizeBytes: 738171,  // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — الفوائد لابن القيم، دار الكتب العلمية، '
          'بيروت، الطبعة الثانية ١٣٩٣هـ/١٩٧٣م',
    ),
  ),
  LibraryBook(
    id: 'sayd_al_khatir',
    titleAr: 'صيد الخاطر',
    titleEn: 'Sayd al-Khatir',
    authorAr: 'الإمام أبو الفرج ابن الجوزي',
    authorEn: 'Imam Ibn al-Jawzi',
    authorDeathAr: 'توفي 597 هـ',
    descriptionAr:
        'خواطر ابن الجوزي وتأملاته في النفس والدين والدنيا، من أرقّ ما كُتب '
        'في الوعظ والتربية الروحية عند علماء أهل السنة.',
    category: BookCategory.tazkiyah,
    downloadUrl:
        'https://archive.org/download/aakamel18_gmail_20190131/'
        '%D8%B5%D9%8A%D8%AF%20%D8%A7%D9%84%D8%AE%D8%A7%D8%B7%D8%B1%20-%20'
        '%D9%85%D8%AF%D8%A7%D8%B1%20%D8%A7%D9%84%D9%88%D8%B7%D9%86.pdf',
    fileName: 'sayd_al_khatir.pdf',
    approxSizeBytes: 16347265, // measured with curl 2026-09-02: 16.35 MB
    sourceUrl: 'https://archive.org/details/aakamel18_gmail_20190131',
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/sayd_al_khatir.json',
      fileName: 'sayd_al_khatir_text.json',
      approxSizeBytes: 1559023,  // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — صيد الخاطر، بعناية حسن المساحي سويدان، '
          'دار القلم، دمشق، الطبعة الأولى ١٤٢٥هـ/٢٠٠٤م',
    ),
  ),
  LibraryBook(
    id: 'al_ubudiyyah',
    titleAr: 'العبودية',
    titleEn: "Al-'Ubudiyyah",
    authorAr: 'شيخ الإسلام ابن تيمية',
    authorEn: 'Shaykh al-Islam Ibn Taymiyyah',
    authorDeathAr: 'توفي 728 هـ',
    descriptionAr:
        'رسالة ابن تيمية في تحقيق معنى العبودية لله وحده، وأن كمال العبد في '
        'كمال عبوديته لربه؛ من أهم ما كُتب في هذا الباب.',
    category: BookCategory.aqidah,
    // Verified with curl -L GET on 2026-09-02: HTTP 200, application/pdf,
    // Content-Length 3382545 (item is an image-container scan; the underlying
    // text is public domain — Ibn Taymiyyah d. 728 AH — and the item carries
    // no license restriction).
    downloadUrl: 'https://archive.org/download/20201231_20201231_1341/'
        '%D8%A7%D9%84%D8%B9%D8%A8%D9%88%D8%AF%D9%8A%D8%A9%20-%20'
        '%D8%A7%D8%A8%D9%86%20%D8%AA%D9%8A%D9%85%D9%8A%D8%A9.pdf',
    fileName: 'al_ubudiyyah.pdf',
    approxSizeBytes: 3382545,
    sourceUrl: 'https://archive.org/details/20201231_20201231_1341',
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_ubudiyyah.json',
      fileName: 'al_ubudiyyah_text.json',
      approxSizeBytes: 238715,  // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — العبودية لابن تيمية، تحقيق محمد زهير '
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
    authorDeathAr: 'توفي 728 هـ',
    descriptionAr:
        'رسالة ابن تيمية الشهيرة في اعتقاد أهل السنة والجماعة، كتبها إجابة '
        'لطلب قاضٍ من واسط، ومن أكثر متون العقيدة شرحاً وتداولاً عند أهل السنة.',
    category: BookCategory.aqidah,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_aqidah_al_wasitiyyah.json',
      fileName: 'al_aqidah_al_wasitiyyah_text.json',
      approxSizeBytes: 119516, // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — العقيدة الواسطية لابن تيمية، تحقيق '
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
    authorDeathAr: 'توفي نحو 320 هـ',
    descriptionAr:
        'من أشهر مصنفات الحكيم الترمذي في شرح أصول من الحديث النبوي '
        'بأسلوبٍ صوفيٍّ تربويٍّ متميز. تنبيه أمانةً: يضم الكتاب — كحال '
        'مصنفه المعروف عند أهل الحديث — عدداً من الأحاديث الضعيفة وغير '
        'الثابتة إلى جانب الصحيح، فليُقرأ بهذا الاعتبار.',
    category: BookCategory.hadith,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/nawadir_al_usul.json',
      fileName: 'nawadir_al_usul_text.json',
      approxSizeBytes: 2780973, // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — نوادر الأصول في أحاديث الرسول للحكيم '
          'الترمذي، تحقيق عبد الرحمن عميرة، دار الجيل، بيروت (4 أجزاء)',
    ),
  ),
  LibraryBook(
    id: 'al_samt_wa_adab_al_lisan',
    titleAr: 'الصمت وآداب اللسان',
    titleEn: 'Al-Samt wa Adab al-Lisan',
    authorAr: 'الإمام ابن أبي الدنيا',
    authorEn: 'Ibn Abi al-Dunya',
    authorDeathAr: 'توفي 281 هـ',
    descriptionAr:
        'مصنَّف ابن أبي الدنيا في فضل الصمت وحفظ اللسان وآفات الكلام، جمع '
        'فيه أحاديث وآثاراً في آداب الكلام والصمت عند السلف.',
    category: BookCategory.adab,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/al_samt_wa_adab_al_lisan.json',
      fileName: 'al_samt_wa_adab_al_lisan_text.json',
      approxSizeBytes: 563635, // built by scripts/build_book_text.py
      sourceLabel: 'المكتبة الشاملة — الصمت وآداب اللسان لابن أبي الدنيا، '
          'تحقيق أبو إسحاق الحويني الأثري، دار الكتاب العربي، بيروت، '
          'الطبعة الأولى ١٤١٠هـ/١٩٩٠م',
    ),
  ),
];
