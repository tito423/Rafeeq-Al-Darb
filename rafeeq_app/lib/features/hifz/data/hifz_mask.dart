/// Hiding an ayah's words, one step at a time.
///
/// The «إخفاء تدريجي» ladder: at step 0 the whole ayah is shown, and each
/// step hides one more word — from the END, so the reader is always given
/// the run-up and asked for what comes next, which is how an ayah is
/// actually recited from memory. At the last step nothing is left but the
/// first word.
///
/// Nothing here alters a letter of the ayah: the words are the ayah's own,
/// split on spaces, and a hidden word is replaced in the WIDGET, never in
/// the text (§1.2).
library;

List<String> ayahWords(String text) {
  final out = <String>[];
  for (final t in text.split(RegExp(r'\s+'))) {
    if (t.isEmpty) continue;
    // A pause mark (ۚ ۖ ۗ ۛ …) is set in the source as a token of its own.
    // As a «word» it wrapped alone to the start of the next line, away from
    // the word it belongs to (the owner's al-Nisa 1, 2026-09-23), and cost
    // a step of the hiding ladder. It stays with the word before it, with
    // the source's own space — the text is unchanged.
    if (out.isNotEmpty && !_letter.hasMatch(t)) {
      out[out.length - 1] = '${out.last} $t';
    } else {
      out.add(t);
    }
  }
  return out;
}

final _letter = RegExp('[ء-يٱ]');

/// How many steps this ayah has, counting step 0 (nothing hidden).
int hifzMaskSteps(String text) => ayahWords(text).length;

/// Whether the word at [index] is hidden at [step].
bool hifzWordHidden(int wordIndex, int wordCount, int step) {
  if (step <= 0) return false;
  final hidden = step.clamp(0, wordCount - 1);
  return wordIndex >= wordCount - hidden;
}
