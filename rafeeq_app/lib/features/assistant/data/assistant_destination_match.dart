part of 'assistant_intent.dart';

/// Resolves the longest screen or settings title after the parser has ruled
/// out commands that carry their own details (surah, reciter, book, etc.).
AssistantIntent _matchDestination({
  required String heard,
  required String clean,
  required List<String> words,
  required bool commanded,
  required Map<AssistantScreen, List<String>> screens,
  required Map<String, List<String>> sections,
  required List<String> settings,
  required bool Function(String, Iterable<String>) hasPhrase,
}) {
  // A screen: the longest phrase wins («مشغل التلاوه» beats «التلاوه»).
  AssistantScreen? best;
  var bestLen = 0;
  var bestWords = 0;
  for (final e in screens.entries) {
    for (final p in e.value) {
      if (p.length > bestLen && hasPhrase(clean, [p])) {
        best = e.key;
        bestLen = p.length;
        bestWords = p.split(' ').length;
      }
    }
  }

  // A settings section opens where it is, not merely on the settings list.
  String? section;
  for (final e in sections.entries) {
    for (final p in e.value) {
      if (p.length > bestLen && hasPhrase(clean, [p])) {
        section = e.key;
        bestLen = p.length;
        bestWords = p.split(' ').length;
      }
    }
  }
  // Preserve the owner's earlier command; «شاشة» requests the full editor.
  if (best == AssistantScreen.prayerAdjustments &&
      !words.any((w) => bare(w) == 'شاشه')) {
    best = null;
    section = 'prayer.adjustments';
  }

  // Any other setting, by its title in any language, opens settings.
  for (final p in settings) {
    if (p.length > bestLen && hasPhrase(clean, [p])) {
      best = AssistantScreen.settings;
      section = null;
      bestLen = p.length;
      bestWords = p.split(' ').length;
    }
  }

  // ASR may swallow one word of a 3+-word section title. On emulator-5554,
  // «افتح ضبط المواقيت والتاريخ» became «فتحضط المواقيط والتاريخ».
  if (section == null) {
    final said = {for (final w in words) bare(w)};
    var bestHits = best == null ? 0 : bestWords;
    for (final e in sections.entries) {
      for (final p in e.value) {
        final phraseWords = p.split(' ');
        if (phraseWords.length < 3) continue;
        final hits = phraseWords.where((w) => said.contains(bare(w))).length;
        if (hits == phraseWords.length - 1 && hits > bestHits) {
          section = e.key;
          best = null;
          bestHits = hits;
          bestWords = phraseWords.length;
        }
      }
    }
  }

  final slack = bestWords >= 3 ? 2 : 1;
  if (section != null && (commanded || words.length <= bestWords + slack)) {
    return OpenSettingIntent(section);
  }
  if (best != null && (commanded || words.length <= bestWords + 1)) {
    return OpenScreenIntent(best);
  }
  return UnknownIntent(heard);
}
