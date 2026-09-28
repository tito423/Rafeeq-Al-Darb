typedef WakeNormalizer = String Function(String text);
typedef WakeDistance = int Function(String a, String b, int max);

/// Returns what follows the assistant's name, or null when it was not called.
///
/// Recognition may split, join, or miss one letter in the wake word. The same
/// one-edit tolerance applies when the first command word is glued to it.
String? splitAfterWakeWord(
  String heard,
  Set<String> wakeWords, {
  required WakeNormalizer normalize,
  required WakeDistance distance,
}) {
  final words = normalize(heard).split(' ').where((x) => x.isNotEmpty).toList();

  bool isName(String word) {
    var candidate = word;
    if (candidate.startsWith('يا') && candidate.length > 4) {
      candidate = candidate.substring(2);
    }
    if (candidate.startsWith('ya') && candidate.length > 5) {
      candidate = candidate.substring(2);
    }
    if (candidate.startsWith('hey') && candidate.length > 6) {
      candidate = candidate.substring(3);
    }
    return wakeWords.any((name) => distance(candidate, name, 1) <= 1);
  }

  String? gluedRest(String word) {
    final candidate = word.startsWith('يا') ? word.substring(2) : word;
    for (final name in wakeWords) {
      for (final cut in [name.length - 1, name.length, name.length + 1]) {
        if (name.length < 4 || cut <= 0 || candidate.length - cut < 2) continue;
        if (distance(candidate.substring(0, cut), name, 1) <= 1) {
          return candidate.substring(cut);
        }
      }
    }
    return null;
  }

  for (var i = 0; i < words.length && i < 4; i++) {
    if (isName(words[i])) return words.sublist(i + 1).join(' ');
    final glued = gluedRest(words[i]);
    if (glued != null) return [glued, ...words.sublist(i + 1)].join(' ');
    if (i + 1 < words.length && isName(words[i] + words[i + 1])) {
      return words.sublist(i + 2).join(' ');
    }
  }
  return null;
}
