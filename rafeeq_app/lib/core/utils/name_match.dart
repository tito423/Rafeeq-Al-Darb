import 'arabic_normalize.dart';

/// «جيت ابحث عن ابن القيم مش لاقيها … البحث لازم يكون قوي». The catalogue
/// writes «الإمام ابن قيّم الجوزية»; a reader types «ابن القيم». Matching the
/// query as one substring fails on the article alone, so a title or an
/// author is matched word by word instead:
///
/// * every query word must match some word of the text, in any order;
/// * a word matches when, with harakat and the article «ال» removed, one
///   starts with the other (so «القيم» meets «قيّم», «الجوزي» meets
///   «الجوزية», «نعيم» meets «نعيم»);
/// * «ابن» and «بن» are the same word («ابن كثير» finds «إسماعيل بن كثير»);
/// * a leading «و» / «ب» / «ل» on a query word is tried off as well.
bool nameMatches(String text, String query) {
  final q = _words(query);
  if (q.isEmpty) return false;
  final t = _words(text);
  for (final w in q) {
    if (!t.any((x) => _wordHit(x, w))) return false;
  }
  return true;
}

List<String> _words(String s) {
  final n = normalizeArabicLoose(normalizeArabic(s))
      .replaceAll('ة', 'ه')
      .toLowerCase();
  return [
    for (final w in n.split(RegExp(r'[^ء-ي0-9a-z٠-٩]+')))
      if (w.isNotEmpty) _core(w),
  ];
}

String _core(String w) {
  if (w == 'ابن' || w == 'بن' || w == 'بنت' || w == 'ابنه') return 'بن';
  if (w.length > 3 && w.startsWith('ال')) return w.substring(2);
  return w;
}

bool _wordHit(String text, String q) {
  if (text.startsWith(q) || (q.length >= 3 && q.startsWith(text) && text.length >= 3)) {
    return true;
  }
  // «والقيم», «بالجوزية»: a clitic the text never carries.
  if (q.length > 3 && 'وبل'.contains(q[0])) {
    final rest = _core(q.substring(1));
    return text.startsWith(rest);
  }
  return false;
}
