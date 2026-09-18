/// Diacritised Arabic -> the token ids the open FastPitch voice was trained on.
///
/// A PORT, line for line, of `tts_arabic/text/phonetise_buckwalter.py` and
/// `tts_arabic/text/__init__.py` (nipponjo), itself adapted from Nawar
/// Halabi's Arabic-Phonetiser — licence CC BY-NC 4.0, credited on the Sources
/// screen. It was written from the Python, not copied from any Dart port.
///
/// It must reproduce the PYTHON'S BEHAVIOUR, not its intent: the model learned
/// from that behaviour. Two places where the two differ are kept as written:
///  * line 223's exclusion list is `emphatics + [u'r'""", u'l'"""]`, which
///    Python reads as ONE string, "r, u'l'" — so r and l are NOT excluded, and
///    [_resetsEmphasis] does not exclude them either;
///  * `vowel_map` folds the emphatic long vowels (AA, UU, II) into the plain
///    ones before tokenising, so tafkhim is not a token the model sees.
/// `test/arabic_phonetiser_test.dart` holds the port to the Python's own
/// output on real book sentences.
library;

const _ar2bw = <String, String>{
  'ب': 'b', 'ذ': '*', 'ط': 'T', 'م': 'm',
  'ت': 't', 'ر': 'r', 'ظ': 'Z', 'ن': 'n',
  'ث': '^', 'ز': 'z', 'ع': 'E', 'ه': 'h',
  'ج': 'j', 'س': 's', 'غ': 'g', 'ح': 'H',
  'ق': 'q', 'ف': 'f', 'خ': 'x', 'ص': 'S',
  'ش': r'$', 'د': 'd', 'ض': 'D', 'ك': 'k',
  'أ': '>', 'ء': "'", 'ئ': '}', 'ؤ': '&',
  'إ': '<', 'آ': '|', 'ا': 'A', 'ى': 'Y',
  'ة': 'p', 'ي': 'y', 'ل': 'l', 'و': 'w',
  'ً': 'F', 'ٌ': 'N', 'ٍ': 'K', 'َ': 'a',
  'ُ': 'u', 'ِ': 'i', 'ّ': '~', 'ْ': 'o',
};

String arabicToBuckwalter(String s) =>
    s.split('').map((c) => _ar2bw[c] ?? c).join();

const _unambiguous = <String, String>{
  'b': 'b', '*': '*', 'T': 'T', 'm': 'm', 't': 't', 'r': 'r', 'Z': 'Z',
  'n': 'n', '^': '^', 'z': 'z', 'E': 'E', 'h': 'h', 'j': 'j', 's': 's',
  'g': 'g', 'H': 'H', 'q': 'q', 'f': 'f', 'x': 'x', 'S': 'S', r'$': r'$',
  'd': 'd', 'D': 'D', 'k': 'k', '>': '<', "'": '<', '}': '<', '&': '<',
  '<': '<',
};

const _diacritics = ['o', 'a', 'u', 'i', 'F', 'N', 'K', '~'];
const _diacriticsNoShadda = ['o', 'a', 'u', 'i', 'F', 'N', 'K'];
const _emphatics = ['D', 'S', 'T', 'Z', 'g', 'x', 'q'];
const _forwardEmphatics = ['g', 'x'];
const _consonants = [
  '>', '<', '}', '&', "'", 'b', 't', '^', 'j', 'H', 'x', 'd', '*', 'r', //
  'z', 's', r'$', 'S', 'D', 'T', 'Z', 'E', 'g', 'f', 'q', 'k', 'l', 'm',
  'n', 'h', '|',
];
const _punctuation = ['.', ',', '?', '!'];

// vowelMap: [plain, emphatic] x [normal, shortened]; 'a' is flat.
const _vowelMap = <String, List<List<String>>>{
  'A': [['aa', ''], ['AA', '']],
  'Y': [['aa', ''], ['AA', '']],
  'w': [['uu0', 'uu1'], ['UU0', 'UU1']],
  'y': [['ii0', 'ii1'], ['II0', 'II1']],
  'u': [['u0', 'u1'], ['U0', 'U1']],
  'i': [['i0', 'i1'], ['I0', 'I1']],
};
const _vowelA = ['a', 'A'];
bool _inVowelMap(String c) => _vowelMap.containsKey(c) || c == 'a';

const _fixedWords = <String, List<String>>{
  'h*A': ['h aa * aa', 'h aa * a'],
  'h*h': ['h aa * i0 h i0', 'h aa * i1 h'],
  'h*An': ['h aa * aa n i0', 'h aa * aa n'],
  "h&lA'": ['h aa < u0 l aa < i0', 'h aa < u0 l aa <'],
  '*lk': ['* aa l i0 k a', '* aa l i0 k'],
  'k*lk': ['k a * aa l i0 k a', 'k a * aa l i1 k'],
  '*lkm': ['* aa l i0 k u1 m'],
  '>wl}k': ['< u0 l aa < i0 k a', '< u0 l aa < i1 k'],
  'Th': ['T aa h a'],
  'lkn': ['l aa k i0 nn a', 'l aa k i1 n'],
  'lknh': ['l aa k i0 nn a h u0'],
  'lknhm': ['l aa k i0 nn a h u1 m'],
  'lknk': ['l aa k i0 nn a k a', 'l aa k i0 nn a k i0'],
  'lknkm': ['l aa k i0 nn a k u1 m'],
  'lknkmA': ['l aa k i0 nn a k u0 m aa'],
  'lknnA': ['l aa k i0 nn a n aa'],
  'AlrHmn': ['rr a H m aa n i0', 'rr a H m aa n'],
  'Allh': ['ll aa h i0', 'll aa h', 'll AA h u0', 'll AA h a', 'll AA h', 'll A'],
  'h*yn': ['h aa * a y n i0', 'h aa * a y n'],
  'nt': ['n i1 t'],
  'fydyw': ['v i0 d y uu1'],
  'lndn': ['l A n d u1 n'],
};
// Entries that are a single string in the Python are matched unconditionally.
const _fixedSingle = {'*lkm', 'Th', 'lknh', 'lknhm', 'lknkm', 'lknkmA', 'lknnA', 'nt', 'fydyw', 'lndn'};

List<String>? _fixedWord(String word) {
  final consonantsOnly = word.replaceAll(RegExp(r"[^h*Ahn'>wl}kmyTtfd]"), '');
  final entry = _fixedWords[consonantsOnly];
  if (entry == null) return null;
  if (_fixedSingle.contains(consonantsOnly)) return entry.first.split(' ');
  // lastLetter: a list for the vowels, else a STRING tested with Python's
  // substring `in`.
  final last = word.isEmpty ? '' : word[word.length - 1];
  bool matches(String p) {
    final tail = p.split(' ').last;
    switch (last) {
      case 'a':
        return tail == 'a' || tail == 'A';
      case 'A':
        return tail == 'aa';
      case 'u':
        return tail == 'u0';
      case 'i':
        return tail == 'i0';
    }
    final mapped = _unambiguous[last];
    if (mapped != null) return tail == mapped;
    return last.contains(tail); // Python: `tail in lastLetter` on a str
  }

  for (final p in entry) {
    if (matches(p)) return p.split(' ');
  }
  return null;
}

List<String> _preprocess(String u) {
  u = u
      .replaceAll('AF', 'F')
      .replaceAll('ـ', '')
      .replaceAll('o', '')
      .replaceAll('aA', 'A')
      .replaceAll('aY', 'Y')
      .replaceAll(' A', ' ')
      .replaceAll('F', 'an')
      .replaceAll('N', 'un')
      .replaceAll('K', 'in')
      .replaceAll('|', '>A')
      .replaceAll('i~', '~i')
      .replaceAll('a~', '~a')
      .replaceAll('u~', '~u')
      .replaceAll('Ai', '<i')
      .replaceAll('Aa', '>a')
      .replaceAll('Au', '>u');
  u = u.replaceAllMapped(RegExp(r'^>([^auAw])'), (m) => '>a${m[1]}');
  u = u.replaceAllMapped(RegExp(r' >([^auAw ])'), (m) => ' >a${m[1]}');
  u = u.replaceAllMapped(RegExp(r'<([^i])'), (m) => '<i${m[1]}');
  u = u.replaceAllMapped(RegExp(r'(\S)(\.|\?|,|!)'), (m) => '${m[1]} ${m[2]}');
  return u.split(' ');
}

/// One word's pronunciation: `pronunciations[0]` of the Python.
List<String> _processWord(String raw) {
  if (_punctuation.contains(raw)) return [raw];
  final fixed = _fixedWord(raw);
  var emphatic = false;
  final w = 'bb${raw}ee';
  // Each entry is a String, or a List<String> of alternatives of which the
  // Python's first pronunciation always takes element 0.
  final phones = <Object>[];

  for (var idx = 2; idx < w.length - 2; idx++) {
    final l = w[idx], l1 = w[idx + 1], l2 = w[idx + 2];
    final lm1 = w[idx - 1], lm2 = w[idx - 2];

    if ((_consonants.contains(l) || l == 'w' || l == 'y') && !_emphatics.contains(l)) {
      emphatic = false;
    }
    if (_emphatics.contains(l)) emphatic = true;
    if (_emphatics.contains(l1) && !_forwardEmphatics.contains(l1)) emphatic = true;

    if (_unambiguous.containsKey(l)) phones.add(_unambiguous[l]!);

    if (l == 'l') {
      if (!_diacritics.contains(l1) && !_inVowelMap(l1) && l2 == '~') {
        phones.add('');
      } else {
        phones.add('l');
      }
    }
    if (l == '~' && lm1 != 'w' && lm1 != 'y' && phones.isNotEmpty) {
      final last = phones.removeLast();
      phones.add(last is String ? last + last : _doubleAlt(last as List<String>));
    }
    if (l == '|') {
      phones.add(emphatic ? ['<', 'AA'] : ['<', 'aa']);
    }
    if (l == 'p') phones.add(_diacritics.contains(l1) ? 't' : '');

    if (_inVowelMap(l)) {
      if (l == 'w' || l == 'y') {
        final vm = _vowelMap[l]!;
        if (_diacriticsNoShadda.contains(l1) || l1 == 'A' || l1 == 'Y' ||
            ((l1 == 'w' || l1 == 'y') && !(_diacritics.contains(l2) || l2 == 'A' || l2 == 'w' || l2 == 'y')) ||
            (_diacriticsNoShadda.contains(lm1) && (_consonants.contains(l1) || l1 == 'e'))) {
          if ((l == 'w' && lm1 == 'u' && !['a', 'i', 'A', 'Y'].contains(l1)) ||
              (l == 'y' && lm1 == 'i' && !['a', 'u', 'A', 'Y'].contains(l1))) {
            phones.add(emphatic ? vm[1][0] : vm[0][0]);
          } else {
            if (l1 == 'A' && l == 'w' && l2 == 'e') {
              phones.add([l, vm[0][0]]);
            } else {
              phones.add(l);
            }
          }
        } else if (l1 == '~') {
          if (lm1 == 'a' || (l == 'w' && (lm1 == 'i' || lm1 == 'y')) || (l == 'y' && (lm1 == 'w' || lm1 == 'u'))) {
            phones..add(l)..add(l);
          } else {
            phones..add(vm[0][0])..add(l);
          }
        } else {
          final v = emphatic ? vm[1][0] : vm[0][0];
          if ((_consonants.contains(lm1) || lm1 == 'u' || lm1 == 'i') && l1 == 'e') {
            phones.add([v, v.substring(1)]);
          } else {
            phones.add(v);
          }
        }
      }
      if (l == 'u' || l == 'i') {
        final vm = _vowelMap[l]!;
        final set = emphatic ? vm[1] : vm[0];
        final shorten = (_unambiguous.containsKey(l1) || l1 == 'l') && l2 == 'e' && w.length > 7;
        phones.add(shorten ? set[1] : set[0]);
      }
      if (l == 'a' || l == 'A' || l == 'Y') {
        if (l == 'A' && (lm1 == 'w' || lm1 == 'k') && lm2 == 'b') {
          phones.add(['a', _vowelMap[l]![0][0]]);
        } else if (l == 'A' && (lm1 == 'u' || lm1 == 'i')) {
          // nothing
        } else if (l == 'A' && lm1 == 'w' && l1 == 'e') {
          phones.add([_vowelMap[l]![0][0], _vowelMap[l]![0][1]]);
        } else if ((l == 'A' || l == 'Y') && l1 == 'e') {
          phones.add(emphatic
              ? [_vowelMap[l]![1][0], _vowelA[1]]
              : [_vowelMap[l]![0][0], _vowelA[0]]);
        } else if (l == 'a') {
          // vowelMap['a'][1][0] is 'A'[0], i.e. 'A'.
          phones.add(emphatic ? 'A' : 'a');
        } else {
          phones.add(emphatic ? _vowelMap[l]![1][0] : _vowelMap[l]![0][0]);
        }
      }
    }
  }

  var p = fixed ??
      [
        for (final ph in phones)
          if ((ph is String ? ph : (ph as List<String>).first) != '')
            ph is String ? ph : (ph as List<String>).first,
      ];
  p = List.of(p);
  var prev = '';
  final toDelete = <int>[];
  for (var i = 0; i < p.length; i++) {
    final letter = p[i];
    if (['aa', 'uu0', 'ii0', 'AA', 'UU0', 'II0'].contains(letter) &&
        prev.toLowerCase() == letter.substring(1).toLowerCase()) {
      toDelete.add(i - 1);
      p[i] = p[i - 1][0] + p[i - 1];
    }
    if ((letter == 'u0' || letter == 'i0') && prev.toLowerCase() == letter.toLowerCase()) {
      toDelete.add(i - 1);
      p[i] = p[i - 1];
    }
    if ((letter == 'y' || letter == 'w') && prev == letter) {
      p[i - 1] = p[i - 1] + p[i - 1];
      toDelete.add(i);
    }
    prev = letter;
  }
  for (final i in toDelete.reversed) {
    p.removeAt(i);
  }
  return p;
}

/// Python's `phones[-1] += phones[-1]` on an alternatives list doubles the
/// LIST, it does not double each alternative — `[a, b] + [a, b]`. Element 0
/// is unchanged, which is all the first pronunciation reads.
List<String> _doubleAlt(List<String> alt) => [...alt, ...alt];

/// `process_utterance` + `phonemes_to_tokens`, for diacritised Arabic.
List<String> arabicToTokens(String arabic, {bool appendSpace = true}) {
  final words = _preprocess(arabicToBuckwalter(arabic));
  final perWord = <List<String>>[];
  for (final w in words) {
    if (w == '-' || w == 'sil') {
      perWord.add(['sil']);
      continue;
    }
    final ph = _processWord(w);
    if (ph.length == 1 && _punctuation.contains(ph.first) && perWord.isNotEmpty) {
      perWord.last.add(ph.first);
    } else {
      perWord.add(ph);
    }
  }
  final seq = perWord.map((p) => p.join(' ')).join(' + ');
  final toks = seq.replaceAll('sil', '').replaceAll('+', '_+_').split(RegExp(r'\s+'))
    ..removeWhere((t) => t.isEmpty);
  final out = <String>[];
  for (final t in toks) {
    if (t.length == 2 && !_vowels.contains(t) && t[0] == t[1]) {
      out..add(t[0])..add('_dbl_');
    } else {
      out.add(_vowelFold[t] ?? t);
    }
  }
  if (appendSpace) out.add('_+_');
  out.add('_eos_');
  return out;
}

const _vowels = {
  'aa', 'AA', 'uu0', 'uu1', 'UU0', 'UU1', 'ii0', 'ii1', 'II0', 'II1', //
  'a', 'A', 'u0', 'u1', 'U0', 'U1', 'i0', 'i1', 'I0', 'I1',
};
const _vowelFold = {
  'aa': 'aa', 'AA': 'aa', 'uu0': 'uu', 'uu1': 'uu', 'UU0': 'uu', 'UU1': 'uu',
  'ii0': 'ii', 'ii1': 'ii', 'II0': 'ii', 'II1': 'ii', 'a': 'a', 'A': 'a',
  'u0': 'u', 'u1': 'u', 'U0': 'u', 'U1': 'u', 'i0': 'i', 'i1': 'i',
  'I0': 'i', 'I1': 'i',
};

/// `symbols.py`, in order: the index is the model's input id.
const ttsSymbols = [
  '_pad_', '_eos_', '_sil_', '_dbl_', '_+_', '.', ',', '?', '!', //
  '<', 'b', 't', '^', 'j', 'H', 'x', 'd', '*', 'r', 'z', 's', r'$', 'S', 'D',
  'T', 'Z', 'E', 'g', 'f', 'q', 'k', 'l', 'm', 'n', 'h', 'w', 'y', 'v',
  'a', 'u', 'i', 'aa', 'uu', 'ii',
];

List<int> tokensToIds(List<String> tokens) =>
    [for (final t in tokens) ttsSymbols.indexOf(t)];
