import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/arabic_normalize.dart';
import 'shamela_nass.dart';

/// The book card on `https://shamela.ws/book/{id}`.
class ShamelaCard {
  const ShamelaCard({
    required this.card,
    required this.title,
    required this.author,
    required this.printMatches,
  });
  final String card;
  final String title;
  final String author;
  final bool printMatches;
}

/// Thrown when the owner's standing exclusion covers the book's author.
class ShamelaExcludedAuthor implements Exception {
  const ShamelaExcludedAuthor(this.author);
  final String author;
}

/// Builds one Shamela book in the app's own format, on the phone.
///
/// A port of `scripts/build_book_text.py` (`fetch_meta_card`, `build_book`,
/// `print_reliable`) - the pipeline every library book was built with - so
/// an imported book has the same pages, table of contents and meta as one
/// the pipeline made. The page parser is `parseNass`, tested identical to
/// the Python on 321 real pages.
///
/// Pages are walked by `nextId` exactly as the pipeline does, with its
/// 0.15 s pause between requests (polite to a public library's server), and
/// each one is kept on disk as it arrives: an import stopped by the reader,
/// the network or Android resumes from the last page it had.
class ShamelaBookBuilder {
  ShamelaBookBuilder(this.shamelaId, {Dio? dio}) : _dio = dio ?? Dio();

  final int shamelaId;
  final Dio _dio;
  bool _cancelled = false;

  static const _host = 'https://shamela.ws';
  static const _ua =
      'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/126.0 Mobile Safari/537.36 RafeeqAlDarb';
  static const _delay = Duration(milliseconds: 150);

  /// The owner's standing exclusion (memory «library-content-policy»,
  /// 2026-09-23): «اللي ذكرتهم دول لا سيبهم مستبعدين».
  static const excludedAuthors = [
    'ابن باز',
    'ابن عثيمين',
    'ابن جبرين',
    'محمد بن عبد الوهاب',
    'الألباني',
  ];

  static bool isExcluded(String author) {
    final a = normalizeArabic(author);
    return excludedAuthors.any((n) => a.contains(normalizeArabic(n)));
  }

  void cancel() => _cancelled = true;

  Future<String> _get(String path, {bool ajax = false}) async {
    Object? last;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (_cancelled) throw const _Cancelled();
      try {
        final res = await _dio.get<String>(
          '$_host$path',
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'User-Agent': _ua,
              if (ajax) 'X-Requested-With': 'XMLHttpRequest',
            },
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        if (res.statusCode == 200 && (res.data ?? '').isNotEmpty) {
          return res.data!;
        }
        last = 'HTTP ${res.statusCode}';
      } catch (e) {
        last = e;
      }
      await Future<void>.delayed(Duration(seconds: attempt + 1));
    }
    throw HttpException('GET $path failed: $last');
  }

  /// The «بطاقة الكتاب» block (pipeline: `fetch_meta_card`).
  Future<ShamelaCard> fetchCard() async {
    final h = await _get('/book/$shamelaId');
    final m = RegExp(r'<div style="line-height: 1\.8;">(.*?)</div>',
            dotAll: true)
        .firstMatch(h);
    var card = '';
    if (m != null) {
      card = m.group(1)!.replaceAll(RegExp(r'<br\s*/?>'), '\n');
      card = card.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    }
    // «الكتاب : x» and «الكتاب: x» both occur (3 of 182 books had the space).
    final title =
        RegExp(r'الكتاب\s*:\s*(.+)').firstMatch(card)?.group(1)?.trim() ?? '';
    final author =
        RegExp(r'المؤلف\s*:\s*(.+)').firstMatch(card)?.group(1)?.trim() ?? '';
    // «غير موافق للمطبوع» CONTAINS «موافق للمطبوع» - the negation first.
    final printMatches = card.contains('موافق للمطبوع') &&
        !card.contains('غير موافق للمطبوع') &&
        !card.contains('مرقم آليا');
    return ShamelaCard(
        card: card, title: title, author: author, printMatches: printMatches);
  }

  static Future<File> _partFile(int id) async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'shamela', 'parts', '$id.jsonl'));
  }

  /// Builds the book and returns the app's book JSON (gzip bytes), ready for
  /// `LibraryApiService.installBookBytes`. [onPage] gets the pages done so
  /// far; Shamela gives no total up front, so the caller shows a count.
  Future<List<int>> build(
    ShamelaCard card, {
    required String bookId,
    void Function(int pages)? onPage,
  }) async {
    if (isExcluded(card.author)) throw ShamelaExcludedAuthor(card.author);
    final part = await _partFile(shamelaId);
    await part.parent.create(recursive: true);

    // Resume: pages already fetched for this book, by pageId.
    final cache = <String, Map<String, dynamic>>{};
    if (part.existsSync()) {
      for (final line in await part.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          final d = jsonDecode(line) as Map<String, dynamic>;
          cache['${d['pageId']}'] = d;
        } catch (_) {}
      }
    }
    final sink = part.openWrite(mode: FileMode.append);
    final pages = <Map<String, dynamic>>[];
    final toc = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? pageId = '1';
    String? lastTitle;
    try {
      while (pageId != null) {
        if (_cancelled) throw const _Cancelled();
        if (!seen.add(pageId)) {
          throw StateError('loop at pageId $pageId');
        }
        var data = cache[pageId];
        if (data == null) {
          final raw = await _get('/ajax/pageContent/$shamelaId/$pageId',
              ajax: true);
          data = jsonDecode(raw) as Map<String, dynamic>;
          data['pageId'] = pageId;
          sink.writeln(jsonEncode(data));
          await Future<void>.delayed(_delay);
        }
        final printed = int.tryParse('${data['pageNum'] ?? 0}') ?? 0;
        final title = '${data['title'] ?? ''}'.trim();
        final paras = parseNass('${data['nass'] ?? ''}');
        // Shamela repeats the nearest heading on every page of a section;
        // one فهرس entry per section, at the page it starts on.
        if (title.isNotEmpty && title != lastTitle) {
          final level =
              RegExp(r'^(كتاب |مقدمة|خطبة|تمهيد)').hasMatch(title) ? 0 : 1;
          toc.add({
            'title': title,
            'page': printed,
            'pageIndex': pages.length,
            'level': level,
          });
        }
        if (title.isNotEmpty) lastTitle = title;
        pages.add({'p': printed, 'paras': paras});
        onPage?.call(pages.length);
        final nxt = data['nextId'];
        pageId = (nxt == null || '$nxt' == '' || '$nxt' == '0') ? null : '$nxt';
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    final doc = {
      'id': bookId,
      'schema': 1,
      'meta': {
        'titleAr': card.title,
        'authorAr': card.author,
        'sourceLabel': 'المكتبة الشاملة',
        'shamelaId': shamelaId,
        'shamelaUrl': '$_host/book/$shamelaId',
        'printMatches': card.printMatches,
        'printReliable': printReliable(pages, card.printMatches),
        'editionCard': card.card,
        'pageCount': pages.length,
        'sectionCount': toc.length,
        'builtAt': DateTime.now().toUtc().toIso8601String(),
        'builtFrom': 'app: Shamela import (shamela.ws ajax/pageContent)',
      },
      'toc': toc,
      'pages': pages,
    };
    final bytes = gzip.encode(utf8.encode(jsonEncode(doc)));
    // The book is whole; its page cache is no longer needed.
    if (part.existsSync()) await part.delete();
    return bytes;
  }

  /// Printed page numbers are trusted (shown, navigable) only with the
  /// «موافق للمطبوع» flag, near-perfect order, and no big jump back
  /// (pipeline: `print_reliable`; book 12014 keeps the flag yet drops ~100).
  static bool printReliable(List<Map<String, dynamic>> pages, bool matches) {
    final nums = [
      for (final pg in pages)
        if ((pg['p'] as int) != 0) pg['p'] as int,
    ];
    if (!matches || nums.length < 10) return false;
    var ok = 0;
    var minDelta = 1 << 30;
    for (var i = 1; i < nums.length; i++) {
      final d = nums[i] - nums[i - 1];
      if (d >= 0) ok++;
      if (d < minDelta) minDelta = d;
    }
    return ok / (nums.length - 1) >= 0.985 && minDelta >= -3;
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
