/// «التسميع»: listening to a recitation and saying which words were missed.
///
/// THE RECOGNISER (since 2026-09-30): NVIDIA's Arabic FastConformer CTC,
/// int8, through sherpa-onnx - the same file as Rafeeq's «دقة أعلى في
/// العربية» pack (`RafeeqVoicePack.accurate`), so it is downloaded once for
/// both. It runs **on the device, offline**.
///
/// WHY IT REPLACED tarteel whisper-tiny-ar-quran (whisper.cpp), measured on
/// the same 750 words, six reciters (scripts/asr_candidates_2026-09-30.txt,
/// fc_band_cause_2026-09-30.txt):
///
///  * clean recordings: tiny 89.3 %, FastConformer 91.3 %, and 97.5 % after
///    the 3.4 kHz low-pass `tasmee_audio.dart` applies (al-Minshawi 79 -> 98,
///    as-Sudais 81 -> 98);
///  * through a phone / Bluetooth-headset band: tiny 84.9 %, FastConformer
///    97.1 %; al-Banna's 2:255 on that band: tiny 3/50, FastConformer 48/50 -
///    the owner's «ميكروفون السماعة» case;
///  * 6 times faster (0.025 s per second of audio against 0.156 on the PC);
///  * a recitation stopped half-way and the wrong ayah still show up as a
///    plain drop in matched words (9/50, 1/11, 1/50), as with tiny.
///
///  * **tajweed is not checked.** A wrong madd or a missed ghunnah is not a
///    wrong WORD, and nothing here would catch it. The screen must say so.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart'; // Float32List, @visibleForTesting
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../../assistant/data/rafeeq_voice_pack.dart';
import 'tasmee_audio.dart';

/// What the recogniser costs to download: the Arabic FastConformer pack.
int get tasmeeDownloadBytes => RafeeqVoicePack.accurate.totalBytes;

/// How long one recitation may run - a cap, so a forgotten «stop» does not
/// fill the disk. Al-Baqarah 255 runs 60 s (48/50 words on the headset band).
const tasmeeMaxSeconds = 120;

class TasmeeResult {
  /// The ayah's own words, in order — what the panel prints back.
  final List<String> words;

  /// One flag per word of [words]: was it heard?
  final List<bool> heardWord;
  final List<String> saidWords;
  final int matched;

  const TasmeeResult({
    required this.words,
    required this.heardWord,
    required this.saidWords,
    required this.matched,
  });

  int get total => heardWord.length;
  double get ratio => total == 0 ? 0 : matched / total;
}

class TasmeeEngine {
  TasmeeEngine._();
  static final TasmeeEngine instance = TasmeeEngine._();

  final _pack = RafeeqVoicePack.accurate;

  /// The pack's own progress and state, so every button that offers the
  /// recogniser - here, the onboarding, the downloads panel, Rafeeq's
  /// settings - shows the same download.
  ValueNotifier<double?> get downloadProgress => _pack.progress;
  ValueNotifier<bool?> get installed => _pack.installed;

  Future<bool> isInstalled() async {
    final ok = await _pack.check();
    if (ok) unawaited(_dropOldWhisperModel());
    return ok;
  }

  /// The 78 MB whisper-tiny model an older version downloaded is no longer
  /// read; it is taken off the phone.
  Future<void> _dropOldWhisperModel() async {
    try {
      final base = await getApplicationSupportDirectory();
      final old = Directory(p.join(base.path, 'asr'));
      if (old.existsSync()) await old.delete(recursive: true);
    } catch (_) {}
  }

  /// Starts the download, or joins the one already running (the pack's own
  /// guard) - byte count and SHA-256 checked before it counts.
  Future<void> startDownload() => _pack.download();

  void cancelDownload() => _pack.cancel();

  /// Transcribes a 16 kHz mono WAV recorded from the microphone, on a worker
  /// isolate so no frame waits for it.
  Future<String> transcribeFile(String wavPath) async {
    if (!await isInstalled()) {
      throw StateError('the recogniser is not downloaded yet');
    }
    final dir = (await _pack.dir()).path;
    return Isolate.run(() => _decode(wavPath, dir));
  }

  // ---- live following -------------------------------------------------
  //
  // While the reader recites, the WAV file the recorder is writing is read
  // from its tail every second or so and decoded by ONE long-lived worker
  // isolate that keeps the recogniser loaded (building it per call costs more
  // than decoding). The final score is still computed from the whole file
  // after «stop»; this only lets the words light up while he recites.

  Isolate? _liveIso;
  SendPort? _liveSend;
  ReceivePort? _liveRecv;
  Completer<String>? _liveWait;

  Future<void> startLive() async {
    if (_liveIso != null) return;
    if (!await isInstalled()) return;
    final dir = (await _pack.dir()).path;
    final recv = ReceivePort();
    final ready = Completer<SendPort>();
    recv.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is String) {
        _liveWait?.complete(m);
        _liveWait = null;
      }
    });
    _liveRecv = recv;
    _liveIso = await Isolate.spawn(_liveMain, (recv.sendPort, dir));
    _liveSend = await ready.future;
  }

  /// Text heard in the last [seconds] of the growing WAV at [wavPath]; null
  /// when a previous request is still running (the caller skips the tick).
  Future<String?> liveTail(String wavPath, {int seconds = 10}) async {
    final send = _liveSend;
    if (send == null || _liveWait != null) return null;
    final c = _liveWait = Completer<String>();
    send.send((wavPath, seconds));
    return c.future;
  }

  void stopLive() {
    _liveIso?.kill(priority: Isolate.immediate);
    _liveIso = null;
    _liveSend = null;
    _liveRecv?.close();
    _liveRecv = null;
    if (_liveWait?.isCompleted == false) _liveWait!.complete('');
    _liveWait = null;
  }

  static void _liveMain((SendPort, String) a) {
    so.initBindings();
    final rp = ReceivePort();
    a.$1.send(rp.sendPort);
    final rec = so.OfflineRecognizer(so.OfflineRecognizerConfig(
      model: so.OfflineModelConfig(
        nemoCtc: so.OfflineNemoEncDecCtcModelConfig(
            model: p.join(a.$2, 'model.int8.onnx')),
        tokens: p.join(a.$2, 'tokens.txt'),
        numThreads: 2,
        debug: false,
      ),
    ));
    rp.listen((m) {
      final (path, seconds) = m as (String, int);
      var text = '';
      try {
        text = _decodeTail(rec, path, seconds);
      } catch (_) {}
      a.$1.send(text);
    });
  }

  /// The PCM after the header, cut to the last [seconds]; a half-written
  /// sample at the end is ignored.
  static String _decodeTail(so.OfflineRecognizer rec, String path, int seconds) {
    final f = File(path);
    final len = f.lengthSync();
    if (len < 44 + 16000) return ''; // under half a second
    final want = seconds * 32000;
    final from = len - 44 > want ? 44 + ((len - 44 - want) ~/ 2) * 2 : 44;
    final raf = f.openSync();
    final Uint8List bytes;
    try {
      raf.setPositionSync(from);
      bytes = raf.readSync(len - from);
    } finally {
      raf.closeSync();
    }
    final n = bytes.length ~/ 2;
    final bd = ByteData.sublistView(bytes);
    final x = Float32List(n);
    for (var i = 0; i < n; i++) {
      x[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    final y = lowPass3400(x);
    final padded = Float32List(y.length + 12000)..setAll(4000, y);
    final s = rec.createStream();
    try {
      s.acceptWaveform(samples: padded, sampleRate: 16000);
      rec.decode(s);
      return rec.getResult(s).text;
    } finally {
      s.free();
    }
  }

  static String _decode(String wavPath, String dir) {
    so.initBindings();
    final x = lowPass3400(wavSamples(File(wavPath).readAsBytesSync()));
    // A quarter second of silence either side, as the measurement fed it.
    final padded = Float32List(x.length + 12000)..setAll(4000, x);
    final rec = so.OfflineRecognizer(so.OfflineRecognizerConfig(
      model: so.OfflineModelConfig(
        nemoCtc: so.OfflineNemoEncDecCtcModelConfig(
            model: p.join(dir, 'model.int8.onnx')),
        tokens: p.join(dir, 'tokens.txt'),
        numThreads: 2,
        debug: false,
      ),
    ));
    final s = rec.createStream();
    try {
      s.acceptWaveform(samples: padded, sampleRate: 16000);
      rec.decode(s);
      return rec.getResult(s).text;
    } finally {
      s.free();
      rec.free();
    }
  }

  /// Live marking: [flags] (one per ayah word, never turned off) gains the
  /// words found in [heard], the text of the last seconds. Only the words from
  /// a little before the last one already heard are compared, so what has
  /// scrolled out of the window cannot be marked missed or re-matched to
  /// something later. Returns the number of words heard so far.
  static int liveMerge({
    required String ayahText,
    required String heard,
    required List<bool> flags,
    int surahId = 0,
    int ayahNumber = 0,
  }) {
    final expected = tasmeeWords(ayahText);
    if (flags.length != expected.length) return 0;
    final last = flags.lastIndexOf(true);
    final start = last < 0 ? 0 : (last - 3 < 0 ? 0 : last - 3);
    final said = tasmeeWords(heard);
    if (said.isEmpty) return flags.where((f) => f).length;
    final letters = start == 0 && expected.isNotEmpty
        ? _asRecited(expected[0], surahId, ayahNumber)
        : null;
    final (got, _) = _align(
      [for (final w in expected.sublist(start)) _fold(w)],
      [for (final w in said) _fold(w)],
      letterNames: letters?.split(' ').map(_fold).toList(),
    );
    for (var i = 0; i < got.length; i++) {
      if (got[i]) flags[start + i] = true;
    }
    return flags.where((f) => f).length;
  }

  /// Compares what was heard with the ayah, word by word.
  ///
  /// Words are aligned in order (a skipped word and an extra word both cost
  /// nothing but the word itself), and an ayah word counts as said when it
  /// is CLOSE ENOUGH to one heard word, or to two or three heard words run
  /// together — because the recogniser splits and misspells:
  ///
  ///  * «إذ نادى ربه نداء خفيا» came back from the owner's phone as
  ///    «إذن دعوا به ندى أن خفية», and «ذكر رحمت» as «زيك رون حمتي». The old
  ///    comparison wanted the skeletons EQUAL and scored those 0 of 5 and 3
  ///    of 5 while he had recited them correctly (2026-09-23).
  ///  * Closeness is a weighted letter overlap (consonants count double —
  ///    they carry a word, long vowels are what the model most often gets
  ///    wrong) with ذ/ز, ث/س, ظ/ض folded, as a speaker and the model both
  ///    confuse them. The threshold is what still rejects another ayah: the
  ///    tests pin that too.
  ///
  /// [surahId]/[ayahNumber] let the opening letters (كهيعص, الم…) be compared
  /// as they are RECITED — «كاف ها يا عين صاد» — and only where they really
  /// are those letters: «ألم» opens al-Fil and is a word, not letters.
  static TasmeeResult compare({
    required String ayahText,
    required String heard,
    int surahId = 0,
    int ayahNumber = 0,
  }) {
    final expected = tasmeeWords(ayahText);
    final said = tasmeeWords(heard);
    final letters = expected.isEmpty
        ? null
        : _asRecited(expected[0], surahId, ayahNumber);
    final (flags, matched) = _align(
      [for (final w in expected) _fold(w)],
      [for (final w in said) _fold(w)],
      letterNames: letters?.split(' ').map(_fold).toList(),
    );
    return TasmeeResult(
      words: expected,
      heardWord: flags,
      saidWords: said,
      matched: matched,
    );
  }
}

/// The in-order alignment behind [TasmeeEngine.compare]: most words matched,
/// ties broken by total closeness. When [letterNames] is given, e[0] is a
/// surah's opening letters and counts as said when enough of their NAMES
/// were heard, each name compared as a word of its own.
(List<bool>, int) _align(
  List<String> e,
  List<String> h, {
  List<String>? letterNames,
}) {
  final n = e.length, m = h.length;
  final cnt = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  final sum = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
  final how = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  bool better(int c, double s, int i, int j) =>
      c > cnt[i][j] || (c == cnt[i][j] && s > sum[i][j] + 1e-9);
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      if (i == 0 && j == 0) continue;
      cnt[i][j] = -1;
      if (i > 0 && better(cnt[i - 1][j], sum[i - 1][j], i, j)) {
        cnt[i][j] = cnt[i - 1][j];
        sum[i][j] = sum[i - 1][j];
        how[i][j] = -1; // expected word i-1 not said
      }
      if (j > 0 && better(cnt[i][j - 1], sum[i][j - 1], i, j)) {
        cnt[i][j] = cnt[i][j - 1];
        sum[i][j] = sum[i][j - 1];
        how[i][j] = -2; // heard word j-1 is extra
      }
      if (i == 0) continue;
      final names = i == 1 ? letterNames : null;
      final maxK = names != null ? names.length + 1 : 3;
      for (var k = 1; k <= maxK && k <= j; k++) {
        final double sim;
        if (names != null) {
          // «كاف ها يا عين صاد»: at least 40% of the names, so two of five
          // (what the phone heard as «كيف حيث صد») — but «ألم» said as a
          // word is one name of three, and is not al-Baqarah's letters.
          final got = _align(names, h.sublist(j - k, j)).$2;
          sim = got >= (names.length * 0.4).ceil() ? got / names.length : 0;
          if (sim == 0) continue;
        } else {
          sim = _closeness(e[i - 1], h.sublist(j - k, j).join());
          if (sim < _threshold) continue;
        }
        final c = cnt[i - 1][j - k] + 1, s = sum[i - 1][j - k] + sim;
        if (better(c, s, i, j)) {
          cnt[i][j] = c;
          sum[i][j] = s;
          how[i][j] = k;
        }
      }
    }
  }
  final flags = List<bool>.filled(n, false);
  var i = n, j = m;
  while (i > 0 || j > 0) {
    final k = how[i][j];
    if (k == -1) {
      i--;
    } else if (k == -2) {
      j--;
    } else {
      flags[i - 1] = true;
      i--;
      j -= k;
    }
  }
  return (flags, n == 0 ? 0 : cnt[n][m]);
}

/// How close a heard word must be to count. 0.7 accepts «به» for «ربه»
/// (0.8), «ندى» for «نداء» (0.8) and «زيك» for «ذكر» (0.73), and rejects
/// «ربك» for «ربه» (0.67). At 0.6 that pair passed, and so would any two
/// words sharing a root's worth of letters — `tasmee_compare_test.dart`.
const double _threshold = 0.7;

/// The surahs that open with separate letters, by the letters' recited names
/// (Hafs). Keyed by surah; 42:2 «عسق» is the one set in a second verse.
const Map<int, String> _openingLetters = {
  2: 'الف لام ميم',
  3: 'الف لام ميم',
  7: 'الف لام ميم صاد',
  10: 'الف لام را',
  11: 'الف لام را',
  12: 'الف لام را',
  13: 'الف لام ميم را',
  14: 'الف لام را',
  15: 'الف لام را',
  19: 'كاف ها يا عين صاد',
  20: 'طا ها',
  26: 'طا سين ميم',
  27: 'طا سين',
  28: 'طا سين ميم',
  29: 'الف لام ميم',
  30: 'الف لام ميم',
  31: 'الف لام ميم',
  32: 'الف لام ميم',
  36: 'يا سين',
  38: 'صاد',
  40: 'حا ميم',
  41: 'حا ميم',
  42: 'حا ميم',
  43: 'حا ميم',
  44: 'حا ميم',
  45: 'حا ميم',
  46: 'حا ميم',
  50: 'قاف',
  68: 'نون',
};

String? _asRecited(String firstWord, int surahId, int ayahNumber) {
  if (surahId == 42 && ayahNumber == 2) return 'عين سين قاف';
  if (ayahNumber != 1) return null;
  final names = _openingLetters[surahId];
  if (names == null) return null;
  // Only when the first word IS the letters (it always is in Hafs; a
  // different text source must not get the substitution by accident).
  final letters = names.split(' ').map((n) => n[0]).join();
  return firstWord == letters ? names : null;
}

/// Letters as they are compared: hamza carriers already folded by
/// [tasmeeWords], the bare hamza dropped, and the pairs a reciter's accent
/// and the recogniser both swap folded together.
String _fold(String w) {
  const folds = {'ذ': 'ز', 'ث': 'س', 'ظ': 'ض', 'ء': '', ' ': ''};
  var t = w;
  folds.forEach((a, b) => t = t.replaceAll(a, b));
  return t;
}

int _weight(String c) => 'اوي'.contains(c) ? 1 : 2;

int _wsum(String w) {
  var s = 0;
  for (final c in w.split('')) {
    s += _weight(c);
  }
  return s;
}

/// Weighted letter overlap, 0..1: twice the weight of the longest common
/// subsequence over the two words' total weight. Equal skeletons score 1,
/// so «الكتب» and «الكتاب» are the same word here, as they always were.
double _closeness(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (_skeleton(a) == _skeleton(b)) return 1;
  final x = a.split(''), y = b.split('');
  var prev = List<int>.filled(y.length + 1, 0);
  for (var i = 1; i <= x.length; i++) {
    final cur = List<int>.filled(y.length + 1, 0);
    for (var j = 1; j <= y.length; j++) {
      cur[j] = x[i - 1] == y[j - 1]
          ? prev[j - 1] + _weight(x[i - 1])
          : (prev[j] > cur[j - 1] ? prev[j] : cur[j - 1]);
    }
    prev = cur;
  }
  return 2 * prev[y.length] / (_wsum(a) + _wsum(b));
}

@visibleForTesting
double tasmeeCloseness(String a, String b) => _closeness(_fold(a), _fold(b));

final _marks = RegExp('[ً-ٰٟۖ-ۭـ]');
final _notArabic = RegExp('[^ء-ي\\s]');

/// The ayah's words, normalised for comparison only — the ayah itself is
/// never rewritten (§1.2).
List<String> tasmeeWords(String text) {
  var t = text.replaceAll('ٱ', 'ا'); // alif wasla is a letter
  t = t.replaceAll(_marks, '');
  t = t.replaceAll(_notArabic, ' ');
  const folds = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ى': 'ي',
    'ة': 'ه',
    'ؤ': 'و',
    'ئ': 'ي',
  };
  folds.forEach((a, b) => t = t.replaceAll(a, b));
  return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}

String _skeleton(String w) => w.replaceAll(RegExp('[اوي]'), '');

@visibleForTesting
String tasmeeSkeleton(String w) => _skeleton(w);
