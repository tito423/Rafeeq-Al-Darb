import '../../../core/utils/arabic_normalize.dart';
import '../../../core/utils/digits.dart' show asciiDigits;

/// «رفيق» - the in-app assistant's understanding: an Arabic sentence (MSA or
/// Egyptian, as speech recognition writes it) -> one action in the app.
/// Owner, 2026-09-27: «مساعد آلي شخصي لكل ما هو في التطبيق».
///
/// Deliberately NOT a language model: every name it can act on comes from
/// the app's own catalogues ([AssistantCatalog]), matched by rule, so it
/// never invents a surah, a reciter or a book - and it never answers a
/// religious question itself, it only opens where the answer is.

/// What the app can do, by name.
enum AssistantScreen {
  home,
  quran,
  prayer,
  azkar,
  tasbeeh,
  library,
  more,
  settings,
  downloads,
  recitationPlayer,
  ayahPlayer,
  qibla,
  hifz,
  ruqyah,
  hajj,
  tajweed,
  dorar,
  shamela,
  onThisDay,
  dailyHadith,
}

sealed class AssistantIntent {
  const AssistantIntent();
}

class OpenScreenIntent extends AssistantIntent {
  const OpenScreenIntent(this.screen);
  final AssistantScreen screen;
  @override
  String toString() => 'open ${screen.name}';
}

/// Play a surah, by a named reciter when one was said.
class PlaySurahIntent extends AssistantIntent {
  const PlaySurahIntent(this.surah, {this.reciterId});
  final int surah;
  final String? reciterId;
  @override
  String toString() => 'play surah $surah by ${reciterId ?? '-'}';
}

class OpenBookIntent extends AssistantIntent {
  const OpenBookIntent(this.bookId);
  final String bookId;
  @override
  String toString() => 'book $bookId';
}

class AuthorBooksIntent extends AssistantIntent {
  const AuthorBooksIntent(this.author);
  final String author;
  @override
  String toString() => 'author $author';
}

/// «حدث في مثل هذا اليوم» for a hijri day, or today when [day] is null.
class OnThisDayIntent extends AssistantIntent {
  const OnThisDayIntent({this.day, this.month});
  final int? day;
  final int? month;
  @override
  String toString() => 'on this day ${day ?? '-'}/${month ?? '-'}';
}

/// Understood the words but not a thing the app has; [heard] is echoed
/// back so the reader sees what was recognised.
class UnknownIntent extends AssistantIntent {
  const UnknownIntent(this.heard);
  final String heard;
  @override
  String toString() => 'unknown';
}

class CatalogReciter {
  const CatalogReciter(this.id, this.names);
  final String id;

  /// Every name he goes by (Arabic, English).
  final List<String> names;
}

class CatalogBook {
  const CatalogBook(this.id, this.title, this.author);
  final String id;
  final String title;
  final String author;
}

/// The names the assistant may act on - built from the app's own data.
class AssistantCatalog {
  const AssistantCatalog({
    required this.surahs,
    this.reciters = const [],
    this.books = const [],
  });

  /// Surah names by number (index 0 = surah 1), Arabic.
  final List<String> surahs;
  final List<CatalogReciter> reciters;
  final List<CatalogBook> books;
}

/// Plain, comparable Arabic: no diacritics, one alef, ى->ي, ة->ه, no tatweel.
String norm(String s) => normalizeArabic(s)
    .replaceAll('ة', 'ه')
    .replaceAll('ـ', '')
    .replaceAll(RegExp(r'[^ء-ي0-9a-z\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

/// A word without the article or an attached preposition («والكهف»,
/// «بالمنشاوي», «للنووي» -> الكهف/المنشاوي/النووي -> كهف/منشاوي/نووي).
String bare(String w) {
  var x = w;
  for (final p in const ['وال', 'بال', 'فال', 'كال', 'لل', 'ال']) {
    if (x.startsWith(p) && x.length > p.length + 1) {
      x = x.substring(p.length);
      break;
    }
  }
  return x;
}

const _fillers = {
  'يا', 'رفيق', 'لو', 'سمحت', 'سمحتي', 'من', 'فضلك', 'عايز', 'عاوز', 'عايزه',
  'عاوزه', 'اريد', 'ابغي', 'ممكن', 'بالله', 'عليك', 'لي', 'ليا', 'لى', 'دلوقتي',
  'الان', 'حالا', 'بسرعه', 'بقي', 'طيب',
};

const _openVerbs = {
  'افتح', 'افتحلي', 'افتحي', 'وريني', 'ورني', 'اعرض', 'اعرضلي', 'روح', 'روحلي',
  'ادخل', 'خش', 'هات', 'هاتلي', 'اظهر', 'طلعلي', 'جيبلي', 'ودني', 'وديني',
};
const _playVerbs = {
  'شغل', 'شغلي', 'شغللي', 'اسمعني', 'سمعني', 'اقرا', 'اقرالي', 'اتلو', 'رتل',
  'ابدا', 'ابدأ',
};

/// Screen names and the words people use for them (normalised).
const Map<AssistantScreen, List<String>> _screenWords = {
  AssistantScreen.ayahPlayer: ['ايه بايه', 'ايه ايه', 'مشغل الايات', 'التلاوه ايه'],
  AssistantScreen.recitationPlayer: [
    'مشغل التلاوه', 'مشغل القران', 'مشغل التلاوات', 'التلاوات', 'القراء',
  ],
  AssistantScreen.onThisDay: ['حدث في مثل هذا اليوم', 'في مثل هذا اليوم', 'حصل في مثل'],
  AssistantScreen.dailyHadith: ['حديث اليوم'],
  AssistantScreen.azkar: ['الاذكار', 'اذكار', 'الاذكار'],
  AssistantScreen.tasbeeh: ['المسبحه', 'السبحه', 'مسبحه', 'التسبيح'],
  AssistantScreen.library: ['المكتبه', 'مكتبه', 'الكتب'],
  AssistantScreen.settings: ['الاعدادات', 'اعدادات', 'الضبط'],
  AssistantScreen.downloads: ['التنزيلات', 'التحميلات', 'تنزيلات', 'تحميلات'],
  AssistantScreen.qibla: ['القبله', 'اتجاه القبله'],
  AssistantScreen.prayer: ['مواقيت الصلاه', 'الصلاه', 'المواقيت', 'الاذان'],
  AssistantScreen.hifz: ['التحفيظ', 'التسميع', 'الحفظ'],
  AssistantScreen.ruqyah: ['الرقيه'],
  AssistantScreen.hajj: ['الحج', 'العمره', 'المناسك'],
  AssistantScreen.tajweed: ['التجويد'],
  AssistantScreen.dorar: ['الدرر', 'الدرر السنيه', 'التخريج'],
  AssistantScreen.shamela: ['الشامله', 'المكتبه الشامله'],
  AssistantScreen.quran: ['المصحف', 'القران'],
  AssistantScreen.more: ['المزيد'],
  AssistantScreen.home: ['الرئيسيه', 'الصفحه الرئيسيه', 'البدايه'],
};

const _hijriMonths = [
  ['محرم'],
  ['صفر'],
  ['ربيع الاول', 'ربيع اول'],
  ['ربيع الثاني', 'ربيع الاخر', 'ربيع تاني'],
  ['جمادي الاولي', 'جمادي الاول', 'جمادي اولي'],
  ['جمادي الثانيه', 'جمادي الاخره', 'جمادي الاخر', 'جمادي تاني'],
  ['رجب'],
  ['شعبان'],
  ['رمضان'],
  ['شوال'],
  ['ذو القعده', 'ذي القعده', 'القعده'],
  ['ذو الحجه', 'ذي الحجه', 'الحجه'],
];

class AssistantParser {
  AssistantParser(this.catalog)
      : _surahs = [for (final s in catalog.surahs) _surahKey(s)];

  /// «سُورَةُ آلِ عِمۡرَانَ» -> «ال عمران»... -> words without «سورة» and
  /// without the article: «عمران» for آل عمران would be wrong, so «آل» is
  /// kept (it is a word, not the article).
  static String _surahKey(String name) {
    var w = norm(name).split(' ');
    if (w.isNotEmpty && w.first == 'سوره') w = w.sublist(1);
    return w.map((x) => x == 'ال' ? x : bare(x)).join(' ');
  }

  final AssistantCatalog catalog;
  final List<String> _surahs;

  AssistantIntent parse(String heard) {
    final text = norm(asciiDigits(heard));
    final words = [
      for (final w in text.split(' '))
        if (w.isNotEmpty && !_fillers.contains(w)) w,
    ];
    final clean = words.join(' ');
    if (clean.isEmpty) return UnknownIntent(heard);

    final playing = words.any(_playVerbs.contains);

    // «حدث في مثل هذا اليوم [١٢ ربيع الأول]»
    if (_hasPhrase(clean, _screenWords[AssistantScreen.onThisDay]!)) {
      return _onThisDay(clean);
    }
    // «كل كتب ابن الجوزي» / «كتب ابن الجوزي»
    final author = RegExp(r'(?:كل )?كتب (.+)$').firstMatch(clean);
    if (author != null) {
      final a = _author(author.group(1)!);
      if (a != null) return AuthorBooksIntent(a);
    }
    // «كتاب الأذكار للنووي»
    final book = RegExp(r'كتاب (.+)$').firstMatch(clean);
    if (book != null) {
      final b = _book(book.group(1)!);
      if (b != null) return OpenBookIntent(b);
    }
    // «شغل سورة الكهف بصوت المنشاوي» / «اقرالي يس للعفاسي»
    final surah = _surahIn(clean, requireWord: !playing);
    if (surah != null) {
      // The surah's own words are not a reciter's name («آل عمران» is not
      // the reciter «عمران»).
      final sw = _surahs[surah - 1].split(' ').toSet();
      final rest = clean.split(' ').where((w) => !sw.contains(bare(w))).join(' ');
      return PlaySurahIntent(surah, reciterId: _reciterIn(rest));
    }
    // A screen: the longest phrase that appears wins («مشغل التلاوه» beats
    // «التلاوه», «المكتبه الشامله» beats «المكتبه»).
    // «آية بآية» names the ayah player even inside «مشغل التلاوة آية بآية».
    if (_hasPhrase(clean, _screenWords[AssistantScreen.ayahPlayer]!)) {
      return const OpenScreenIntent(AssistantScreen.ayahPlayer);
    }
    // A screen opens on a command («افتح …») or when the sentence is only
    // its name. A question that merely mentions one («ما حكم صلاة الجمعة»)
    // is not a command - the assistant does not answer questions.
    final commanded = words.any(_openVerbs.contains) || playing;
    AssistantScreen? best;
    var bestLen = 0;
    for (final e in _screenWords.entries) {
      for (final p in e.value) {
        if (p.length > bestLen && _hasPhrase(clean, [p])) {
          best = e.key;
          bestLen = p.length;
        }
      }
    }
    if (best != null &&
        (commanded || words.length <= norm(_longest(best)).split(' ').length + 1)) {
      return OpenScreenIntent(best);
    }
    return UnknownIntent(heard);
  }

  static String _longest(AssistantScreen s) =>
      _screenWords[s]!.reduce((a, b) => a.length >= b.length ? a : b);

  bool _hasPhrase(String clean, List<String> phrases) {
    final padded = ' $clean ';
    final bareText = ' ${clean.split(' ').map(bare).join(' ')} ';
    for (final p in phrases) {
      final np = norm(p);
      if (padded.contains(' $np ') ||
          bareText.contains(' ${np.split(' ').map(bare).join(' ')} ')) {
        return true;
      }
    }
    return false;
  }

  /// A surah named in [clean]: after «سورة» anywhere, or (when a play verb
  /// was said) any surah name among the words. Longest name wins («آل
  /// عمران» over «عمران»).
  int? _surahIn(String clean, {required bool requireWord}) {
    final ws = clean.split(' ').map(bare).toList();
    final at = ws.indexOf('سوره');
    if (requireWord && at < 0) return null;
    final from = at >= 0 ? at + 1 : 0;
    final tail = ws.sublist(from).join(' ');
    int? best;
    var bestLen = 0;
    for (var i = 0; i < _surahs.length; i++) {
      final n = _surahs[i];
      if (n.length > bestLen && (' $tail ').contains(' $n ')) {
        best = i + 1;
        bestLen = n.length;
      }
    }
    // «سورة ١٨» / «سوره رقم ١٨»
    if (best == null && at >= 0) {
      final m = RegExp(r'^(?:رقم )?(\d{1,3})\b').firstMatch(tail);
      final n = int.tryParse(m?.group(1) ?? '');
      if (n != null && n >= 1 && n <= 114) best = n;
    }
    return best;
  }

  /// A reciter named after «بصوت / للشيخ / الشيخ / القارئ / لل…» or
  /// anywhere: the one whose name shares the most words with the sentence.
  String? _reciterIn(String clean) {
    final said = clean.split(' ').map(bare).toSet();
    String? best;
    var bestScore = 0.0;
    for (final r in catalog.reciters) {
      for (final name in r.names) {
        final nw = norm(name).split(' ').map(bare).where((w) => w.length > 1).toList();
        if (nw.isEmpty) continue;
        final hit = nw.where(said.contains).length;
        // A family name alone («المنشاوي») is enough; a first name alone
        // («محمد») is not.
        final score = hit / nw.length + (hit > 0 && said.contains(nw.last) ? 0.5 : 0);
        if (hit > 0 && score > bestScore && (said.contains(nw.last) || hit >= 2)) {
          best = r.id;
          bestScore = score;
        }
      }
    }
    return best;
  }

  String? _book(String said) {
    final words = said.split(' ').map(bare).where((w) => w.length > 1).toSet();
    String? best;
    var bestScore = 0.0;
    for (final b in catalog.books) {
      final tw = norm(b.title).split(' ').map(bare).where((w) => w.length > 1).toList();
      final aw = norm(b.author).split(' ').map(bare).where((w) => w.length > 1).toSet();
      if (tw.isEmpty) continue;
      // How much of what was SAID is in the title (a title is often longer
      // than what people call it: «بلوغ المرام» for «بلوغ المرام من أدلة
      // الأحكام»); the author's words, when said, count too.
      final titleSet = tw.toSet();
      final saidTitle = words.where((w) => !aw.contains(w)).toList();
      if (saidTitle.isEmpty) continue;
      final covered = saidTitle.where(titleSet.contains).length / saidTitle.length;
      final authorHit = aw.isEmpty ? 0 : aw.where(words.contains).length / aw.length;
      final score = covered + 0.3 * authorHit + 0.1 * (saidTitle.length / tw.length);
      if (covered >= 0.6 && score > bestScore) {
        best = b.id;
        bestScore = score;
      }
    }
    return best;
  }

  String? _author(String said) {
    final words = said.split(' ').map(bare).where((w) => w.length > 1).toSet();
    String? best;
    var bestScore = 0.0;
    for (final b in catalog.books) {
      final aw = norm(b.author).split(' ').map(bare).where((w) => w.length > 1).toList();
      if (aw.isEmpty) continue;
      final hit = aw.where(words.contains).length;
      final score = hit / words.length;
      if (hit > 0 && score > bestScore && hit >= (words.length >= 2 ? 2 : 1)) {
        best = b.author;
        bestScore = score;
      }
    }
    return best;
  }

  OnThisDayIntent _onThisDay(String clean) {
    int? month;
    var monthLen = 0;
    for (var i = 0; i < _hijriMonths.length; i++) {
      for (final m in _hijriMonths[i]) {
        if (m.length > monthLen && (' $clean ').contains(' $m ')) {
          month = i + 1;
          monthLen = m.length;
        }
      }
    }
    final d = RegExp(r'\b(\d{1,2})\b').firstMatch(clean);
    final day = int.tryParse(d?.group(1) ?? '');
    return OnThisDayIntent(
      day: day != null && day >= 1 && day <= 30 ? day : null,
      month: month,
    );
  }
}
