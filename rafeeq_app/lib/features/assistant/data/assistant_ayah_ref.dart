part of 'assistant_intent.dart';

/// Open the mushaf on a surah, at an ayah (1 when none was said).
///
/// Owner, 2026-09-29: «يا رفيق افتح التطبيق على القرآن سورة البقرة آية ٢٥٥»
/// opened nothing - every sentence with a surah in it was read as «play the
/// surah», so the recitation started from the surah's first ayah, in the
/// selected reciter's voice, in the background. «افتح» and «آية» now mean
/// what they say.
class OpenQuranAyahIntent extends AssistantIntent {
  const OpenQuranAyahIntent(this.surah, this.ayah,
      {this.numberPending = false, this.marked = false, this.card});
  final int surah;
  final int ayah;

  /// An ayah was asked for by number or name («آية ٢٥٥», «آية الكرسي»):
  /// the mushaf marks it and brings it on screen (owner, 2026-09-30: «حتى لو
  /// الاية في اخر الصفحة ومش ظاهرة ع الشاشة انا عايزه يروح عليها ويظللها»).
  final bool marked;

  /// Its card opened on this tab: 0 tafsir, 1 translation, 2 i'rab
  /// («افتح تفسير آية الكرسي», «ترجمة الآية ٥ من البقرة»).
  final int? card;

  /// «… سورة البقرة آية» with the number not in this utterance: the
  /// recogniser closes a phrase at a breath, and on the owner's sentence
  /// (emulator, 2026-09-30) it cut right after «آي». The number said next
  /// moves the mushaf to it (assistant_sheet.dart, `_ayahPending`).
  final bool numberPending;
  @override
  String toString() => 'open quran $surah:$ayah'
      '${numberPending ? ' (number pending)' : ''}'
      '${marked ? ' marked' : ''}${card != null ? ' card $card' : ''}';
}

/// After «… سورة X آية» with the number cut off, the number said next
/// (within 12 s) moves the mushaf to that ayah.
class AyahFollowUp {
  (int, DateTime)? _pending;

  void arm(AssistantIntent intent) {
    _pending = intent is OpenQuranAyahIntent && intent.numberPending
        ? (intent.surah, DateTime.now().add(const Duration(seconds: 12)))
        : null;
    _card = intent is OpenQuranAyahIntent ? intent.card : null;
  }

  int? _card;

  /// The ayah to open when [heard] is that number; null otherwise.
  OpenQuranAyahIntent? take(String heard) {
    final p = _pending;
    if (p == null || DateTime.now().isAfter(p.$2)) return null;
    final n = spokenNumber(heard);
    if (n == null) return null;
    _pending = null;
    return OpenQuranAyahIntent(p.$1, n, marked: true, card: _card);
  }
}

/// Just a number, as a follow-up to [OpenQuranAyahIntent.numberPending]:
/// «مئتين وخمسة وخمسين», «٢٥٥», «الآية ٢٥٥».
int? spokenNumber(String heard) {
  final ws = [
    for (final w in norm(asciiDigits(heard)).split(' '))
      if (w.isNotEmpty && !_ayahWords.contains(w) && w != 'رقم') w,
  ];
  final n = _numberAt(ws);
  return n != null && n >= 1 && n <= 286 ? n : null;
}

/// Numbers as they are said (Egyptian and MSA), normalised: 1-20 and 30 for
/// days, dates and hadith numbers, plus the tens and hundreds an ayah number
/// needs (the longest surah has 286).
final _numberWords = <String, int>{
  for (final e in const {
    // Ordinals too, masculine and feminine («الآية السابعة»).
    1: ['واحد', 'وحده', 'الاول', 'اول', 'اولي'],
    2: ['اتنين', 'اثنين', 'اثنان', 'تاني', 'ثاني', 'تانيه', 'ثانيه'],
    3: ['تلاته', 'ثلاثه', 'تالت', 'ثالث', 'تالته', 'ثالثه'],
    4: ['اربعه', 'اربع', 'رابع', 'رابعه'],
    5: ['خمسه', 'خمس', 'خامس', 'خامسه'], 6: ['سته', 'ست', 'سادس', 'سادسه'],
    7: ['سبعه', 'سبع', 'سابع', 'سابعه'],
    8: ['تمانيه', 'ثمانيه', 'تامن', 'ثامن', 'تامنه', 'ثامنه'],
    9: ['تسعه', 'تسع', 'تاسع', 'تاسعه'], 10: ['عشره', 'عاشر', 'عاشره'],
    11: ['حداشر', 'احداشر', 'احدعشر'], 12: ['اتناشر', 'اتناش', 'اثناعشر', 'اطناشر'],
    13: ['تلتاشر', 'تلطاشر', 'ثلاثهعشر'], 14: ['اربعتاشر', 'اربعطاشر'],
    15: ['خمستاشر', 'خمسطاشر'], 16: ['ستاشر', 'سطاشر'],
    17: ['سبعتاشر', 'سبعطاشر'], 18: ['تمنتاشر', 'طمنطاشر'],
    19: ['تسعتاشر', 'تسعطاشر'], 20: ['عشرين', 'عشرون'],
    30: ['تلاتين', 'ثلاثين', 'ثلاثون'],
  }.entries)
    for (final w in e.value) norm(w): e.key,
};

final _bigNumberWords = <String, int>{
  for (final e in const {
    40: ['اربعين', 'اربعون'], 50: ['خمسين', 'خمسون'], 60: ['ستين', 'ستون'],
    70: ['سبعين', 'سبعون'], 80: ['تمانين', 'ثمانين', 'ثمانون'],
    90: ['تسعين', 'تسعون'],
    100: ['مئه', 'مائه', 'ميه', 'مايه', 'مية'],
    200: ['مئتين', 'مائتين', 'ميتين', 'متين', 'مئتان', 'مائتان'],
  }.entries)
    for (final w in e.value) norm(w): e.key,
};

/// «آية», as the recogniser and the seven languages write it.
final _ayahWords = _normSet(const [
  'آية', 'الآية', 'ايه', 'الايه', 'اية', 'آيه', 'آيت', 'ayah', 'aya', 'ayat',
  'verse', 'verset', 'versiculo', 'versículo', 'aleya', 'аят',
]);

/// «آي» - «آية» with its last letter lost when the phrase is cut; an ayah
/// word only at the END of what was heard.
final _ayahCut = norm('آي');

/// «افتح» glued to the next word by the recogniser: «افتحتطبيق» (heard on
/// the emulator, 2026-09-30, for «افتح التطبيق»).
bool _gluedOpen(String w) =>
    w.length > 5 && (w.startsWith('افتح') || w.startsWith('فتحل'));

/// «السبع» (the model wrote «آية السبع» for «آية سبعة», 2026-09-30):
/// a number word with the article is still that number.
int? _numberValue(String w) =>
    _numberWords[w] ??
    _bigNumberWords[w] ??
    (w.startsWith('ال') && w.length > 3
        ? _numberWords[w.substring(2)] ?? _bigNumberWords[w.substring(2)]
        : null);

/// «مئتين وخمسة وخمسين» -> 255, «255» -> 255; null when [ws] does not start
/// with a number.
int? _numberAt(List<String> ws) {
  if (ws.isEmpty) return null;
  final digits = int.tryParse(ws.first);
  if (digits != null) return digits;
  var total = 0;
  var any = false;
  for (var w in ws) {
    if (w == 'و') continue;
    if (w.startsWith('و') && _numberValue(w.substring(1)) != null) {
      w = w.substring(1);
    }
    final v = _numberValue(w);
    if (v == null) break;
    total += v;
    any = true;
  }
  return any ? total : null;
}

/// The ayah card's tab a word asks for (0 tafsir, 1 translation, 2 i'rab),
/// the card alone («كارت الآية») being its first tab.
int? _cardIn(List<String> words) {
  for (final w in words) {
    final b = bare(w);
    for (final e in _cardWords.entries) {
      if (e.value.contains(w) || e.value.contains(b)) return e.key;
    }
  }
  return null;
}

final _cardWords = <int, Set<String>>{
  for (final e in lex.ayahCardWords.entries) e.key: _normSet(e.value),
};

extension _AyahRef on AssistantParser {
  /// «افتح سورة البقرة آية ٢٥٥» -> open 2:255; «افتح سورة الكهف» -> open
  /// 18:1; «آية الكرسي» -> 2:255; «شغل البقرة من آية ٢٥٥» -> play from
  /// 2:255. Null when the sentence is not about an ayah or opening a surah,
  /// so the old «play the surah» reading still answers «شغل سورة الكهف».
  AssistantIntent? _ayahRef(List<String> words,
      {required bool playing, required bool memorizing, required bool sunan}) {
    if (memorizing || sunan) return null;
    var at = words.indexWhere(_ayahWords.contains);
    if (at < 0 && words.isNotEmpty && words.last == _ayahCut) {
      at = words.length - 1;
    }
    final card = _cardIn(words);
    // «الكرسيي» is how the model wrote it on the emulator; «الكورسي» is how
    // Egyptians say it.
    if (at >= 0 &&
        at + 1 < words.length &&
        RegExp(r'^كو?رسي*$').hasMatch(bare(words[at + 1]))) {
      return playing
          ? const PlaySurahIntent(2, fromAyah: 255)
          : OpenQuranAyahIntent(2, 255, marked: true, card: card);
    }
    final opening = card != null ||
        words.any((w) => AssistantParser._open.contains(w) || _gluedOpen(w));
    if (at < 0 && (playing || !opening)) return null;
    final n = at >= 0 ? _numberAt(words.sublist(at + 1)) : null;
    // Without «سورة», a surah name counts only beside an ayah NUMBER:
    // «مشغل التلاوة آية بآية لمحمد صديق» is the ayah player, not surah 47.
    final surah = _surahIn(words, requireWord: n == null);
    if (surah == null) return null;
    final ayah = n != null && n >= 1 ? n : 1;
    if (!playing) {
      return OpenQuranAyahIntent(surah, ayah,
          numberPending: at >= 0 && n == null,
          marked: n != null || card != null,
          card: card);
    }
    final sw = {for (final k in _surahKeys[surah - 1]) ...k.split(' ')};
    final rest = [
      for (final w in words)
        if (!sw.contains(bare(w)) && _numberValue(w) == null) w,
    ].join(' ');
    return PlaySurahIntent(surah, reciterId: _reciterIn(rest), fromAyah: ayah);
  }
}
