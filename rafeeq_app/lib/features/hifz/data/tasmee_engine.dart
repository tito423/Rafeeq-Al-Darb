/// «التسميع»: listening to a recitation and saying which words were missed.
///
/// The recogniser is a Whisper fine-tuned on Qur'an recitation
/// (`tarteel-ai/whisper-base-ar-quran`, Apache-2.0), exported for
/// sherpa-onnx by `scripts/export_quran_asr_onnx.py` and hosted on the
/// content bucket. It runs **on the device, offline**, once downloaded.
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

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';  // Float32List, @visibleForTesting
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../core/config/app_config.dart';

/// One file of the recogniser: where it lives on the bucket, and the exact
/// number of bytes it must be once downloaded (a truncated model loads and
/// then hears nothing).
class TasmeeAsset {
  final String name;
  final int bytes;
  const TasmeeAsset(this.name, this.bytes);

  String get url => '${AppConfig.contentBaseUrl}/asr/whisper-base-ar-quran/$name';
}

/// Measured with a HEAD against the bucket on 2026-09-23.
const tasmeeAssets = <TasmeeAsset>[
  TasmeeAsset('encoder.int8.onnx', 29104812),
  TasmeeAsset('decoder.int8.onnx', 130659024),
  TasmeeAsset('tokens.txt', 866987),
];

int get tasmeeDownloadBytes =>
    tasmeeAssets.fold(0, (sum, a) => sum + a.bytes);

/// Whisper's window. Anything longer has to be recited in pieces.
const tasmeeMaxSeconds = 30;

class TasmeeResult {
  /// The ayah's words, in order, each with whether it was heard.
  final List<bool> heardWord;
  final List<String> saidWords;
  final int matched;

  const TasmeeResult({
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

  sherpa.OfflineRecognizer? _recognizer;
  Directory? _dir;

  Future<Directory> _modelDir() async {
    final base = await getApplicationDocumentsDirectory();
    return _dir ??= Directory(p.join(base.path, 'asr', 'whisper-base-ar-quran'));
  }

  /// True when every file is present at exactly its expected size.
  Future<bool> isInstalled() async {
    final dir = await _modelDir();
    for (final a in tasmeeAssets) {
      final f = File(p.join(dir.path, a.name));
      if (!f.existsSync() || await f.length() != a.bytes) return false;
    }
    return true;
  }

  /// Downloads the three files, verifying each one's size before it counts as
  /// installed. [onProgress] gets 0..1 over the whole set.
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
      final path = p.join(dir.path, a.name);
      final f = File(path);
      if (f.existsSync() && await f.length() == a.bytes) {
        done += a.bytes;
        onProgress?.call(done / total);
        continue;
      }
      final tmp = '$path.part';
      await dio.download(
        a.url,
        tmp,
        cancelToken: cancelToken,
        onReceiveProgress: (got, _) => onProgress?.call((done + got) / total),
      );
      final got = await File(tmp).length();
      if (got != a.bytes) {
        await File(tmp).delete();
        throw StateError('${a.name} came back $got bytes, expected ${a.bytes}');
      }
      await File(tmp).rename(path);
      done += a.bytes;
      onProgress?.call(done / total);
    }
  }

  Future<void> deleteModel() async {
    _recognizer?.free();
    _recognizer = null;
    final dir = await _modelDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Loads the recogniser (once). Throws if the model is not installed.
  Future<void> _ensureLoaded() async {
    if (_recognizer != null) return;
    if (!await isInstalled()) {
      throw StateError('the recogniser is not downloaded yet');
    }
    sherpa.initBindings();
    final dir = await _modelDir();
    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: p.join(dir.path, 'encoder.int8.onnx'),
          decoder: p.join(dir.path, 'decoder.int8.onnx'),
          language: 'ar',
          task: 'transcribe',
        ),
        tokens: p.join(dir.path, 'tokens.txt'),
        numThreads: 2,
        modelType: 'whisper',
      ),
    );
    _recognizer = sherpa.OfflineRecognizer(config);
  }

  /// Transcribes [samples] (16 kHz mono float32 in [-1, 1]).
  Future<String> transcribe(Float32List samples) async {
    await _ensureLoaded();
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    _recognizer!.decode(stream);
    final text = _recognizer!.getResult(stream).text;
    stream.free();
    return text;
  }

  /// Compares what was heard with the ayah, word by word.
  ///
  /// The comparison is the one the desktop measurement used: marks stripped,
  /// alif/ya/ta-marbuta folded, and a word counted as said when its
  /// SKELETON matches — because the Uthmani script writes «السموت» where the
  /// recogniser returns «السماوات», and for «did you say this word» those
  /// are the same word.
  static TasmeeResult compare({
    required String ayahText,
    required String heard,
  }) {
    final expected = tasmeeWords(ayahText);
    final said = tasmeeWords(heard);
    final flags = List<bool>.filled(expected.length, false);
    var i = 0, j = 0, matched = 0;
    while (i < expected.length && j < said.length) {
      if (_skeleton(expected[i]) == _skeleton(said[j])) {
        flags[i] = true;
        matched++;
        i++;
        j++;
      } else if (j + 1 < said.length &&
          _skeleton(expected[i]) == _skeleton(said[j + 1])) {
        j++; // an extra word was heard
      } else if (i + 1 < expected.length &&
          _skeleton(expected[i + 1]) == _skeleton(said[j])) {
        i++; // a word was skipped
      } else {
        i++;
        j++;
      }
    }
    return TasmeeResult(heardWord: flags, saidWords: said, matched: matched);
  }
}

final _marks = RegExp('[ً-ٰٟۖ-ۭـ]');
final _notArabic = RegExp('[^ء-ي\\s]');

/// The ayah's words, normalised for comparison only — the ayah itself is
/// never rewritten (§1.2).
List<String> tasmeeWords(String text) {
  var t = text.replaceAll('ٱ', 'ا'); // alif wasla is a letter
  t = t.replaceAll(_marks, '');
  t = t.replaceAll(_notArabic, ' ');
  const folds = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي',
  };
  folds.forEach((a, b) => t = t.replaceAll(a, b));
  return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
}

String _skeleton(String w) => w.replaceAll(RegExp('[اوي]'), '');

@visibleForTesting
String tasmeeSkeleton(String w) => _skeleton(w);
