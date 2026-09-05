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
  static Future<BookText> fromFile(String path) async {
    final bytes = await File(path).readAsBytes();
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

  factory BookText.fromJson(Map<String, dynamic> j) {
    final m = (j['meta'] as Map).cast<String, dynamic>();
    return BookText(
      meta: BookTextMeta(
        titleAr: (m['titleAr'] ?? '') as String,
        authorAr: (m['authorAr'] ?? '') as String,
        sourceLabel: (m['sourceLabel'] ?? '') as String,
        shamelaUrl: (m['shamelaUrl'] ?? '') as String,
        printMatches: (m['printMatches'] ?? false) as bool,
        printReliable: (m['printReliable'] ?? false) as bool,
        pageCount: (m['pageCount'] ?? 0) as int,
        sectionCount: (m['sectionCount'] ?? 0) as int,
      ),
      toc: [
        for (final t in (j['toc'] as List? ?? const []))
          BookSection(
            title: (t['title'] ?? '') as String,
            page: (t['page'] ?? 0) as int,
            pageIndex: (t['pageIndex'] ?? 0) as int,
            level: (t['level'] ?? 1) as int,
          ),
      ],
      pages: [
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
      ],
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

  /// True only when [printMatches] AND the `printedPage` numbers actually run
  /// monotonically (some Shamela books carry the flag but have out-of-order
  /// page numbers in stretches — e.g. Riyad as-Salihin / book 12014). The
  /// reader only shows printed-page numbers / "go to printed page" when this
  /// is true; otherwise it navigates by sequence position + the فهرس.
  final bool printReliable;
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
