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

List<String> ayahWords(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// How many steps this ayah has, counting step 0 (nothing hidden).
int hifzMaskSteps(String text) => ayahWords(text).length;

/// Whether the word at [index] is hidden at [step].
bool hifzWordHidden(int wordIndex, int wordCount, int step) {
  if (step <= 0) return false;
  final hidden = step.clamp(0, wordCount - 1);
  return wordIndex >= wordCount - hidden;
}
