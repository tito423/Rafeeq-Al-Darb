part of 'assistant_intent.dart';

class MemorizeSurahIntent extends AssistantIntent {
  const MemorizeSurahIntent(this.surah);
  final int surah;
  @override
  String toString() => 'memorize surah $surah';
}

class OpenSunanSurahIntent extends AssistantIntent {
  const OpenSunanSurahIntent(this.surah);
  final int surah;
  @override
  String toString() => 'sunan surah $surah';
}

class OpenAzkarSectionIntent extends AssistantIntent {
  const OpenAzkarSectionIntent(this.sectionId);
  final int sectionId;
  @override
  String toString() => 'azkar section $sectionId';
}

class OpenAyahReciterIntent extends AssistantIntent {
  const OpenAyahReciterIntent(this.reciterId);
  final String reciterId;
  @override
  String toString() => 'ayah reciter $reciterId';
}

class OpenWholeSurahReciterIntent extends AssistantIntent {
  const OpenWholeSurahReciterIntent(this.reciterId);
  final int reciterId;
  @override
  String toString() => 'whole surah reciter $reciterId';
}

extension on AssistantParser {
  int? _wholeSurahReciterIn(String clean) {
    final said = clean.split(' ').map(bare).toSet();
    int? best;
    var bestScore = 0.0;
    for (final r in catalog.wholeSurahReciters) {
      for (final name in r.names) {
        final nw = norm(name)
            .split(' ')
            .map(bare)
            .where((w) => w.length > 1 &&
                w != 'قارئ' && w != 'القارئ' &&
                w != 'شيخ' && w != 'الشيخ')
            .toList();
        if (nw.isEmpty) continue;
        final hit = nw.where(said.contains).length;
        final score = hit / nw.length +
            (hit > 0 && said.contains(nw.last) ? 0.5 : 0);
        if (hit > 0 && score > bestScore &&
            (said.contains(nw.last) || hit >= 2)) {
          best = r.id;
          bestScore = score;
        }
      }
    }
    return best;
  }
}
