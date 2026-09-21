import 'dart:convert';
import 'dart:io';

/// Parsed model of a book's **text** edition (the P2-4b "نص" companion to the
/// scanned image PDF).
///
/// The on-disk file is the structured JSON built by
/// `scripts/build_book_text.py` from al-Maktaba al-Shamela and hosted on
/// `tito423/rafeeq-api` (`books/text/<id>.json`). Downloaded on demand by
/// [DownloadManager] under the id `"<book id>_text"`, then read from disk and
/// parsed here — no network once cached.
///
/// JSON shape (see the script's docstring for the authority):
/// ```
/// { "id", "schema": 1,
///   "meta": { "titleAr","authorAr","sourceLabel","shamelaUrl",
///             "printMatches", "pageCount", "sectionCount", "editionCard" },
///   "toc":   [ { "title", "page", "pageIndex", "level" } ],
///   "pages": [ { "p": <printed page number>,
///                "paras": [ { "t": "<text>", "k": "body|aya|ref|head",
///                             "r": "<ayah ref, optional>" } ] } ] }
/// ```
class BookText {
  final BookTextMeta meta;
  final List<BookSection> toc;
  final List<BookPage> pages;

  const BookText({required this.meta, required this.toc, required this.pages});

  /// P3-44: newer uploads are gzip-compressed on R2 (real bandwidth savings
  /// for a reader on mobile data — these files run a few hundred KB to a
  /// few MB of Arabic text, which gzips very well) — `DownloadManager`
  /// streams whatever bytes the server sends straight to disk with no
  /// decompression of its own (`ResponseType.stream` bypasses dio's normal
  /// auto-decompression), so this is the one place that needs to know.
  /// Detected by gzip's own magic bytes (`0x1f 0x8b`), not the file
  /// extension, so an **already-downloaded, still-plain-JSON file from
  /// before this change keeps working** without forcing every reader to
  /// re-download it — real backward compatibility, not just new files.
  static Future<BookText> fromFile(String path) async =>
      fromBytes(await File(path).readAsBytes());

  /// The same, from bytes already in hand - a text bundled as an asset.
  static BookText fromBytes(List<int> bytes) {
    final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    final raw = isGzip
        ? utf8.decode(gzip.decode(bytes))
        : utf8.decode(bytes);
    return BookText.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Shamela occasionally serves a paragraph that is only "..." / "…" / a lone
  /// separator on the first page of a book — skip those so the reader doesn't
  /// open on a stray line of dots.
  static bool _isNoise(String t) {
    final s = t.trim();
    return s.isEmpty || RegExp(r'^[.…·\-_*\s]{1,4}$').hasMatch(s);
  }

  /// Whether [pages]'s printed numbers can be used as a NAVIGATION SCALE.
  ///
  /// «كل الكتب في المكتبة عدادات الصفحات غلط. انا عديت على عشر كتب»
  /// (2026-09-21). The file's own `printReliable` flag was taken at face
  /// value, and it is wrong in a way that reading the numbers exposes at
  /// once: it only ever meant "monotonic", and a **repeated** page number is
  /// monotonic. Counted over the 33 bundled texts:
  ///
  ///  * `mishkat_al_masabih` — 7,436 pages carrying 1,701 distinct printed
  ///    numbers. **5,735 duplicates**, flag `true`.
  ///  * `al_adab_al_mufrad` — 2,010 pages, 433 distinct numbers, 1,577
  ///    duplicates, flag `true`.
  ///  * `musnad_abi_hanifah_abu_nuaym` — 662 pages, 413 duplicates, `true`.
  ///  * and `nataij_al_afkar` (16), `hadith_asma_allah_al_husna` (4),
  ///    `al_amali_al_mutlaqah` (1).
  ///
  /// Shamela splits a printed page into several stream units, so a reader
  /// turning pages watched «صفحة ٢٠٠» sit still for five turns, the slider
  /// run to 7,436 under a label that stopped at 1,771, and «الانتقال إلى
  /// صفحة» land on the first of however many pages share that number. That
  /// is the counter being wrong, and it was wrong in six of the books on the
  /// shelf before a single hosted one was looked at.
  ///
  /// So the flag is no longer believed — it is RECOMPUTED here, from the
  /// numbers actually in the file. A printed scale needs every number to be
  /// positive and each to be strictly greater than the one before it. One
  /// exception, because it is real and harmless: Shamela leaves the cover
  /// leaf unnumbered, so five of the bundled books open with a single
  /// `p == 0` (`al_baith_al_hathith`, `al_idah_fi_manasik_al_hajj_wal_umrah`,
  /// `bulugh_al_maram`, `musnad_abi_hanifah_abu_nuaym`, `tuhfat_al_atfal` —
  /// always index 0, never anywhere else). A leading unnumbered run is
  /// allowed and those pages show their position instead of «صفحة ٠»; see
  /// [printedPageAt].
  static bool _printedNumbersUsable(List<BookPage> pages) {
    var i = 0;
    while (i < pages.length && pages[i].printedPage <= 0) {
      i++;
    }
    if (i >= pages.length) return false;
    for (var k = i + 1; k < pages.length; k++) {
      if (pages[k].printedPage <= pages[k - 1].printedPage) return false;
    }
    return true;
  }

  /// The printed number to show for [index], or null when this book has no
  /// usable printed scale or that particular page carries no number.
  /// A caller that gets null shows the sequence position instead.
  int? printedPageAt(int index) {
    if (!meta.printReliable) return null;
    if (index < 0 || index >= pages.length) return null;
    final p = pages[index].printedPage;
    return p > 0 ? p : null;
  }

  /// First and last numbers on the printed scale, for the ends of the reader's
  /// rail. Skips a leading unnumbered leaf so the rail never starts at zero.
  int get firstPrintedPage =>
      pages.firstWhere((p) => p.printedPage > 0, orElse: () => pages.first)
          .printedPage;
  int get lastPrintedPage => pages.last.printedPage;

  /// Where a table-of-contents entry really starts.
  ///
  /// The entry carries both a printed `page` and a `pageIndex` into [pages],
  /// and in four of the bundled books the generator emitted a `pageIndex`
  /// that does not point at the page it names — `nawasikh_al_quran` 173 of
  /// its 174 entries, `umdat_al_ahkam` 119 of 120, `nuzhat_al_nazar` 101 of
  /// 105, `jami_al_ulum_wal_hikam` 58 of 67, and three of those files also
  /// declare a `pageCount` larger than the `pages` array they ship (945 vs
  /// 940, 211 vs 210, 157 vs 154, 448 vs 428). The فهرس therefore printed one
  /// page number and jumped to a different page — the same complaint from the
  /// other end.
  ///
  /// The printed number is the authority: it is what the entry says and what
  /// the destination page will show. Where the two disagree and the book has
  /// a usable, non-repeating printed scale, the index is re-derived from the
  /// number. Where it cannot be (no scale, or the number is not in the book)
  /// the stated index is kept and clamped into range, which is still better
  /// than throwing.
  static int _resolveSectionIndex(List<BookPage> pages, int stated, int page,
      bool printedUsable) {
    if (pages.isEmpty) return 0;
    final clamped = stated.clamp(0, pages.length - 1);
    if (!printedUsable || page <= 0) return clamped;
    if (pages[clamped].printedPage == page) return clamped;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].printedPage == page) return i;
    }
    return clamped;
  }

  factory BookText.fromJson(Map<String, dynamic> j) {
    final m = (j['meta'] as Map).cast<String, dynamic>();
    final pages = [
      for (final p in (j['pages'] as List? ?? const []))
        BookPage(
          printedPage: (p['p'] ?? 0) as int,
          paras: [
            for (final a in (p['paras'] as List? ?? const []))
              if (!_isNoise((a['t'] ?? '') as String))
                BookPara(
                  text: (a['t'] ?? '') as String,
                  kind: (a['k'] ?? 'body') as String,
                  ref: a['r'] as String?,
                ),
          ],
        ),
    ];
    // Both flags have to hold: the edition has to claim its numbering matches
    // the print, AND the numbers in the file have to behave like a scale.
    final printedUsable = ((m['printMatches'] ?? false) as bool) &&
        ((m['printReliable'] ?? false) as bool) &&
        _printedNumbersUsable(pages);
    final toc = [
      for (final t in (j['toc'] as List? ?? const []))
        BookSection(
          title: (t['title'] ?? '') as String,
          page: (t['page'] ?? 0) as int,
          pageIndex: _resolveSectionIndex(pages, (t['pageIndex'] ?? 0) as int,
              (t['page'] ?? 0) as int, printedUsable),
          level: (t['level'] ?? 1) as int,
        ),
    ];
    return BookText(
      meta: BookTextMeta(
        titleAr: (m['titleAr'] ?? '') as String,
        authorAr: (m['authorAr'] ?? '') as String,
        sourceLabel: (m['sourceLabel'] ?? '') as String,
        shamelaUrl: (m['shamelaUrl'] ?? '') as String,
        printMatches: (m['printMatches'] ?? false) as bool,
        printReliable: printedUsable,
        // COUNTED, never read off the meta block: four bundled files declare
        // a `pageCount` bigger than the `pages` array they actually carry,
        // and `sectionCount` is the same kind of claim.
        pageCount: pages.length,
        sectionCount: toc.length,
      ),
      toc: toc,
      pages: pages,
    );
  }

  /// The 0-based page index whose section a given [pageIndex] falls under —
  /// used to show "current section" in the reader header.
  String sectionTitleForPageIndex(int pageIndex) {
    String current = '';
    for (final s in toc) {
      if (s.pageIndex <= pageIndex) {
        current = s.title;
      } else {
        break;
      }
    }
    return current;
  }
}

class BookTextMeta {
  final String titleAr;
  final String authorAr;

  /// Full edition + editor line, always shown in the reader.
  final String sourceLabel;
  final String shamelaUrl;

  /// Shamela flag `[ترقيم الكتاب موافق للمطبوع]`.
  final bool printMatches;

  /// True only when [printMatches] AND the `printedPage` numbers really form
  /// a scale — positive and strictly increasing, after any leading unnumbered
  /// cover leaf. **Recomputed from the pages at parse time**, never taken from
  /// the file: the flag as shipped only meant "monotonic", which a repeated
  /// page number satisfies, and six of the 33 bundled books carry repeats
  /// (`mishkat_al_masabih` 5,735 of them). See
  /// [BookText._printedNumbersUsable] for the full count and what the reader
  /// saw. The reader only shows printed-page numbers / "go to printed page"
  /// when this is true; otherwise it navigates by sequence position + the
  /// فهرس, which is always right.
  final bool printReliable;
  /// Counted from the parsed document, not read off the file's meta block.
  final int pageCount;
  final int sectionCount;

  const BookTextMeta({
    required this.titleAr,
    required this.authorAr,
    required this.sourceLabel,
    required this.shamelaUrl,
    required this.printMatches,
    required this.printReliable,
    required this.pageCount,
    required this.sectionCount,
  });
}

class BookSection {
  final String title;

  /// Printed page number the section starts on.
  final int page;

  /// Index into [BookText.pages] the section starts on.
  final int pageIndex;

  /// 0 = a major division (كتاب … / مقدمة / خطبة), 1 = a باب/فصل.
  final int level;

  const BookSection({
    required this.title,
    required this.page,
    required this.pageIndex,
    required this.level,
  });
}

class BookPage {
  final int printedPage;
  final List<BookPara> paras;

  const BookPage({required this.printedPage, required this.paras});
}

/// One paragraph. [kind]:
///  * `body` — running text
///  * `aya`  — a Qur'an ayah (rendered in the Quran font); [ref] is its
///             surah/ayah citation when Shamela supplied one
///  * `head` — a bracketed heading Shamela set inline
///  * `ref`  — a bare citation line (rare)
class BookPara {
  final String text;
  final String kind;
  final String? ref;

  const BookPara({required this.text, required this.kind, this.ref});
}
