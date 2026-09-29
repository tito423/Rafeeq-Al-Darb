import 'dart:math';

import '../../../core/db/models.dart';

/// What the kids' corner offers - all of it real content the app already
/// carries, arranged for a child (owner, 2026-09-29).

/// The short surahs a child learns first: al-Fatihah, then the last surahs
/// of the mushaf. Opened in the app's own memorisation screen.
const kidsSurahIds = <int>[1, 114, 113, 112, 111, 110, 109, 108, 107, 106,
  105, 104, 103, 102, 101, 100, 99, 98, 97, 96, 95, 94, 93];

/// Chapters of «حصن المسلم» (row ids in azkar.db) a child says every day:
/// waking, clothes, the toilet, home, eating, sneezing, sleeping.
const kidsAzkarSectionIds = <int>[1, 2, 6, 7, 10, 11, 70, 71, 78, 29];

/// One «أكمل الآية» question: the ayah without its last word, and choices.
class AyahQuestion {
  final Ayah ayah;

  /// The ayah's words before the missing one, exactly as the mushaf writes
  /// them.
  final String prompt;
  final String answer;
  final List<String> choices;
  const AyahQuestion(this.ayah, this.prompt, this.answer, this.choices);
}

List<String> _words(String text) =>
    text.split(' ').where((w) => w.trim().isNotEmpty).toList();

/// Builds a question from [ayahs] (one surah): an ayah of at least three
/// words, its last word as the answer, and two other words of the same surah
/// that differ from it. Ayahs whose numbers are in [exclude] (already asked)
/// are skipped. Null when the surah has no ayah left to ask.
AyahQuestion? makeAyahQuestion(List<Ayah> ayahs, Random rnd,
    {Set<int> exclude = const {}}) {
  final usable = [
    for (final a in ayahs)
      if (_words(a.textUthmani).length >= 3 && !exclude.contains(a.ayahNumber))
        a,
  ];
  if (usable.isEmpty) return null;
  final pool = <String>{for (final a in ayahs) ..._words(a.textUthmani)};
  for (var tries = 0; tries < 10; tries++) {
    final a = usable[rnd.nextInt(usable.length)];
    final w = _words(a.textUthmani);
    final answer = w.last;
    final others = (pool.toList()..remove(answer))..shuffle(rnd);
    if (others.length < 2) continue;
    final choices = [answer, others[0], others[1]]..shuffle(rnd);
    return AyahQuestion(a, w.sublist(0, w.length - 1).join(' '), answer, choices);
  }
  return null;
}
