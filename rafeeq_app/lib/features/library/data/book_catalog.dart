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
  final String downloadUrl;
  final String fileName;
  final int approxSizeBytes;

  /// The archive.org item this came from, e.g. "archive.org/details/rsnawwy"
  /// — kept so provenance is always one tap away from the UI, never buried.
  final String sourceUrl;

  const LibraryBook({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.authorAr,
    required this.authorEn,
    required this.authorDeathAr,
    required this.descriptionAr,
    required this.downloadUrl,
    required this.fileName,
    required this.approxSizeBytes,
    required this.sourceUrl,
  });
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
    downloadUrl: 'https://archive.org/download/rsnawwy/rs-mohaqaq.pdf',
    fileName: 'riyad_as_salihin.pdf',
    approxSizeBytes: 15770224, // measured with curl 2026-09-02: 15.77 MB
    sourceUrl: 'https://archive.org/details/rsnawwy',
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
    downloadUrl:
        'https://archive.org/download/menhaj-alkasdeen-dar-alhejaz/'
        '%D9%85%D8%AE%D8%AA%D8%B5%D8%B1%20%D9%85%D9%86%D9%87%D8%A7%D8%AC%20'
        '%D8%A7%D9%84%D9%82%D8%A7%D8%B5%D8%AF%D9%8A%D9%86%20-%20%D8%B7%20'
        '%D8%A7%D9%84%D8%AD%D8%AC%D8%A7%D8%B2.pdf',
    fileName: 'mukhtasar_minhaj_al_qasidin.pdf',
    approxSizeBytes: 29648193, // measured with curl 2026-09-02: 29.65 MB
    sourceUrl: 'https://archive.org/details/menhaj-alkasdeen-dar-alhejaz',
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
    downloadUrl: 'https://archive.org/download/fawaeedIbnqaem/fawaeed.pdf',
    fileName: 'al_fawaid.pdf',
    approxSizeBytes: 6285456, // measured with curl 2026-09-02: 6.29 MB
    sourceUrl: 'https://archive.org/details/fawaeedIbnqaem',
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
    downloadUrl:
        'https://archive.org/download/aakamel18_gmail_20190131/'
        '%D8%B5%D9%8A%D8%AF%20%D8%A7%D9%84%D8%AE%D8%A7%D8%B7%D8%B1%20-%20'
        '%D9%85%D8%AF%D8%A7%D8%B1%20%D8%A7%D9%84%D9%88%D8%B7%D9%86.pdf',
    fileName: 'sayd_al_khatir.pdf',
    approxSizeBytes: 16347265, // measured with curl 2026-09-02: 16.35 MB
    sourceUrl: 'https://archive.org/details/aakamel18_gmail_20190131',
  ),
];
