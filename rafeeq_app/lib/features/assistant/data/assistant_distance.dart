/// Edit distance where a long vowel (ا و ي) or ة/ه written or dropped
/// costs 0.5 - the Arabic model's commonest slip on a name is a lost vowel.
double vowelWeightedDistance(String a, String b) {
  const soft = {'ا', 'و', 'ي', 'ه'};
  double cost(String c) => soft.contains(c) ? 0.5 : 1;
  var prev = List<double>.filled(b.length + 1, 0);
  for (var j = 1; j <= b.length; j++) {
    prev[j] = prev[j - 1] + cost(b[j - 1]);
  }
  for (var i = 1; i <= a.length; i++) {
    final cur = List<double>.filled(b.length + 1, 0)
      ..[0] = prev[0] + cost(a[i - 1]);
    for (var j = 1; j <= b.length; j++) {
      final sub = a[i - 1] == b[j - 1] ? 0.0 : 1.0;
      cur[j] = [
        prev[j] + cost(a[i - 1]),
        cur[j - 1] + cost(b[j - 1]),
        prev[j - 1] + sub,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

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
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

/// After «سورة», a name the model misheard by a letter or two: «فطر»
/// (فاطر), «الطوبة» (التوبة), «المعون» (الماعون) - surah_audit.py, 2026-09-30.
/// The first word or two after it, against every surah key; the single
/// nearest within one edit (two from five letters) wins, a tie wins nothing.
/// A long vowel lost or added costs half ([vowelWeightedDistance]), so
/// «فطر» is فاطر and not فجر.
int? nearestSurah(List<Set<String>> keys, List<String> after) {
  final said = <String>{
    for (final w in after.take(2))
      if (w.isNotEmpty) ...[
        w,
        if (w.startsWith('ا') && w.length > 3) w.substring(1),
      ],
    if (after.length >= 2) '${after[0]} ${after[1]}',
  };
  int? best;
  var bestD = 99.0;
  var tie = false;
  for (var i = 0; i < keys.length; i++) {
    for (final k in keys[i]) {
      if (k.length < 3) continue;
      final max = k.length >= 5 ? 2 : 1;
      for (final w in said) {
        final d = vowelWeightedDistance(w, k);
        if (d > max) continue;
        if (d < bestD) {
          best = i + 1;
          bestD = d;
          tie = false;
        } else if (d == bestD && best != i + 1) {
          tie = true;
        }
      }
    }
  }
  return tie ? null : best;
}

/// A reciter's name word as the recogniser writes it. Seen on
/// emulator-5554 (2026-10-02): «بصوت الحصري» came back «الحصررى» - a
/// doubled letter - and the command was unknown. So a repeated letter is
/// collapsed, and a long word (6+ letters, family names) may be one edit
/// off; short words («محمد» / «احمد») must match exactly.
bool heardNameWord(String w, Set<String> said) {
  if (said.contains(w)) return true;
  final cw = _collapseRepeats(w);
  for (final s in said) {
    if (_collapseRepeats(s) == cw) return true;
    if (w.length >= 6 && s.length >= 5 && editDistance(w, s, 1) <= 1) return true;
  }
  return false;
}

String _collapseRepeats(String w) {
  final b = StringBuffer();
  for (var i = 0; i < w.length; i++) {
    if (i == 0 || w[i] != w[i - 1]) b.write(w[i]);
  }
  return b.toString();
}
