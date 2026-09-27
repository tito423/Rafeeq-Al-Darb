import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// Does the device's Arabic voice actually READ the harakat we give it?
///
/// WHY THIS EXISTS BEFORE THE FEATURE DOES. The owner asked for a spoken
/// reader for the library and asked for it «متقن». The obstacle is measured,
/// not guessed: across a random sample of 24 books the median diacritisation
/// is **35.6%**, ten of them are under 20% (al-Muwafaqat 2.9%, Dhamm al-Dunya
/// 0.3%) and seven are over 60%. The corpus is bimodal — a book is either
/// nearly fully vowelled or nearly bare.
///
/// That matters because Arabic without harakat is genuinely ambiguous: the
/// same consonantal skeleton is several different words, and in a scholarly
/// religious text a wrong vowel is a wrong meaning, not a wrong accent.
///
/// So the whole feature rests on one question that nobody's documentation
/// answers: **if we hand a voice fully vowelled text, does it use the
/// vowels?** `flutter_tts` is only a wrapper over Android's `TextToSpeech`;
/// whether a given engine and voice honour combining marks is that voice's
/// behaviour, and Android promises nothing about it.
///
/// The test is empirical and needs no listener: synthesise MINIMAL PAIRS —
/// one consonantal skeleton, two different vowellings that are two different
/// words — to separate files, and compare the bytes. If the two files are
/// identical, the voice threw the harakat away, and every diacritisation
/// plan downstream of it is worthless. If they differ, the voice is reading
/// them, and the work has somewhere to go.
///
/// This is a probe, not a feature. Nothing in the app calls it; it is driven
/// from a test so the answer is recorded rather than remembered.
class TtsProbe {
  final FlutterTts _tts = FlutterTts();

  /// Minimal pairs: identical letters, different vowels, different words.
  ///
  /// Chosen so a failure is unmistakable rather than subtle — these are not
  /// shades of the same word, they are different words, and two of them are
  /// the kind of pair that changes the meaning of a sentence in fiqh prose.
  static const pairs = <String, List<String>>{
    // «he wrote» vs «books» — the classic skeleton.
    'ktb': ['كَتَبَ', 'كُتُبٌ'],
    // «knowledge» vs «flag/banner» vs «he taught» — same three letters.
    'alm': ['عِلْمٌ', 'عَلَمٌ'],
    // «he asked» vs «it was asked» — active against passive, which is the
    // difference between a man asking and a man being asked.
    'sal': ['سَأَلَ', 'سُئِلَ'],
    // «a man» nominative vs accusative — the case ending on its own.
    'rjl': ['رَجُلٌ', 'رَجُلًا'],
  };

  /// Synthesises every member of every pair to its own file.
  ///
  /// Returns a map of label -> file, or an empty map when the device has no
  /// Arabic voice at all, which is itself an answer worth recording.
  Future<Map<String, File>> synthesiseAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final out = <String, File>{};

    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(0.45);
    await _tts.awaitSynthCompletion(true);

    for (final entry in pairs.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        // WHERE THE OUTPUT ACTUALLY LANDS, which took two failed runs and
        // logcat to establish. flutter_tts's Android side does
        // `File(fileName)` — so the argument is a full path, not a name.
        // But Android's own TextToSpeech.synthesizeToFile then routes it
        // through the MediaStore under scoped storage, and the file appears
        // in /storage/emulated/0/Music with the path FLATTENED into the
        // display name:
        //
        //   D TTS: Successfully created file :
        //     /external/audio/media/138//data/user/0/<pkg>/app_flutter/ktb_0.wav
        //
        //   /storage/emulated/0/Music/_data_user_0_<pkg>_app_flutter_ktb_0.wav
        //
        // So the file requested is never at the path requested, and a
        // straight File(path).exists() is always false. The probe asks for
        // it under app_flutter and then goes and finds it where Android
        // actually put it.
        final label = '${entry.key}_$i';
        await _tts.synthesizeToFile(entry.value[i], '${dir.path}/$label.wav');
        final f = await _findOutput(label);
        if (f != null) out[label] = f;
      }
    }
    return out;
  }


  /// The newest MediaStore copy of a requested output, by its label.
  ///
  /// Matches on the label alone because Android both flattens the path into
  /// the name and appends « (1)», « (2)» on repeat runs — so the newest file
  /// whose name ends in `<label>.wav` or `<label> (n).wav` is this run's.
  Future<File?> _findOutput(String label) async {
    final music = Directory('/storage/emulated/0/Music');
    if (!await music.exists()) return null;
    final matches = <File>[];
    await for (final e in music.list()) {
      if (e is! File) continue;
      final name = e.path.split('/').last;
      if (!name.endsWith('.wav')) continue;
      final stem = name.substring(0, name.length - 4);
      final repeat = RegExp(r'\s\(\d+\)$');
      final base = repeat.hasMatch(stem)
          ? stem.substring(0, repeat.firstMatch(stem)!.start)
          : stem;
      if (base == label || base.endsWith('_$label')) {
        matches.add(e);
      }
    }
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final newest = matches.first;
    return await newest.length() > 0 ? newest : null;
  }

  /// Every Arabic voice the device offers, so the answer names the voice it
  /// is about rather than "Android".
  Future<List<Map<String, String>>> arabicVoices() async {
    final raw = await _tts.getVoices;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
        .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('ar'))
        .toList();
  }

  Future<List<String>> languages() async {
    final raw = await _tts.getLanguages;
    if (raw is! List) return const [];
    return raw.map((e) => '$e').where((e) => e.toLowerCase().startsWith('ar')).toList();
  }
}
