import '../../../core/utils/arabic_normalize.dart';
import '../../../core/utils/digits.dart' show asciiDigits;
import 'assistant_lexicon.dart' as lex;

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
  clockFaces,
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

/// The app's look: 'light' / 'dark' / 'rgb' / 'system'.
class SetThemeIntent extends AssistantIntent {
  const SetThemeIntent(this.theme);
  final String theme;
  @override
  String toString() => 'theme $theme';
}

/// The app's language, by locale code.
class SetLanguageIntent extends AssistantIntent {
  const SetLanguageIntent(this.code);
  final String code;
  @override
  String toString() => 'language $code';
}

/// A switch in the settings: 'motion' / 'splash' / 'transliteration'.
class ToggleOptionIntent extends AssistantIntent {
  const ToggleOptionIntent(this.option, {required this.on});
  final String option;
  final bool on;
  @override
  String toString() => 'toggle $option ${on ? 'on' : 'off'}';
}

/// A settings section, opened and scrolled to: «افتح إعدادات الخط»,
/// «مواقيت الصلاة في الإعدادات», or the name of anything inside it.
/// [section] is the section title's translation key
/// (`assistantSettingsSections`).
class OpenSettingIntent extends AssistantIntent {
  const OpenSettingIntent(this.section);
  final String section;
  @override
  String toString() => 'setting $section';
}

/// A title to find in Shamela's own catalogue (not yet on the phone):
/// «دورلي في الشاملة على صيد الخاطر», «نزلي كتاب الزهد لأحمد من الشاملة».
/// [title] is what was SAID, uncorrected - a book name is not a command
/// word to be snapped to the nearest one the app knows.
class ShamelaSearchIntent extends AssistantIntent {
  const ShamelaSearchIntent(this.title, {required this.download});
  final String title;
  final bool download;
  @override
  String toString() => 'shamela "$title"${download ? ' download' : ''}';
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
    this.surahsLatin = const [],
    this.reciters = const [],
    this.books = const [],
    this.screenLabels = const {},
    this.settingLabels = const [],
    this.optionLabels = const {},
    this.settingSections = const {},
  });

  /// Settings section key -> its title and everything named inside it, in
  /// the seven languages ([labelsFrom], `assistant_settings_map.dart`).
  final Map<String, List<String>> settingSections;

  /// Surah names by number (index 0 = surah 1), Arabic.
  final List<String> surahs;

  /// The same, transliterated («Al-Kahf»), for the other languages.
  final List<String> surahsLatin;
  final List<CatalogReciter> reciters;
  final List<CatalogBook> books;

  /// Screen titles from the app's seven translation files.
  final Map<AssistantScreen, List<String>> screenLabels;

  /// Every settings title in the seven languages - said, they open Settings.
  final List<String> settingLabels;

  /// Switch titles by option, from the translations.
  final Map<String, List<String>> optionLabels;
}

const _latinFold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'ç': 'c', 'è': 'e',
  'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ù': 'u',
  'ú': 'u', 'û': 'u', 'ü': 'u', 'œ': 'oe', 'ÿ': 'y',
};

/// Cyrillic -> Latin, so «аль-Кахф» and "Al-Kahf" meet in one spelling.
const _cyr = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
  'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'i', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sh', 'ъ': '',
  'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
};

/// Urdu letters -> their Arabic forms, so Urdu speech meets Arabic names.
const _urdu = {
  'ک': 'ك', 'ی': 'ي', 'ې': 'ي', 'ے': 'ي', 'ۓ': 'ي', 'ہ': 'ه', 'ۃ': 'ه',
  'ھ': 'ه', 'ں': 'ن', '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
  '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
};

final _latinWord = RegExp(r'^[a-z]+$');

/// A transliterated word, spelled one way: "Faatiha"/"Fatiha", "Yaseen"/
/// "Yasin", "Baqara"/"Bakara", "Kahf"/«Кахф» -> the same string.
String _foldLatin(String w) => w
    .replaceAll('ee', 'i')
    .replaceAll('oo', 'u')
    .replaceAll('ou', 'u')
    .replaceAll('kh', 'h')
    .replaceAll('dh', 'd')
    .replaceAll('th', 't')
    .replaceAll('q', 'k')
    .replaceAll('ph', 'f')
    .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

/// Plain, comparable text in any of the seven languages: Arabic without
/// diacritics (one alef, ى->ي, ة->ه), Urdu letters as Arabic, Latin without
/// accents, Cyrillic in Latin letters; punctuation gone; lower case.
String norm(String s) {
  final b = StringBuffer();
  for (final r in normalizeArabic(s).toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_urdu[c] ?? _latinFold[c] ?? _cyr[c] ?? c);
  }
  final flat = b
      .toString()
      .replaceAll('ة', 'ه')
      .replaceAll('ـ', '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return flat
      .split(' ')
      .map((w) => _latinWord.hasMatch(w) ? _foldLatin(w) : w)
      .join(' ');
}

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

Set<String> _normSet(Iterable<String> words) =>
    {for (final w in words) ...norm(w).split(' ')}..remove('');

/// Latin articles of transliterated names («al-», «ash-», «ul»), dropped
/// like fillers.
const _latinArticles = {'al', 'el', 'ul', 'ar', 'ash', 'as', 'az', 'ad', 'at', 'an', 'i'};

/// Levenshtein distance, giving up (returning [max] + 1) once it must
/// exceed [max].
int editDistance(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

final _wakeNorm = {for (final w in lex.wakeWords) norm(w)};

/// What was said after «يا رفيق», or null when it was not called.
///
/// The recogniser writes the name many ways - «يار فيق», «يارفيق», «رفيك»,
/// "rafek", "rafec", "refiq", «рафик» - so a word (or two words joined)
/// within one edit of a form of the name counts, and «يا» glued to it is
/// taken off. An empty string means the name alone.
String? afterWakeWord(String heard) {
  final w = norm(heard).split(' ').where((x) => x.isNotEmpty).toList();
  bool isName(String x) {
    var t = x;
    if (t.startsWith('يا') && t.length > 4) t = t.substring(2);
    if (t.startsWith('ya') && t.length > 5) t = t.substring(2);
    if (t.startsWith('hey') && t.length > 6) t = t.substring(3);
    for (final n in _wakeNorm) {
      if (editDistance(t, n, 1) <= 1) return true;
    }
    return false;
  }

  // The name glued to the next word («يارفيقورين» = «يا رفيق وريني»).
  String? gluedRest(String x) {
    var t = x;
    if (t.startsWith('يا')) t = t.substring(2);
    for (final n in _wakeNorm) {
      if (n.length >= 4 && t.length >= n.length + 2 && t.startsWith(n)) {
        return t.substring(n.length);
      }
    }
    return null;
  }

  for (var i = 0; i < w.length && i < 4; i++) {
    if (isName(w[i])) return w.sublist(i + 1).join(' ');
    final glued = gluedRest(w[i]);
    if (glued != null) return [glued, ...w.sublist(i + 1)].join(' ');
    if (i + 1 < w.length && isName(w[i] + w[i + 1])) {
      return w.sublist(i + 2).join(' ');
    }
  }
  return null;
}

/// Day numbers as they are said (Egyptian and MSA), normalised.
final _numberWords = <String, int>{
  for (final e in const {
    1: ['واحد', 'وحده', 'الاول'], 2: ['اتنين', 'اثنين', 'اثنان', 'تاني'],
    3: ['تلاته', 'ثلاثه', 'تالت'], 4: ['اربعه', 'اربع', 'رابع'],
    5: ['خمسه', 'خمس', 'خامس'], 6: ['سته', 'ست', 'سادس'],
    7: ['سبعه', 'سبع', 'سابع'], 8: ['تمانيه', 'ثمانيه', 'تامن'],
    9: ['تسعه', 'تسع', 'تاسع'], 10: ['عشره', 'عاشر'],
    11: ['حداشر', 'احداشر', 'احدعشر'], 12: ['اتناشر', 'اتناش', 'اثناعشر', 'اطناشر'],
    13: ['تلتاشر', 'تلطاشر', 'ثلاثهعشر'], 14: ['اربعتاشر', 'اربعطاشر'],
    15: ['خمستاشر', 'خمسطاشر'], 16: ['ستاشر', 'سطاشر'],
    17: ['سبعتاشر', 'سبعطاشر'], 18: ['تمنتاشر', 'طمنطاشر'],
    19: ['تسعتاشر', 'تسعطاشر'], 20: ['عشرين', 'عشرون'],
    30: ['تلاتين', 'ثلاثين', 'ثلاثون'],
  }.entries)
    for (final w in e.value) norm(w): e.key,
};

class AssistantParser {
  AssistantParser(this.catalog) {
    _surahKeys = [
      for (var i = 0; i < catalog.surahs.length; i++)
        {
          _surahKey(catalog.surahs[i]),
          if (i < catalog.surahsLatin.length) _surahKey(catalog.surahsLatin[i]),
        }..remove(''),
    ];
    _screens = {
      for (final e in lex.screenWords.entries)
        e.key: [for (final p in e.value) _canon(p)],
    };
    for (final e in catalog.screenLabels.entries) {
      (_screens[e.key] ??= []).addAll(e.value.map(_canon));
    }
    _screens.updateAll((_, v) => v.where((p) => p.isNotEmpty).toSet().toList());
    _sections = {
      for (final e in catalog.settingSections.entries)
        e.key: e.value.map(_canon).where((p) => p.isNotEmpty).toSet().toList(),
    };
    _settings = catalog.settingLabels
        .map(_canon)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    _options = {
      for (final e in lex.optionWords.entries)
        e.key: {
          ...e.value.map(_canon),
          ...?catalog.optionLabels[e.key]?.map(_canon),
        }.where((p) => p.isNotEmpty).toList(),
    };

    // Every word the assistant can act on, for [_correct].
    final v = <String>{
      ..._open, ..._play, ..._surahWord, ..._bookWord, ..._booksOf,
      ..._shamelaWord, ..._download,
      ..._change, ..._on, ..._off, ..._langWord, ..._themeWord,
      for (final l in _screens.values) for (final ph in l) ...ph.split(' '),
      for (final ph in _settings) ...ph.split(' '),
      for (final l in _sections.values) for (final ph in l) ...ph.split(' '),
      for (final l in _options.values) for (final ph in l) ...ph.split(' '),
      for (final k in _surahKeys) for (final ph in k) ...ph.split(' '),
      for (final m in lex.hijriMonthWords) for (final w in m) ...norm(w).split(' '),
      for (final l in lex.languageNames.values) for (final w in l) ...norm(w).split(' '),
      for (final l in lex.themeValueWords.values) for (final w in l) ...norm(w).split(' '),
      for (final l in lex.onThisDayPhrases) ...norm(l).split(' '),
    }..removeWhere((w) => w.length < 3);
    // Names from the catalogues are a second tier: a slip is corrected to a
    // command word first («الاثكار» -> «الاذكار», not a book's «الافكار»).
    final names = <String>{
      for (final r in catalog.reciters)
        for (final n in r.names) ...norm(n).split(' '),
      for (final b in catalog.books) ...norm('${b.title} ${b.author}').split(' '),
    }..removeWhere((w) => w.length < 3 || v.contains(w));
    _tiers = [_byLen(v), _byLen(names)];
    _vocab = {...v, ...names};
  }

  static Map<int, List<String>> _byLen(Set<String> words) {
    final m = <int, List<String>>{};
    for (final w in words) {
      (m[w.length] ??= []).add(w);
    }
    return m;
  }

  late final Set<String> _vocab;
  late final List<Map<int, List<String>>> _tiers;

  /// A heard word the app does not know, replaced by the nearest word it
  /// does - the recogniser's slips («الأثكار» -> «الاذكار», «التديق» ->
  /// «التطبيق», «بلغ» -> «بلوغ»). One edit for words of 4-6 letters, two
  /// from 7; shorter words and ties are left alone rather than guessed.
  String _correct(String w) {
    if (w.length < 4 || _vocab.contains(w) || _fillers.contains(w)) return w;
    final max = w.length >= 7 ? 2 : 1;
    for (final tier in _tiers) {
      String? best;
      var bestD = max + 1;
      var tie = false;
      for (var len = w.length - max; len <= w.length + max; len++) {
        for (final c in tier[len] ?? const <String>[]) {
          final d = editDistance(w, c, max);
          if (d < bestD) {
            best = c;
            bestD = d;
            tie = false;
          } else if (d == bestD && c != best) {
            tie = true;
          }
        }
      }
      if (best != null) return tie ? w : best;
    }
    return w;
  }

  final AssistantCatalog catalog;
  late final List<Set<String>> _surahKeys;
  late final Map<AssistantScreen, List<String>> _screens;
  late final List<String> _settings;
  late final Map<String, List<String>> _sections;
  late final Map<String, List<String>> _options;

  static final _fillers = {..._normSet(lex.fillerWords), ..._latinArticles};
  static final _open = _normSet(lex.openVerbs);
  static final _play = _normSet(lex.playVerbs);
  static final _surahWord = _normSet(lex.surahWords);
  static final _bookWord = _normSet(lex.bookWords);
  static final _shamelaWord = _normSet(lex.shamelaWords);
  static final _shamelaNoise = _normSet(lex.shamelaNoise);
  static final _download = _normSet(lex.downloadVerbs);
  static final _booksOf = _normSet(lex.booksOfWords);
  static final _change = _normSet(lex.changeVerbs);
  static final _on = _normSet(lex.onWords);
  static final _off = _normSet(lex.offWords);
  static final _langWord = _normSet(lex.languageWords);
  static final _themeWord = _normSet(lex.themeWords);

  /// A phrase as the parser compares it: normalised, fillers out.
  static String _canon(String p) => norm(asciiDigits(p))
      .split(' ')
      .where((w) => w.isNotEmpty && !_fillers.contains(w))
      .join(' ');

  /// «سُورَةُ آلِ عِمۡرَانَ» -> «ال عمران»; "Aal-i-Imraan" -> "imran".
  /// «آل» is kept in Arabic (a word there, not the article).
  static String _surahKey(String name) {
    var w = norm(name).split(' ').where((x) => x.isNotEmpty).toList();
    if (w.isNotEmpty && _surahWord.contains(w.first)) w = w.sublist(1);
    return w
        .where((x) => !_latinArticles.contains(x))
        .map((x) => x == 'ال' ? x : bare(x))
        .join(' ');
  }

  AssistantIntent parse(String heard) {
    final all = norm(asciiDigits(heard))
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map(_correct)
        .toList();
    final words = [for (final w in all) if (!_fillers.contains(w)) w];
    final clean = words.join(' ');
    if (clean.isEmpty) return UnknownIntent(heard);
    final said = all.toSet();

    final playing = words.any(_play.contains);
    final changing = words.any(_change.contains);

    // «حدث في مثل هذا اليوم [١٢ ربيع الأول]»
    if (_hasPhrase(clean, lex.onThisDayPhrases.map(_canon))) {
      return _onThisDay(clean);
    }
    // «دورلي في الشاملة على …» / «نزلي كتاب … من الشاملة». Before the
    // library's own books: said with «الشاملة», it is Shamela that is meant.
    final raw = norm(asciiDigits(heard)).split(' ').where((w) => w.isNotEmpty);
    if (all.any(_shamelaWord.contains) || raw.any(_shamelaWord.contains)) {
      final title = [
        for (final w in raw)
          if (!_fillers.contains(w) &&
              !_shamelaWord.contains(w) &&
              !_shamelaNoise.contains(w) &&
              !_download.contains(w))
            w,
      ].join(' ');
      if (title.isNotEmpty) {
        return ShamelaSearchIntent(title,
            download: raw.any(_download.contains) || all.any(_download.contains));
      }
    }
    // «كل كتب ابن الجوزي» / "books by Ibn al-Jawzi"
    final ob = words.indexWhere(_booksOf.contains);
    if (ob >= 0 && ob < words.length - 1) {
      final a = _author(words.sublist(ob + 1).join(' '));
      if (a != null) return AuthorBooksIntent(a);
    }
    // «كتاب الأذكار للنووي»
    final bk = words.indexWhere(_bookWord.contains);
    if (bk >= 0 && bk < words.length - 1) {
      final b = _book(words.sublist(bk + 1).join(' '));
      if (b != null) return OpenBookIntent(b);
    }
    // «خلي اللغة إنجليزي» / "switch to English" / «поменяй язык на русский»
    if (changing || words.any(_langWord.contains)) {
      for (final e in lex.languageNames.entries) {
        if (_hasPhrase(clean, e.value.map(_canon))) {
          return SetLanguageIntent(e.key);
        }
      }
    }
    // «خلي التطبيق ليلي» / "dark mode" / «modo oscuro»
    if (changing || words.any(_themeWord.contains)) {
      String? best;
      var bestLen = 0;
      for (final e in lex.themeValueWords.entries) {
        for (final p in e.value.map(_canon)) {
          if (p.length > bestLen && _hasPhrase(clean, [p])) {
            best = e.key;
            bestLen = p.length;
          }
        }
      }
      if (best != null) return SetThemeIntent(best);
    }
    // «اقفل التأثيرات الحركية» / "turn off animations"
    for (final e in _options.entries) {
      if (_hasPhrase(clean, e.value)) {
        final off = said.any(_off.contains);
        final on = said.any(_on.contains);
        if (off || on) return ToggleOptionIntent(e.key, on: !off);
        return const OpenScreenIntent(AssistantScreen.settings);
      }
    }
    // «شغل سورة الكهف بصوت المنشاوي» / "play surah Kahf by Alafasy"
    final surah = _surahIn(words, requireWord: !playing);
    if (surah != null) {
      // The surah's own words are not a reciter's name («آل عمران» is not
      // the reciter «عمران»).
      final sw = {for (final k in _surahKeys[surah - 1]) ...k.split(' ')};
      final rest = words.where((w) => !sw.contains(bare(w))).join(' ');
      return PlaySurahIntent(surah, reciterId: _reciterIn(rest));
    }
    // «آية بآية» names the ayah player even inside «مشغل التلاوة آية بآية».
    if (_hasPhrase(clean, _screens[AssistantScreen.ayahPlayer] ?? const [])) {
      return const OpenScreenIntent(AssistantScreen.ayahPlayer);
    }
    // A screen: the longest phrase that appears wins («مشغل التلاوه» beats
    // «التلاوه», «المكتبه الشامله» beats «المكتبه»). It opens on a command
    // («افتح …») or when the sentence is only its name. A question that
    // merely mentions one («ما حكم صلاة الجمعة») is not a command - the
    // assistant does not answer questions.
    final commanded = words.any(_open.contains) || playing || changing;
    AssistantScreen? best;
    var bestLen = 0;
    var bestWords = 0;
    for (final e in _screens.entries) {
      for (final p in e.value) {
        if (p.length > bestLen && _hasPhrase(clean, [p])) {
          best = e.key;
          bestLen = p.length;
          bestWords = p.split(' ').length;
        }
      }
    }
    // A settings section - by its title or anything named inside it -
    // opened WHERE IT IS rather than on the settings list («في اي خرم
    // ابرة», owner 2026-09-27).
    String? section;
    for (final e in _sections.entries) {
      for (final p in e.value) {
        if (p.length > bestLen && _hasPhrase(clean, [p])) {
          section = e.key;
          bestLen = p.length;
          bestWords = p.split(' ').length;
        }
      }
    }
    // Any other setting, by its title in any language: open the settings.
    for (final p in _settings) {
      if (p.length > bestLen && _hasPhrase(clean, [p])) {
        best = AssistantScreen.settings;
        section = null;
        bestLen = p.length;
        bestWords = p.split(' ').length;
      }
    }
    // Nothing matched whole: a section name of three words or more with
    // all but one of its words said. On emulator-5554 (2026-09-28) «افتح
    // ضبط المواقيت والتاريخ» came back as «فتحضط المواقيط والتاريخ» - the
    // verb swallowed «ضبط»; the other two words still name one section.
    if (section == null) {
      final said = {for (final w in words) bare(w)};
      // A screen matched on fewer words («المواقيت» alone) loses to it.
      var bestHits = best == null ? 0 : bestWords;
      for (final e in _sections.entries) {
        for (final p in e.value) {
          final pw = p.split(' ');
          if (pw.length < 3) continue;
          final hits = pw.where((w) => said.contains(bare(w))).length;
          if (hits == pw.length - 1 && hits > bestHits) {
            section = e.key;
            best = null;
            bestHits = hits;
            bestLen = p.length;
            bestWords = pw.length;
          }
        }
      }
    }
    // A section's name of three words or more is specific enough to allow
    // two stray words around it - «في تحلي» is how the recogniser broke
    // «افتحلي» on emulator-5554 (2026-09-28).
    final slack = bestWords >= 3 ? 2 : 1;
    if (section != null && (commanded || words.length <= bestWords + slack)) {
      return OpenSettingIntent(section);
    }
    if (best != null && (commanded || words.length <= bestWords + 1)) {
      return OpenScreenIntent(best);
    }
    return UnknownIntent(heard);
  }

  bool _hasPhrase(String clean, Iterable<String> phrases) {
    final padded = ' $clean ';
    final bareText = ' ${clean.split(' ').map(bare).join(' ')} ';
    // «لنهاري» / «بالعربي»: a one-letter preposition on a word said after a
    // verb («غير المظهر لنهاري»).
    final unPrefixed = ' ${clean.split(' ').map((w) => w.length > 3 && (w.startsWith('ل') || w.startsWith('ب')) ? bare(w.substring(1)) : bare(w)).join(' ')} ';
    for (final np in phrases) {
      if (np.isEmpty) continue;
      final nb = ' ${np.split(' ').map(bare).join(' ')} ';
      if (padded.contains(' $np ') ||
          bareText.contains(nb) ||
          unPrefixed.contains(nb)) {
        return true;
      }
    }
    return false;
  }

  /// A surah named in [words]: after «سورة»/"surah" anywhere, or (when a
  /// play verb was said) any surah name among the words. Longest name wins
  /// («آل عمران» over «عمران»).
  int? _surahIn(List<String> words, {required bool requireWord}) {
    final ws = words.map(bare).toList();
    final at = ws.indexWhere(_surahWord.contains);
    if (requireWord && at < 0) return null;
    final tail = ' ${ws.sublist(at >= 0 ? at + 1 : 0).join(' ')} ';
    int? best;
    var bestLen = 0;
    for (var i = 0; i < _surahKeys.length; i++) {
      for (final n in _surahKeys[i]) {
        if (n.length > bestLen && tail.contains(' $n ')) {
          best = i + 1;
          bestLen = n.length;
        }
      }
    }
    // «سورة ١٨» / «سوره رقم ١٨» / "surah number 18"
    if (best == null && at >= 0) {
      final m = RegExp(r'^ (?:\S+ )?(\d{1,3}) ').firstMatch(tail);
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
    for (var i = 0; i < lex.hijriMonthWords.length; i++) {
      for (final m in lex.hijriMonthWords[i].map(_canon)) {
        if (m.length > monthLen && _hasPhrase(clean, [m])) {
          month = i + 1;
          monthLen = m.length;
        }
      }
    }
    final d = RegExp(r'\b(\d{1,2})\b').firstMatch(clean);
    var day = int.tryParse(d?.group(1) ?? '');
    if (day == null) {
      // «اتناشر ربيع الأول»: the day said as a word, as recognisers write it.
      final ws = clean.split(' ');
      for (var i = 0; i < ws.length && day == null; i++) {
        final n = _numberWords[ws[i]];
        if (n == null) continue;
        // «واحد وعشرين» / «خمسه و عشرين»
        final next = i + 1 < ws.length ? ws[i + 1] : '';
        final tens = _numberWords[next.startsWith('و') ? next.substring(1) : ''] ??
            (next == 'و' && i + 2 < ws.length ? _numberWords[ws[i + 2]] : null);
        day = n < 10 && (tens == 20 || tens == 30) ? n + tens! : n;
      }
    }
    return OnThisDayIntent(
      day: day != null && day >= 1 && day <= 30 ? day : null,
      month: month,
    );
  }
}
