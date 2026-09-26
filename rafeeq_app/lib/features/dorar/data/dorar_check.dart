import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/arabic_normalize.dart';
import 'dorar_service.dart';

/// «تخريج من الدرر» for any hadith in the app (owner, 2026-09-26: check any
/// hadith anywhere against Dorar, including text selected in a library book).
///
/// How a hadith is looked up, and why each step exists - all measured live
/// against `dorar_api.json` on 2026-09-26:
///  * Dorar returns 15 results for ANY words, even «زيد عمرو بكر خالد
///    سعيد», so a result count proves nothing. A result is shown only when
///    [matchScore] says its own text holds the query's words (>= [minScore]).
///    An earlier button that offered near-matches for the reader to sort out
///    was removed at the owner's request; this never shows a guess.
///  * An isnad in the query drowns the matn («حدثنا الحميدي ... إنما الأعمال
///    بالنيات» returned three unrelated isnad-heavy texts), so [extractMatn]
///    drops the chain first.
///  * Diacritics make no difference to Dorar («إِنَّمَا الأَعْمَالُ» and
///    «انما الاعمال» both return the hadith), so the query is sent plain.
/// On 60 random hadiths from hadith.db (two samples of 30), 26 of the last 30
/// had a result at >= 0.8; the 4 without were fragments («فذكر مثله»).
class DorarCheck {
  DorarCheck._();
  static final DorarCheck instance = DorarCheck._();

  /// Share of the query's words a result must contain to be shown.
  static const double minScore = 0.8;

  /// A query shorter than this cannot tell one hadith from another.
  static const int minWords = 4;

  /// Query length: long enough to be specific, short enough that a hadith
  /// Dorar words slightly differently further on still matches.
  static const int queryWords = 10;

  /// Gradings for [text] (a whole hadith, or a passage the reader selected).
  /// Cached per query in app support `dorar/check/`, so a hadith checked
  /// once opens offline and without asking Dorar again.
  Future<DorarCheckResult> check(String text) async {
    final words = matnQueryWords(text);
    if (words.length < minWords) {
      return DorarCheckResult(query: words.join(' '), matches: const []);
    }
    final query = words.join(' ');
    final cached = await _readCache(query);
    if (cached != null) return cached;
    final all = await DorarService.instance.search(query);
    final scored = [
      for (final h in all)
        if (matchScore(words, h.text) >= minScore) (h, matchScore(words, h.text)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final result = DorarCheckResult(
        query: query, matches: [for (final s in scored) s.$1]);
    await _writeCache(query, result);
    return result;
  }

  Future<File> _file(String query) async {
    final dir = await getApplicationSupportDirectory();
    final key = sha1.convert(utf8.encode(query)).toString();
    return File('${dir.path}/dorar/check/$key.json');
  }

  Future<DorarCheckResult?> _readCache(String query) async {
    try {
      final f = await _file(query);
      if (!f.existsSync()) return null;
      return DorarCheckResult.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String query, DorarCheckResult r) async {
    try {
      final f = await _file(query);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(r.toJson()));
    } catch (_) {
      // A cache that cannot be written only costs a second lookup.
    }
  }
}

class DorarCheckResult {
  const DorarCheckResult({required this.query, required this.matches});
  final String query;
  final List<DorarHadith> matches;

  Map<String, dynamic> toJson() => {
        'query': query,
        'matches': [
          for (final h in matches)
            {
              'text': h.text,
              'rawi': h.rawi,
              'muhaddith': h.muhaddith,
              'source': h.source,
              'page': h.page,
              'grade': h.grade,
            }
        ],
      };

  factory DorarCheckResult.fromJson(Map<String, dynamic> j) => DorarCheckResult(
        query: '${j['query']}',
        matches: [
          for (final m in (j['matches'] as List))
            DorarHadith(
              text: '${m['text']}',
              rawi: '${m['rawi']}',
              muhaddith: '${m['muhaddith']}',
              source: '${m['source']}',
              page: '${m['page']}',
              grade: '${m['grade']}',
            ),
        ],
      );
}

final _nonLetter = RegExp(r'[^ء-ي\s"«“]');
final _nonArabic = RegExp(r'[^ء-ي\s]');
final _quote = RegExp(r'["«“]\s*(.+)');
final _honorific = RegExp(
    r'صلي الله عليه واله وسلم|صلي الله عليه وسلم|رضي الله عنهما|رضي الله عنها|رضي الله عنه');
final _lead = RegExp(r'^((قال|قالت|يقول|انه|ان|فقال|رسول|الله|النبي)\s+)+');

/// A narration verb or link of an isnad («حدثنا», «وأخبرني», «وحدثناه»,
/// «عن», «سمعت», the tahwil «ح»).
final _verb = RegExp(r'^و?(حدث|اخبر|انبا|نبا)[ء-ي]*$|^و?عن$|^و?سمعت?$|^ح$');
const _stops = {
  'قال', 'قالت', 'يقول', 'تقول', 'ان', 'انه', 'انها', 'انهم', 'انهما', //
  'قالا', 'يحدث', 'يخبر', 'رفعه', 'يرفعه',
};

/// Plain letters for comparing: no diacritics, one alef, ى as ي.
String _plain(String s) => normalizeArabic(s).replaceAll('ـ', '');

/// For scoring only: ة and ه compared as one letter (Dorar and the
/// collections differ in dotting it). Never used on text that is shown.
String _loose(String s) => _plain(s).replaceAll('ة', 'ه');

/// Drops the isnad at the start of [words]: each narration verb and the
/// name after it (up to ten words - «عبيد الله بن عبد الله بن عتبة بن
/// مسعود» is nine), as long as the chain continues. A «قال»/«أن» ends the
/// chain unless another narration verb follows within six words
/// («قال عمرو أخبرني عطاء», «أن عبد الله بن عباس أخبره»).
List<String> stripIsnad(List<String> words) {
  bool verbWithin(int from, int n) {
    for (var j = from; j < words.length && j < from + n; j++) {
      if (_verb.hasMatch(words[j])) return true;
    }
    return false;
  }

  var i = 0, last = -1, gap = 0;
  while (i < words.length) {
    final w = words[i];
    if (_verb.hasMatch(w)) {
      last = i;
      gap = 0;
      i++;
    } else if (last < 0) {
      break;
    } else if (_stops.contains(w)) {
      if (!verbWithin(i + 1, 6)) break;
      gap = 0;
      i++;
    } else if (gap < 10) {
      gap++;
      i++;
    } else {
      break;
    }
  }
  return last >= 0 ? words.sublist(i) : words;
}

/// The matn of a hadith as plain words (no isnad, no diacritics, no
/// honorifics), for looking it up - never for display.
String extractMatn(String arabic) {
  var t = _plain(arabic).replaceAll(_nonLetter, ' ');
  t = stripIsnad(t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList())
      .join(' ');
  final q = _quote.firstMatch(t);
  if (q != null && q.group(1)!.split(' ').length >= 4) t = q.group(1)!;
  t = t.replaceAll(_honorific, ' ').replaceAll(_nonArabic, ' ');
  t = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  return t.replaceFirst(_lead, '');
}

/// The words sent to Dorar for [text].
List<String> matnQueryWords(String text) {
  final m = extractMatn(text).split(' ').where((w) => w.isNotEmpty).toList();
  return m.length > DorarCheck.queryWords
      ? m.sublist(0, DorarCheck.queryWords)
      : m;
}

/// Share (0..1) of [queryWords] found among the words of [resultText].
double matchScore(List<String> queryWords, String resultText) {
  if (queryWords.isEmpty) return 0;
  final have = _loose(resultText)
      .replaceAll(_nonArabic, ' ')
      .split(RegExp(r'\s+'))
      .toSet();
  var n = 0;
  for (final w in queryWords) {
    if (have.contains(_loose(w))) n++;
  }
  return n / queryWords.length;
}
