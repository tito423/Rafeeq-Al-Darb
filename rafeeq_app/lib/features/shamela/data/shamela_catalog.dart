import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/arabic_normalize.dart';

/// One book in al-Maktaba al-Shamela's own catalogue.
class ShamelaBookRef {
  const ShamelaBookRef(this.id, this.title);
  final int id;
  final String title;
}

/// The whole Shamela catalogue on the phone, searched locally.
///
/// Owner, 2026-09-26: search Shamela by book name from inside the app and
/// import the book (GitHub build only - see docs/history/SHAMELA_IMPORT_PLAN.md).
///
/// The site's own title autocomplete (`/ajax/books/`, the select2 box on its
/// search page) ignores the typed text and returns EVERY book - measured
/// 2026-09-26: 8,598 books (8,599 items less the placeholder), 1,679,477 B, 195,186 B gzipped. So it is fetched
/// once, kept on the phone, refreshed weekly, and searched here with the
/// app's own Arabic matching: instant, offline after the first fetch, and
/// one request to Shamela a week instead of one per keystroke.
class ShamelaCatalog {
  ShamelaCatalog._();
  static final ShamelaCatalog instance = ShamelaCatalog._();

  static const _url = 'https://shamela.ws/ajax/books/';
  static const _maxAge = Duration(days: 7);

  List<(ShamelaBookRef, String)>? _books; // (book, normalized title)
  Future<void>? _loading;

  /// How many books the last catalogue on this phone held, for the library's
  /// «استورد أي كتاب من N كتابًا» card - which used to say a number measured
  /// once (8,598 on 2026-09-26) and typed into the translations. Null until
  /// the catalogue has been fetched once.
  static const _countKey = 'shamela_catalog_count';
  static Future<int?> cachedCount() async =>
      (await SharedPreferences.getInstance()).getInt(_countKey);

  Future<void> _remember(List<Object> books) async =>
      (await SharedPreferences.getInstance()).setInt(_countKey, books.length);

  bool get isLoaded => _books != null;
  int get count => _books?.length ?? 0;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'shamela', 'books.json.gz'));
  }

  /// Loads the cached list, fetching it when missing, older than a week, or
  /// when [refresh] is set. A failed refresh keeps the older copy.
  Future<void> load({bool refresh = false}) =>
      _loading ??= _load(refresh).whenComplete(() => _loading = null);

  Future<void> _load(bool refresh) async {
    final file = await _file();
    final fresh =
        file.existsSync() &&
        DateTime.now().difference(file.lastModifiedSync()) < _maxAge;
    if (!fresh || refresh || _books == null && !file.existsSync()) {
      try {
        final res = await Dio().get<List<int>>(
          _url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'X-Requested-With': 'XMLHttpRequest',
              'User-Agent': 'RafeeqAlDarb (Android; personal library)',
            },
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        final bytes = res.data ?? const <int>[];
        // Only a real catalogue replaces the cache: an error page from a
        // busy server (trap #5) must not wipe a good copy.
        final parsed = await Isolate.run(() => _parse(bytes));
        if (parsed.length > 1000) {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(gzip.encode(bytes));
          _books = parsed;
          await _remember(parsed);
          return;
        }
      } catch (_) {
        if (!file.existsSync()) rethrow;
      }
    }
    if (_books != null && !refresh) return;
    final gz = await file.readAsBytes();
    _books = await Isolate.run(() => _parse(gzip.decode(gz)));
    await _remember(_books!);
  }

  static List<(ShamelaBookRef, String)> _parse(List<int> bytes) {
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final items = (j['results'] as Map<String, dynamic>)['items'] as List;
    final out = <(ShamelaBookRef, String)>[];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      final id = int.tryParse('${m['id']}') ?? -1;
      if (id <= 0) continue; // «جميع الكتب», the select2 placeholder
      final title = '${m['text']}'.trim();
      if (title.isEmpty) continue;
      out.add((
        ShamelaBookRef(id, title),
        normalizeArabicLoose(normalizeArabic(title)),
      ));
    }
    return out;
  }

  /// A title asked for by VOICE («الزهد للإمام أحمد ابن حنبل»), not typed.
  ///
  /// [search] wants every word whole, which a spoken request never meets:
  /// Shamela writes «الزهد لأحمد بن حنبل» (id 8494) - «لأحمد» is one word,
  /// «ابن» is «بن», and «الإمام» is not in the title at all. Here a word
  /// matches with its attached «و/ل/لل/ب» dropped on either side, «ابن» =
  /// «بن», and titles are ranked by how many of the words they hold; the
  /// first word (the book's own name, as people say it) must be among them.
  /// `full` is true when the best title holds EVERY word.
  ({List<ShamelaBookRef> books, bool full}) searchSpoken(String said,
      {int limit = 40}) {
    final books = _books;
    final words = [
      for (final w in normalizeArabicLoose(normalizeArabic(said.trim()))
          .split(RegExp(r'\s+')))
        if (_stem(w).isNotEmpty && !_spokenOnly.contains(_stem(w))) _stem(w),
    ];
    if (books == null || words.isEmpty) return (books: const [], full: false);
    final ranked = <(int, ShamelaBookRef)>[];
    for (final (book, norm) in books) {
      final title = {
        for (final t in norm.split(RegExp(r'[^ء-ي0-9a-z٠-٩]+'))) _stem(t),
      };
      if (!title.contains(words.first)) continue;
      final hits = words.where(title.contains).length;
      if (hits * 2 >= words.length) ranked.add((hits, book));
    }
    ranked.sort((a, b) {
      final r = b.$1.compareTo(a.$1);
      return r != 0 ? r : a.$2.title.length.compareTo(b.$2.title.length);
    });
    return (
      books: [for (final r in ranked.take(limit)) r.$2],
      full: ranked.isNotEmpty && ranked.first.$1 == words.length,
    );
  }

  /// Honorifics people say and titles do not carry.
  static const _spokenOnly = {'امام', 'الامام', 'شيخ', 'الشيخ', 'العلامه', 'الحافظ'};

  static String _stem(String w) {
    var s = w;
    if (s.length > 3 && s.startsWith('و')) s = s.substring(1);
    if (s.length > 4 && s.startsWith('لل')) {
      s = 'ال${s.substring(2)}';
    } else if (s.length > 3 && (s.startsWith('ل') || s.startsWith('ب'))) {
      // Over-stripping («لسان» -> «سان») is harmless: title and request
      // are stemmed the same way.
      s = s.substring(1);
    }
    return s == 'ابن' ? 'بن' : s;
  }

  /// Titles matching [query], best first: the whole title, then titles
  /// starting with it, then titles holding every query word whole, then
  /// titles holding them anywhere. At most [limit].
  List<ShamelaBookRef> search(String query, {int limit = 80}) {
    final books = _books;
    // A pasted Shamela link («shamela.ws/book/9632/15») or a bare book id
    // finds that book - copying a link from the site is the quickest way
    // to name a book exactly.
    // Spaces are ignored inside a link: the Xiaomi keyboard turned a typed
    // «shamela.ws» into «shamela. ws» and the book was not found (seen on
    // the phone, 2026-09-27).
    final link = RegExp(r'shamela\.ws/book/(\d+)')
            .firstMatch(query.replaceAll(RegExp(r'\s+'), '')) ??
        RegExp(r'^\s*(\d{1,7})\s*$').firstMatch(query);
    if (books != null && link != null) {
      final id = int.parse(link.group(1)!);
      return [
        for (final (b, _) in books)
          if (b.id == id) b,
      ];
    }
    final q = normalizeArabicLoose(normalizeArabic(query.trim()));
    if (books == null || q.isEmpty) return const [];
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final ranked = <(int, ShamelaBookRef)>[];
    for (final (book, norm) in books) {
      int? rank;
      if (norm == q) {
        rank = 0;
      } else if (norm.startsWith(q)) {
        rank = 1;
      } else {
        final titleWords = norm.split(RegExp(r'[^ء-ي0-9a-z٠-٩]+')).toSet();
        if (words.every(titleWords.contains)) {
          rank = 2;
        } else if (words.every(norm.contains)) {
          rank = 3;
        }
      }
      if (rank != null) ranked.add((rank, book));
    }
    ranked.sort((a, b) {
      final r = a.$1.compareTo(b.$1);
      return r != 0 ? r : a.$2.title.length.compareTo(b.$2.title.length);
    });
    return [for (final r in ranked.take(limit)) r.$2];
  }

  /// For tests: the catalogue from bytes already in hand.
  void loadForTest(List<int> bytes) => _books = _parse(bytes);
}
