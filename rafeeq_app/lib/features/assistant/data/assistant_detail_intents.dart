part of 'assistant_intent.dart';

class CatalogAzkarSection {
  const CatalogAzkarSection(this.id, this.names);
  final int id;
  final List<String> names;
}

class CatalogWholeReciter {
  const CatalogWholeReciter(this.id, this.names);
  final int id;
  final List<String> names;
}

class CatalogHadeethCategory {
  const CatalogHadeethCategory(this.id, this.names);
  final String id;
  final List<String> names;
}

class CatalogHadithBook {
  const CatalogHadithBook(this.id, this.names);
  final int id;
  final List<String> names;
}

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

class OpenHadeethCategoryIntent extends AssistantIntent {
  const OpenHadeethCategoryIntent(this.categoryId);
  final String categoryId;
  @override
  String toString() => 'hadeeth category $categoryId';
}

class OpenHadithBookIntent extends AssistantIntent {
  const OpenHadithBookIntent(this.bookId);
  final int bookId;
  @override
  String toString() => 'hadith book $bookId';
}

extension on AssistantParser {
  int? _hadithBookIn(List<String> words) {
    final title = words
        .where((word) => !AssistantParser._open.contains(word) &&
            !AssistantParser._bookWord.contains(word))
        .map(bare)
        .join(' ');
    for (final book in catalog.hadithBooks) {
      for (final name in book.names) {
        if (title == AssistantParser._canon(name).split(' ').map(bare).join(' ')) {
          return book.id;
        }
      }
    }
    return null;
  }

  String? _hadeethCategoryIn(String clean) {
    String? best;
    var bestLength = 0;
    for (final category in catalog.hadeethCategories) {
      for (final name in category.names.map(AssistantParser._canon)) {
        if (name.length > bestLength && _hasPhrase(clean, [name])) {
          best = category.id;
          bestLength = name.length;
        }
      }
    }
    return best;
  }

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
