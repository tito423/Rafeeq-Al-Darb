import 'dart:convert';

import 'package:dio/dio.dart';

/// One grading of a hadith, as Dorar's encyclopaedia records it.
///
/// Every field is Dorar's own text. [muhaddith] is never empty on a result
/// the app shows: the project's rule is «no grade without a named grader»
/// (CLAUDE.md §1.2), and a result without one is dropped by [parseDorar].
class DorarHadith {
  const DorarHadith({
    required this.text,
    required this.rawi,
    required this.muhaddith,
    required this.source,
    required this.page,
    required this.grade,
  });
  final String text;
  final String rawi;
  final String muhaddith;
  final String source;
  final String page;
  final String grade;
}

/// Hadith gradings from al-Durar al-Saniyya (dorar.net), searched live.
///
/// Dorar publishes a public JSON endpoint for exactly this -
/// `https://dorar.net/dorar_api.json?skey=<words>&page=<n>` (measured
/// 2026-09-26: 200 application/json, 15 results a page, `page` changes the
/// results). The app asks it when the reader asks, and copies nothing of
/// Dorar's database. Owner, 2026-09-26: «ابدأ بالدرر».
class DorarService {
  DorarService._();
  static final DorarService instance = DorarService._();

  final Dio _dio = Dio();

  Future<List<DorarHadith>> search(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final res = await _dio.get<String>(
      'https://dorar.net/dorar_api.json',
      queryParameters: {'skey': q, 'page': page},
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': 'RafeeqAlDarb (Android; personal library)'},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final j = jsonDecode(res.data ?? '{}') as Map<String, dynamic>;
    final result = (j['ahadith'] as Map<String, dynamic>?)?['result'];
    return parseDorar('${result ?? ''}');
  }
}

final _block = RegExp(
  r'<div class="hadith"[^>]*>(.*?)</div>\s*<div class="hadith-info">(.*?)</div>',
  dotAll: true,
);
final _tag = RegExp(r'<[^>]+>');
final _ws = RegExp(r'\s+');
final _num = RegExp(r'^\s*\d+\s*-\s*');

String _plain(String html) => html
    .replaceAll(_tag, '')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(_ws, ' ')
    .trim();

/// The text after «label:» up to the next label, inside one info block.
String _field(String info, String label) {
  final i = info.indexOf('$label:</span>');
  if (i < 0) return '';
  var rest = info.substring(i + label.length + ':</span>'.length);
  final next = rest.indexOf('<span class="info-subtitle">');
  if (next >= 0) rest = rest.substring(0, next);
  return _plain(rest);
}

/// Dorar's result HTML -> gradings. Entries with no named grader are left
/// out; the rest keep Dorar's wording exactly (nothing normalised - trap:
/// never «fix» text that is hadith or next to it).
List<DorarHadith> parseDorar(String html) {
  final out = <DorarHadith>[];
  for (final m in _block.allMatches(html)) {
    final text = _plain(m.group(1)!).replaceFirst(_num, '');
    final info = m.group(2)!;
    final muhaddith = _field(info, 'المحدث');
    if (muhaddith.isEmpty || muhaddith == '-') continue;
    out.add(DorarHadith(
      text: text.endsWith(' .') ? text.substring(0, text.length - 2) : text,
      rawi: _field(info, 'الراوي'),
      muhaddith: muhaddith,
      source: _field(info, 'المصدر'),
      page: _field(info, 'الصفحة أو الرقم'),
      grade: _field(info, 'خلاصة حكم المحدث'),
    ));
  }
  return out;
}
