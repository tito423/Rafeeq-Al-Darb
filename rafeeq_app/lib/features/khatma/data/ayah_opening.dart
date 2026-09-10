/// The opening of an ayah, cut at a word — never in the middle of one.
///
/// THE BUG THIS FIXES, reported as «في الختمة بياكل جزء من الآية وهو بيعرضها».
/// The khatma card drew the ayah with `maxLines: 2` and
/// `TextOverflow.ellipsis`, which lets the text engine break wherever the line
/// happens to run out — mid-word, and with a Latin «…» glued to the fragment.
///
/// The card's own label says «من قوله تعالى», so an opening is the right thing
/// to show; a *damaged* opening is not. This cuts on whole words, and says
/// nothing at all when the whole ayah fits.
///
/// It never rewrites the text it keeps (§1.2) — no normalising, no stripping
/// of marks, nothing but a cut at a space.
library;

/// The Arabic ellipsis. U+2026 renders as three dots on the baseline in both
/// directions and is what the rest of the app uses.
const String _ellipsis = '…';

/// [words] whole words of [ayah], followed by «…» only if something was left.
///
/// Returns the ayah unchanged when it is short enough, so a five-word ayah is
/// never decorated with an ellipsis it does not need.
String ayahOpening(String ayah, {int words = 12}) {
  final text = ayah.trim();
  if (text.isEmpty) return '';
  // Split on runs of whitespace so a double space cannot produce an empty
  // "word" and eat one of the twelve.
  final parts = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.length <= words) return text;
  return '${parts.take(words).join(' ')} $_ellipsis';
}

/// True when [ayah] would be cut by [ayahOpening] — the card uses it to decide
/// whether the «من قوله تعالى» label is a promise it is keeping.
bool ayahIsCut(String ayah, {int words = 12}) {
  final parts =
      ayah.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return parts.length > words;
}
