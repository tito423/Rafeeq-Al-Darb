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

class CatalogHadithChapter {
  const CatalogHadithChapter(this.bookId, this.chapterNo, this.names);
  final int bookId;
  final num chapterNo;
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

/// «فين كلمة الرحمن في القرآن» / «where is the word mercy in the Qur'an»
/// (owner, 2026-09-29): every word of the Qur'an is findable by voice. The
/// search itself is `QuranRepository.searchQuran` - the same index the search
/// screen uses - so a word, its derivatives and a whole phrase all work.
class QuranWordIntent extends AssistantIntent {
  const QuranWordIntent(this.query);
  final String query;
  @override
  String toString() => 'quran word $query';
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

/// «شغل الآية بصوت المنشاوي» - no surah named: the ayah open in the Quran
/// tab (else the last page read) in that reciter's voice; while a
/// recitation is going on, the same ayah goes on in the new voice.
class PlayCurrentAyahIntent extends AssistantIntent {
  const PlayCurrentAyahIntent(this.reciterId);
  final String reciterId;
  @override
  String toString() => 'play current ayah by $reciterId';
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

class OpenHadithChapterIntent extends AssistantIntent {
  const OpenHadithChapterIntent(this.bookId, this.chapterNo);
  final int bookId;
  final num chapterNo;
  @override
  String toString() => 'hadith chapter $bookId/$chapterNo';
}

class OpenHadithDetailIntent extends AssistantIntent {
  const OpenHadithDetailIntent(this.bookId, this.numberInBook);
  final int bookId;
  final int numberInBook;
  @override
  String toString() => 'hadith detail $bookId/$numberInBook';
}

/// «فينكلمة» / «فينكلمت» -> «فين» «كلمه»: the marker word split out of the
/// word the recogniser glued it to.
List<String> _splitGlued(String w) {
  for (final m in const ['كلمه', 'كلمت']) {
    if (w != m && w.contains(m)) {
      return w.replaceFirst(m, ' كلمه ').trim().split(RegExp(r'\s+'));
    }
  }
  return [w];
}

extension on AssistantParser {
  /// The word or phrase asked for in «فين كلمة X في القرآن», or null when the
  /// sentence is not that question. It reads the RAW words, not the corrected
  /// ones: spelling correction pulls unknown words toward the command
  /// vocabulary, and a Qur'anic word must reach the search exactly as heard.
  String? _quranWordQuery(String heard) {
    // «كلمت»: the recogniser also writes the closing ta as an open one.
    const marker = {'كلمه', 'كلمت', 'لفظ', 'لفظه', 'word', 'palabra', 'mot', 'palavra', 'слово'};
    // The recogniser glues short words to their neighbour: on emulator-5554
    // «فين كلمة عسعس» came out «فينكلمة عسعس». A word that carries «كلمه»
    // inside it is split around it.
    final raw = <String>[
      for (final w in norm(asciiDigits(heard)).split(' '))
        if (w.isNotEmpty)
          ..._splitGlued(w),
    ];
    const context = {
      'القران', 'قران', 'ذكرت', 'وردت', 'ورد', 'ذكر', 'فين', 'اين', 'وين', 'امتي',
      'فيها', 'فيه', 'ايه', 'اية', 'where', 'donde', 'onde', 'quran', 'coran',
      'koran', 'где', 'коране',
    };
    const noise = {
      'في', 'ف', 'القران', 'قران', 'ذكرت', 'وردت', 'ورد', 'ذكر', 'فين', 'اين',
      'وين', 'دي', 'ده', 'هذه', 'هذا', 'هذي', 'مره', 'كام', 'ايه', 'اية', 'اي',
      'سوره', 'موضع', 'مواضع', 'امتي', 'وريني', 'اعرض', 'اعرضلي', 'جيب', 'هات',
      'فيها', 'فيه', 'لي', 'ليا', 'the', 'in', 'quran', 'where', 'is', 'was',
      'mentioned', 'of', 'de', 'en', 'el', 'la', 'le', 'les', 'du', 'dans', 'где',
      'в', 'коране', 'donde', 'onde', 'coran', 'koran',
    };
    final i = raw.indexWhere(marker.contains);
    if (i < 0 || !raw.any(context.contains)) return null;
    final taken = <String>[];
    for (var k = i + 1; k < raw.length; k++) {
      if (noise.contains(raw[k])) {
        if (taken.isEmpty) continue;
        break;
      }
      taken.add(raw[k]);
    }
    if (taken.isEmpty) {
      for (var k = 0; k < i; k++) {
        if (!noise.contains(raw[k]) && !raw[k].startsWith('دور')) taken.add(raw[k]);
      }
    }
    return taken.isEmpty ? null : taken.join(' ');
  }

  AssistantIntent? _collectionDetailIn(String clean) {
    final azkarSection = _azkarSectionIn(clean);
    // «اسمع أذكار الصباح»: the recorded adhkar, not the written list
    // (sections 27 and 28 of azkar.db are the morning and the evening).
    if ((azkarSection == 27 || azkarSection == 28) &&
        clean.split(' ').any(_listenWords.contains)) {
      return OpenScreenIntent(azkarSection == 27
          ? AssistantScreen.adhkarListenMorning
          : AssistantScreen.adhkarListenEvening);
    }
    if (azkarSection != null) return OpenAzkarSectionIntent(azkarSection);
    final category = _hadeethCategoryIn(clean);
    return category == null ? null : OpenHadeethCategoryIntent(category);
  }

  static final _listenWords = _normSet(const [
    'اسمع', 'استمع', 'اسمعني', 'سمعني', 'اسمعلي', 'شغل', 'شغلي', 'شغللي',
    'شغلها', 'سمعها', 'بصوت', 'صوت', 'صوتي', 'listen', 'play', 'audio',
    'escuchar', 'escucha', 'ecouter', 'ecoute', 'ouvir', 'слушать', 'послушать',
    'سنو', 'سناؤ',
  ]);

  int? _hadithNumberIn(String clean) {
    const markers = {'حديث', 'الحديث', 'hadith', 'hadeeth'};
    if (!clean.split(' ').map(bare).any(markers.contains)) return null;
    final match = RegExp(r'(?:رقم|number|no)?\s*(\d{1,6})(?:\s|$)')
        .firstMatch(clean);
    final digits = int.tryParse(match?.group(1) ?? '');
    if (digits != null) return digits;
    for (final word in clean.split(' ')) {
      final spoken = _numberWords[word];
      if (spoken != null) return spoken;
    }
    return null;
  }

  int? _azkarSectionIn(String clean) {
    int? best;
    var bestLen = 0;
    for (final e in _azkarSectionKeys.entries) {
      for (final name in e.value) {
        if (name.length > bestLen && _hasPhrase(clean, [name])) {
          best = e.key;
          bestLen = name.length;
        }
      }
    }
    if (best != null) return best;

    // The book's own titles are long («الأذكار بعد السلام من الصلاة») and
    // people say them short («الأذكار بعد الصلاة»). A title of three or more
    // content words still matches when exactly one of them was not said, and
    // only when that reading is unique.
    const filler = {'من', 'في', 'عن', 'على', 'الى', 'ما', 'اذا', 'عند', 'او'};
    final said = clean.split(' ').map(bare).toSet();
    var bestHits = 0;
    var ambiguous = false;
    for (final e in _azkarSectionKeys.entries) {
      for (final name in e.value) {
        final content =
            name.split(' ').map(bare).where((w) => !filler.contains(w)).toList();
        if (content.length < 3) continue;
        final hits = content.where(said.contains).length;
        if (hits != content.length - 1) continue;
        if (hits > bestHits) {
          best = e.key;
          bestHits = hits;
          ambiguous = false;
        } else if (hits == bestHits && best != e.key) {
          ambiguous = true;
        }
      }
    }
    return ambiguous ? null : best;
  }

  bool _hasHadithChapterWord(List<String> words) => words
      .map(bare)
      .any(const {'باب', 'فصل', 'ابواب', 'فصول', 'chapter', 'capitulo',
        'chapitre', 'glava'}.contains);

  int? _hadithBookMentionedIn(String clean) {
    int? best;
    var bestLength = 0;
    for (final book in catalog.hadithBooks) {
      for (final name in book.names.map(AssistantParser._canon)) {
        if (name.length > bestLength && _hasPhrase(clean, [name])) {
          best = book.id;
          bestLength = name.length;
        }
      }
    }
    return best;
  }

  num? _hadithChapterIn(List<String> words, int bookId) {
    final bookWords = <String>{
      for (final book in catalog.hadithBooks)
        if (book.id == bookId)
          for (final name in book.names)
            ...AssistantParser._canon(name).split(' ').map(bare),
    };
    final title = words
        .map(bare)
        .where((word) => !AssistantParser._open.contains(word) &&
            !AssistantParser._bookWord.contains(word) &&
            !bookWords.contains(word) &&
            !const {'باب', 'فصل', 'ابواب', 'فصول', 'chapter', 'capitulo',
              'chapitre', 'glava'}.contains(word))
        .join(' ');
    for (final chapter in catalog.hadithChapters) {
      if (chapter.bookId != bookId) continue;
      for (final raw in chapter.names) {
        final name = AssistantParser._canon(raw);
        final short = name.startsWith('كتاب ') ? name.substring(5) : name;
        for (final phrase in {name, short}) {
          final key = phrase.split(' ').map(bare).join(' ');
          if (title == key) return chapter.chapterNo;
        }
      }
    }
    return null;
  }

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
