part of 'assistant_intent.dart';

/// Open the mushaf on a surah, at an ayah (1 when none was said).
///
/// Owner, 2026-09-29: «يا رفيق افتح التطبيق على القرآن سورة البقرة آية ٢٥٥»
/// opened nothing - every sentence with a surah in it was read as «play the
/// surah», so the recitation started from the surah's first ayah, in the
/// selected reciter's voice, in the background. «افتح» and «آية» now mean
/// what they say.
class OpenQuranAyahIntent extends AssistantIntent {
  const OpenQuranAyahIntent(this.surah, this.ayah);
  final int surah;
  final int ayah;
  @override
  String toString() => 'open quran $surah:$ayah';
}

/// Numbers as they are said (Egyptian and MSA), normalised: 1-20 and 30 for
/// days, dates and hadith numbers, plus the tens and hundreds an ayah number
/// needs (the longest surah has 286).
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

int? _numberValue(String w) => _numberWords[w] ?? _bigNumberWords[w];

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

extension _AyahRef on AssistantParser {
  /// «افتح سورة البقرة آية ٢٥٥» -> open 2:255; «افتح سورة الكهف» -> open
  /// 18:1; «آية الكرسي» -> 2:255; «شغل البقرة من آية ٢٥٥» -> play from
  /// 2:255. Null when the sentence is not about an ayah or opening a surah,
  /// so the old «play the surah» reading still answers «شغل سورة الكهف».
  AssistantIntent? _ayahRef(List<String> words,
      {required bool playing, required bool memorizing, required bool sunan}) {
    if (memorizing || sunan) return null;
    final at = words.indexWhere(_ayahWords.contains);
    if (at >= 0 && at + 1 < words.length && bare(words[at + 1]) == 'كرسي') {
      return playing
          ? const PlaySurahIntent(2, fromAyah: 255)
          : const OpenQuranAyahIntent(2, 255);
    }
    final opening = words.any(AssistantParser._open.contains);
    if (at < 0 && (playing || !opening)) return null;
    final n = at >= 0 ? _numberAt(words.sublist(at + 1)) : null;
    // Without «سورة», a surah name counts only beside an ayah NUMBER:
    // «مشغل التلاوة آية بآية لمحمد صديق» is the ayah player, not surah 47.
    final surah = _surahIn(words, requireWord: n == null);
    if (surah == null) return null;
    final ayah = n != null && n >= 1 ? n : 1;
    if (!playing) return OpenQuranAyahIntent(surah, ayah);
    final sw = {for (final k in _surahKeys[surah - 1]) ...k.split(' ')};
    final rest = [
      for (final w in words)
        if (!sw.contains(bare(w)) && _numberValue(w) == null) w,
    ].join(' ');
    return PlaySurahIntent(surah, reciterId: _reciterIn(rest), fromAyah: ayah);
  }
}
