/// «التسميع»: listening to a recitation and saying which words were missed.
///
/// The recogniser is a Whisper fine-tuned on Qur'an recitation
/// (`tarteel-ai/whisper-tiny-ar-quran`, Apache-2.0), converted to whisper.cpp's
/// ggml format by `scripts/export_quran_asr_onnx.py` and hosted on the content
/// bucket. It runs **on the device, offline**, once downloaded.
///
/// WHY whisper.cpp AND NOT sherpa-onnx (2026-09-23, found on the owner's
/// phone): sherpa ships its own onnxruntime, the app already ships another
/// for the book reading voice, and two ONNX Runtimes in one APK collide —
/// «cannot locate symbol OrtGetApiBase». whisper.cpp needs no onnxruntime,
/// and its ggml tiny model measured the SAME 95.9% as the base one at three
/// times the speed and half the size.
///
/// WHAT IT CAN AND CANNOT DO — measured on a desktop before any of this was
/// written (`scripts/measure_quran_asr.py`, and sherpa's own recognizer on
/// the exported model):
///
///  * ayahs under 30 s: 23/23 words, and it is not tied to one reciter
///    (Alafasy 11/11 and 49/50) nor broken by a narrow-band microphone;
///  * a skipped tail and a wrong ayah both show up as a plain drop in
///    matched words — 9/50 and 1/11;
///  * **an ayah longer than 30 s does not fit whisper's window**, so this
///    class refuses it rather than reporting half of it as «missed»;
///  * **tajweed is not checked.** A wrong madd or a missed ghunnah is not a
///    wrong WORD, and nothing here would catch it. The screen must say so.
library;

import '../../../core/config/content_mirrors.dart';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Float32List, @visibleForTesting
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../../core/config/app_config.dart';

/// One file of the recogniser: where it lives on the bucket, and the exact
/// number of bytes it must be once downloaded (a truncated model loads and
/// then hears nothing).
class TasmeeAsset {
  /// The object's name on the bucket.
  final String name;
  final int bytes;

  /// The name it must have on the device: whisper_flutter_new opens
  /// `<dir>/ggml-<model>.bin` and, when that file is missing, DOWNLOADS
  /// whisper.cpp's generic model from HuggingFace under that name, silently.
  final String localName;

  /// SHA-256 of the bucket object. The generic `ggml-tiny.bin` is
  /// 77,691,713 bytes too - HuggingFace's own size header says so - so the
  /// size alone cannot tell the two apart; this can (theirs is be07e048…).
  final String sha256;

  const TasmeeAsset(this.name, this.bytes, this.localName, this.sha256);

  String get url =>
      '${AppConfig.contentBaseUrl}/asr/whisper-tiny-ar-quran/$name';
}

/// Size measured with a HEAD, hash with sha256sum on the downloaded object,
/// both on 2026-09-23.
const tasmeeAssets = <TasmeeAsset>[
  TasmeeAsset(
    'ggml-model.bin',
    77691713,
    'ggml-tiny.bin',
    '5a9a479f9ec6b192ba6860801fca70b69f10b9f8a9b876422990562521bf7a11',
  ),
];

int get tasmeeDownloadBytes => tasmeeAssets.fold(0, (sum, a) => sum + a.bytes);

/// How long one recitation may run. whisper.cpp slides its own 30-second
/// window, so a longer ayah is handled — this is a cap on the recording, so a
/// forgotten «stop» does not fill the disk. Al-Baqarah 255 runs 60 s and
/// measured 47/50 words, which is why it is not 30.
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

  Whisper? _whisper;
  Directory? _dir;

  /// The model directory. whisper_flutter_new reads `ggml-tiny.bin` from
  /// here - see [TasmeeAsset.localName] for why that name matters.
  ///
  /// WHAT WENT WRONG UNTIL 2026-09-23: the model was saved as
  /// `ggml-model.bin`, the package did not find `ggml-tiny.bin`, and on the
  /// first recitation it fetched whisper.cpp's GENERIC tiny model from
  /// HuggingFace with no progress shown. The owner saw «ابدأ التسميع» hang;
  /// and every recitation on his phone had been heard by that generic model,
  /// not the Quran-tuned one that was measured and uploaded.
  Future<Directory> _modelDir() async {
    final base = await getApplicationSupportDirectory();
    return _dir ??= Directory(p.join(base.path, 'asr'));
  }

  /// Written beside the model once its hash has been checked, so the 78 MB
  /// are hashed once per install rather than on every screen.
  static const _verifiedSuffix = '.quran-verified';

  /// True only when OUR model sits where the package will read it. A file
  /// under that name that is not ours (the generic download) is deleted,
  /// and a copy of ours left under its old name is moved into place.
  Future<bool> isInstalled() async {
    final dir = await _modelDir();
    for (final a in tasmeeAssets) {
      final local = File(p.join(dir.path, a.localName));
      final marker = File('${local.path}$_verifiedSuffix');
      if (local.existsSync() &&
          marker.existsSync() &&
          marker.readAsStringSync().trim() == a.sha256 &&
          await local.length() == a.bytes) {
        continue;
      }
      // Installs before the fix: ours under the bucket's name, possibly
      // with the generic one beside it under the name that is read.
      final old = File(p.join(dir.path, a.name));
      if (old.existsSync() &&
          await old.length() == a.bytes &&
          await _sha256(old.path) == a.sha256) {
        if (local.existsSync()) await local.delete();
        await old.rename(local.path);
        await marker.writeAsString(a.sha256);
        continue;
      }
      if (local.existsSync() && await _sha256(local.path) == a.sha256) {
        await marker.writeAsString(a.sha256);
        continue;
      }
      if (local.existsSync()) await local.delete(); // not ours
      _whisper = null;
      installed.value = false;
      return false;
    }
    installed.value = true;
    return true;
  }

  static Future<String> _sha256(String path) => Isolate.run(() async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  });

  /// 0..1 while the model is downloading, null otherwise. Held HERE, not in
  /// a widget: the download used to live in the tasmee panel's state, so
  /// leaving the panel cancelled it and coming back showed «نزّل النموذج»
  /// again (owner, 2026-09-24). Every button that offers the model watches
  /// this and [installed].
  final ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  /// Last known install state; null until [isInstalled] has run once.
  final ValueNotifier<bool?> installed = ValueNotifier(null);

  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  Future<void>? _inFlight;

  /// Starts the download, or joins the one already running - so two
  /// buttons never start two transfers of the same 78 MB.
  Future<void> startDownload() => _inFlight ??= () async {
    _cancelToken = CancelToken();
    downloadProgress.value = 0;
    try {
      await download(
        dio: _dio,
        cancelToken: _cancelToken,
        onProgress: (v) => downloadProgress.value = v,
      );
      installed.value = true;
    } finally {
      downloadProgress.value = null;
      _cancelToken = null;
      _inFlight = null;
    }
  }();

  void cancelDownload() => _cancelToken?.cancel();

  /// Downloads the model, verifying its exact byte count and hash before it
  /// counts as installed. [onProgress] gets 0..1. UI goes through
  /// [startDownload]; this is the transfer itself.
  Future<void> download({
    required Dio dio,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _modelDir();
    await dir.create(recursive: true);
    final total = tasmeeDownloadBytes;
    var done = 0;
    for (final a in tasmeeAssets) {
      final path = p.join(dir.path, a.localName);
      final tmp = '$path.part';
      // R2, then its mirror; each must pass the byte count AND the hash.
      await ContentMirrors.fetchFirst<void>(a.url, (url) async {
        await dio.download(
          url,
          tmp,
          cancelToken: cancelToken,
          onReceiveProgress: (got, _) =>
              onProgress?.call((done + got) / total),
        );
        final got = await File(tmp).length();
        final hash = await _sha256(tmp);
        if (got != a.bytes || hash != a.sha256) {
          await File(tmp).delete();
          throw StateError(
            '${a.name} came back $got bytes with sha256 $hash; expected '
            '${a.bytes} bytes with sha256 ${a.sha256}',
          );
        }
      });
      if (File(path).existsSync()) await File(path).delete();
      await File(tmp).rename(path);
      await File('$path$_verifiedSuffix').writeAsString(a.sha256);
      done += a.bytes;
      onProgress?.call(done / total);
    }
    _whisper = null;
  }

  Future<void> deleteModel() async {
    _whisper = null;
    final dir = await _modelDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
    installed.value = false;
  }

  /// Transcribes a 16 kHz mono WAV file recorded from the microphone.
  ///
  /// Refuses unless [isInstalled] has seen our model where the package reads
  /// it: the package's own fallback is a silent download of another model.
  Future<String> transcribeFile(String wavPath) async {
    if (!await isInstalled()) {
      throw StateError('the recogniser is not downloaded yet');
    }
    final dir = await _modelDir();
    _whisper ??= Whisper(model: WhisperModel.tiny, modelDir: dir.path);
    final res = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        language: 'ar',
        threads: 4,
        isNoTimestamps: true,
        noFallback: true,
      ),
    );
    return res.text;
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
