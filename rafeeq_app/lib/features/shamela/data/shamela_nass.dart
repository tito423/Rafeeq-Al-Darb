/// One Shamela page's `nass` HTML -> the app's paragraphs
/// `{"t": text, "k": "body"|"aya"|"ref"|"head", "r"?: ayah reference}`.
///
/// A line-for-line port of `scripts/build_book_text.py:parse_nass`, the
/// parser every book in the library was built with, so a book imported on
/// the phone reads exactly like one the pipeline built. It is held to that:
/// `test/shamela_nass_test.dart` runs 321 real pages from the local crawl
/// (`scripts/make_shamela_parse_fixture.py`) and requires the same output
/// as the Python, paragraph for paragraph.
library;

final _p = RegExp(r'<p\b[^>]*>(.*?)</p>', dotAll: true);

/// Shamela uses both `<div class="hamesh">` and `<p class="hamesh">`;
/// matching only the div left whole modern footnotes in al-Idah's body and
/// attributed them to al-Nawawi (the pipeline's note).
final _hamesh = RegExp(
  r'<(?<tag>div|p)\b[^>]*class="[^"]*\bhamesh\b[^"]*"[^>]*>.*?</\k<tag>>',
  dotAll: true,
);
final _btnTag = RegExp(
  r'<a[^>]*class="[^"]*btn_tag[^"]*"[^>]*>.*?</a>',
  dotAll: true,
);
final _anchor = RegExp(
  r'<span[^>]*class="[^"]*anchor[^"]*"[^>]*>.*?</span>',
  dotAll: true,
);
final _c3 = RegExp(
  r'<span[^>]*class="[^"]*\bc3\b[^"]*"[^>]*>(.*?)</span>',
  dotAll: true,
);
final _c4 = RegExp(
  r'<span[^>]*class="[^"]*\bc4\b[^"]*"[^>]*>(.*?)</span>',
  dotAll: true,
);
final _tag = RegExp(r'<[^>]+>');
// Space, tab and NO-BREAK SPACE (U+00A0) - the Python pattern's third
// character, checked byte by byte.
final _ws = RegExp('[ \t ]+');

final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');
const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'zwnj': '‌',
  'zwj': '‍',
};

/// The entities that can occur. None did in 15,933 real pages from 30 books
/// (measured 2026-09-26), so this is a safeguard, not a hot path.
String _unescape(String s) => s.replaceAllMapped(_entity, (m) {
  final e = m.group(1)!;
  if (e.startsWith('#x')) {
    final v = int.tryParse(e.substring(2), radix: 16);
    return v == null ? m.group(0)! : String.fromCharCode(v);
  }
  if (e.startsWith('#')) {
    final v = int.tryParse(e.substring(1));
    return v == null ? m.group(0)! : String.fromCharCode(v);
  }
  return _named[e] ?? m.group(0)!;
});

String _cleanText(String fragment) {
  var t = fragment.replaceAll(_tag, '');
  t = _unescape(t);
  t = t.replaceAll('\r', ' ').replaceAll('\n', ' ');
  t = t.replaceAll(_ws, ' ');
  return t.trim();
}

List<Map<String, String>> parseNass(String nass) {
  final body = nass.replaceAll(_hamesh, ''); // the footnote apparatus
  final out = <Map<String, String>>[];
  for (final m in _p.allMatches(body)) {
    var p = m.group(1)!;
    p = p.replaceAll(_btnTag, '');
    p = p.replaceAll(_anchor, '');

    final plain = _cleanText(p);
    if (plain.isEmpty) continue;

    // A whole paragraph that is just a bracketed line is a heading
    // (Shamela writes [مقدمة المؤلف], [باب كذا] ...).
    final stripped = plain.trim();
    if (stripped.length <= 120 &&
        stripped.startsWith('[') &&
        stripped.endsWith(']')) {
      out.add({
        't': stripped.substring(1, stripped.length - 1).trim(),
        'k': 'head',
      });
      continue;
    }

    // Ayah-dominant paragraph: the c3 spans are most of it.
    final c3 = [for (final x in _c3.allMatches(p)) _cleanText(x.group(1)!)];
    final c3Len = c3.fold<int>(0, (a, x) => a + x.length);
    if (c3.isNotEmpty && c3Len >= 0.6 * plain.length) {
      final aya = c3.where((x) => x.isNotEmpty).join(' ');
      final ref = [
        for (final x in _c4.allMatches(p)) _cleanText(x.group(1)!),
      ].firstWhere((x) => x.isNotEmpty, orElse: () => '');
      out.add({'t': aya, 'k': 'aya', if (ref.isNotEmpty) 'r': ref});
      continue;
    }

    out.add({'t': plain, 'k': 'body'});
  }
  return out;
}
