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

/// How much of the ayah is left to lean on - «diminishing cues»: the help
/// shrinks a step at a time until the ayah is recited from memory. In the
/// memory research this is the retrieval practice that still works where a
/// plain test does not (Fiechter & Benjamin, Psychonomic Bulletin & Review
/// 25, 2018; checked 2026-09-30). Owner, 2026-09-30: «مش مفروض انها بتختفي
/// او يحطلي كلمة واكمل … بافضل الطرق العلمية والحديثة».
enum HifzCue { full, firstLetters, alternate, firstWord, none }

/// Whether word [i] of [n] is covered at [cue]. [HifzCue.firstLetters]
/// covers none of them whole - see [hifzFirstLetter].
bool hifzCueHidden(int i, int n, HifzCue cue) => switch (cue) {
      HifzCue.full || HifzCue.firstLetters => false,
      HifzCue.alternate => i.isOdd,
      HifzCue.firstWord => i > 0,
      HifzCue.none => true,
    };

/// The word's first letter WITH its own marks (a shadda, a vowel), which is
/// what [HifzCue.firstLetters] leaves showing - the rest is covered in the
/// widget; the text itself is never cut (§1.2).
String hifzFirstLetter(String word) {
  final m = RegExp(r'^[^ً-ٰٟۖ-ۭ]'
          r'[ً-ٰٟۖ-ۭ]*')
      .firstMatch(word);
  return m?.group(0) ?? word;
}

/// One step harder after a strong recitation, one easier after a weak one:
/// the ladder follows the reader (90 % and 60 %, the tasmee' score).
HifzCue hifzCueAfter(HifzCue cue, double ratio) {
  final i = cue.index;
  if (ratio >= 0.9 && i < HifzCue.values.length - 1) {
    return HifzCue.values[i + 1];
  }
  if (ratio < 0.6 && i > 0) return HifzCue.values[i - 1];
  return cue;
}
