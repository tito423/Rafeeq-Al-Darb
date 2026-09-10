/// Pulls the *matn* — the Prophet's ﷺ words — out of a full hadith record so
/// it can be looked up somewhere else.
///
/// A hadith from the nine books arrives with its whole isnad in front of it:
///
///     حدثنا عبد الصمد، حدثنا عبد العزيز يعني ابن مسلم، حدثنا يزيد، عن مجاهد،
///     عن أبي سعيد، أن رسول الله ﷺ قال: " لا يدخل الجنة منان، ولا عاق، ولا
///     مدمن خمر "
///
/// Searching another collection for that whole string finds nothing — the
/// chain of narrators is particular to this edition. The quoted matn is the
/// part two collections share.
///
/// Deliberately conservative: it returns null rather than a guess when there
/// is no quoted span to take, because the caller uses this to *search*, and a
/// bad query is worse than no button.
library;

/// The quote marks these editions actually use, gathered by reading the real
/// text rather than assumed: guillemets, ASCII double quotes, and the curly
/// pair. `hadith.db` uses plain `"` most often, with a space inside it.
const _openers = ['«', '"', '“'];
const _closers = ['»', '"', '”'];

/// The longest quoted span in [full], or null when there is none worth using.
///
/// [minWords] guards against matching a two-word aside; a span that short
/// would match half the corpus and make the search useless.
String? matnOf(String full, {int minWords = 4}) {
  var best = '';
  for (var i = 0; i < _openers.length; i++) {
    final open = _openers[i];
    final close = _closers[i];
    var from = 0;
    while (true) {
      final start = full.indexOf(open, from);
      if (start < 0) break;
      final end = full.indexOf(close, start + open.length);
      if (end < 0) break;
      final span = full.substring(start + open.length, end).trim();
      if (span.length > best.length) best = span;
      from = end + close.length;
    }
  }
  if (best.isEmpty) return null;
  if (best.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < minWords) {
    return null;
  }
  return best;
}

/// A short, distinctive query for the matn — the first [words] words of it.
///
/// The whole matn is a poor search key: two collections rarely word a long
/// hadith identically to the letter, and one differing particle would sink an
/// exact-substring match. An opening run of a few words is both distinctive
/// and much more likely to be shared.
String? matnQuery(String full, {int words = 7}) {
  final matn = matnOf(full);
  if (matn == null) return null;
  final parts =
      matn.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return parts.take(words).join(' ');
}
