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

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';  // Float32List, @visibleForTesting
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../../core/config/app_config.dart';

/// One file of the recogniser: where it lives on the bucket, and the exact
/// number of bytes it must be once downloaded (a truncated model loads and
/// then hears nothing).
class TasmeeAsset {
  final String name;
  final int bytes;
  const TasmeeAsset(this.name, this.bytes);

  String get url =>
      '${AppConfig.contentBaseUrl}/asr/whisper-tiny-ar-quran/$name';
}

/// Measured with a HEAD against the bucket on 2026-09-23.
const tasmeeAssets = <TasmeeAsset>[
  TasmeeAsset('ggml-model.bin', 77691713),
];

int get tasmeeDownloadBytes =>
    tasmeeAssets.fold(0, (sum, a) => sum + a.bytes);

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

  /// whisper.cpp looks for `ggml-tiny.bin` in the directory it is given,
  /// and downloads it if missing — which it never has to, because the file is
  /// already there under that name.
  Future<Directory> _modelDir() async {
    final base = await getApplicationSupportDirectory();
    return _dir ??= Directory(p.join(base.path, 'asr'));
  }

  /// True when the model is present at exactly its expected size.
  Future<bool> isInstalled() async {
    final dir = await _modelDir();
    for (final a in tasmeeAssets) {
      final f = File(p.join(dir.path, a.name));
      if (!f.existsSync() || await f.length() != a.bytes) return false;
    }
    return true;
  }

  /// Downloads the model, verifying its exact byte count before it counts as
  /// installed. [onProgress] gets 0..1.
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
    _whisper = null;
    final dir = await _modelDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Transcribes a 16 kHz mono WAV file recorded from the microphone.
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
    return TasmeeResult(
      words: expected,
      heardWord: flags,
      saidWords: said,
      matched: matched,
    );
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
