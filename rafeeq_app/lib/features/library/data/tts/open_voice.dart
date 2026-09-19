import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/app_config.dart';
import 'arabic_phonetiser.dart';

/// The open Arabic voice the owner chose (sample B) for its tafkhim of the
/// divine name: FastPitch -> Vocos (44.1 kHz), two ONNX files from
/// nipponjo/tts_arabic (Arabic Speech Corpus, male speaker 0), mirrored on R2
/// under `tts/open_ar_v1/` (~261 MB). Runs entirely on the device.
///
/// The pipeline is `tts_arabic/models/tts_models.py`'s, input for input:
///  * fp_ms.onnx: token_ids int64[1,N], pace f32[1], speaker i32[1],
///    pitch_mul f32[1], pitch_add f32[1] -> mel f32[1,80,T];
///  * vocos44.onnx: mel_spec f32[1,80,T], denoise f32[1] (0.005)
///    -> wave f32[1,S] at 44,100 Hz;
///  * then the peak is scaled to 0.9, as `tts(volume=0.9)` does.
class OpenVoice {
  OpenVoice._();
  static final OpenVoice instance = OpenVoice._();

  /// «التالت مقبول» (2026-09-19): of three vocoders heard on the same
  /// sentence, the owner chose Vocos at 44.1 kHz over the original HiFi-GAN
  /// (which he heard as shaky). Vocos takes the same mel and returns the wave
  /// directly - it has its own denoise input, so there is no third model.
  static const sampleRate = 44100;
  static const files = ['fp_ms.onnx', 'vocos44.onnx'];
  static const _sizes = {'fp_ms.onnx': 187215347, 'vocos44.onnx': 73485606};
  static const totalBytes = 187215347 + 73485606;

  /// The earlier vocoder's files, removed from devices that installed it.
  static const _retired = ['hifigan.onnx', 'denoiser.onnx'];

  OrtSession? _fp, _voc;

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'tts', 'open_ar_v1'));
  }

  static String urlFor(String name) =>
      '${AppConfig.contentBaseUrl}/tts/open_ar_v1/$name';

  /// All three files present at their full size.
  static Future<bool> isInstalled() async {
    final d = await _dir();
    for (final f in files) {
      final file = File(p.join(d.path, f));
      if (!file.existsSync() || file.lengthSync() != _sizes[f]) return false;
    }
    return true;
  }

  /// Downloads the pack, resuming nothing - a partial file is replaced.
  /// [onProgress] gets (bytesSoFar, totalBytes).
  static Future<void> install(void Function(int, int)? onProgress) {
    // One download at a time: a second tap while the first is running joins
    // it rather than writing the same .part files twice.
    final running = _installing;
    if (running != null) return running;
    return _installing = _install(onProgress).whenComplete(() => _installing = null);
  }

  static Future<void>? _installing;
  static HttpClient? _client;
  static bool _cancel = false;

  /// Whether the last install ended because the reader cancelled it.
  static bool get wasCancelled => _cancel;

  /// Stops a running download and removes what it wrote, so 252 MB started
  /// by mistake can be taken back. The pending [install] completes with a
  /// [StateError] ('cancelled').
  static Future<void> cancelInstall() async {
    _cancel = true;
    _client?.close(force: true);
    final d = await _dir();
    if (!d.existsSync()) return;
    for (final f in d.listSync().whereType<File>()) {
      if (f.path.endsWith('.part')) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  static Future<void> _install(void Function(int, int)? onProgress) async {
    final d = await _dir();
    d.createSync(recursive: true);
    var done = 0;
    _cancel = false;
    final client = HttpClient()..userAgent = 'RafeeqAlDarb (tts voice)';
    _client = client;
    try {
      for (final r in _retired) {
        final old = File(p.join(d.path, r));
        if (old.existsSync()) old.deleteSync();
      }
      for (final f in files) {
        final target = File(p.join(d.path, f));
        // A file already complete (fp_ms from the earlier pack) is kept:
        // moving to the new vocoder costs 73 MB, not 261.
        if (target.existsSync() && target.lengthSync() == _sizes[f]) {
          done += _sizes[f]!;
          onProgress?.call(done, totalBytes);
          continue;
        }
        final part = File('${target.path}.part');
        final req = await client.getUrl(Uri.parse(urlFor(f)));
        final res = await req.close();
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode} for $f');
        }
        final sink = part.openWrite();
        await for (final chunk in res) {
          if (_cancel) {
            await sink.close();
            if (part.existsSync()) part.deleteSync();
            throw StateError('cancelled');
          }
          sink.add(chunk);
          done += chunk.length;
          onProgress?.call(done, totalBytes);
        }
        await sink.close();
        if (target.existsSync()) target.deleteSync();
        part.renameSync(target.path);
      }
    } finally {
      client.close();
      _client = null;
    }
  }

  /// Bytes the pack occupies now, partial files included, for the
  /// Downloads hub.
  static Future<int> usageBytes() async {
    final d = await _dir();
    if (!d.existsSync()) return 0;
    var n = 0;
    for (final f in d.listSync().whereType<File>()) {
      n += f.lengthSync();
    }
    return n;
  }

  static Future<void> uninstall() async {
    await instance.release();
    final d = await _dir();
    if (d.existsSync()) d.deleteSync(recursive: true);
  }

  Future<void> _ensureLoaded() async {
    if (_fp != null) return;
    OrtEnv.instance.init();
    final d = await _dir();
    OrtSession open(String f) =>
        OrtSession.fromFile(File(p.join(d.path, f)), OrtSessionOptions());
    _fp = open('fp_ms.onnx');
    _voc = open('vocos44.onnx');
  }

  /// Loads the three models ahead of the first «استماع», so the wait is
  /// spent while the reader is reading rather than after they tap.
  Future<void> warmUp() async {
    if (_fp != null || !await isInstalled()) return;
    await _ensureLoaded();
  }

  Future<void> release() async {
    _fp?.release();
    _voc?.release();
    _fp = _voc = null;
  }

  /// Diacritised Arabic -> mono float samples at [sampleRate].
  Future<Float32List> synthesize(String text, {double pace = 0.9}) async {
    await _ensureLoaded();
    final ids = tokensToIds(arabicToTokens(text));
    if (ids.any((i) => i < 0)) {
      // A character the phonetiser has no symbol for (a stray mark, a Latin
      // letter). The Python raises here too; drop them rather than crash.
      ids.removeWhere((i) => i < 0);
    }
    final run = OrtRunOptions();
    final inputs = {
      'token_ids': OrtValueTensor.createTensorWithDataList(Int64List.fromList(ids), [1, ids.length]),
      'pace': OrtValueTensor.createTensorWithDataList(Float32List.fromList([pace]), [1]),
      'speaker': OrtValueTensor.createTensorWithDataList(Int32List.fromList([0]), [1]),
      'pitch_mul': OrtValueTensor.createTensorWithDataList(Float32List.fromList([1]), [1]),
      'pitch_add': OrtValueTensor.createTensorWithDataList(Float32List.fromList([0]), [1]),
    };
    final melOut = (await _fp!.runAsync(run, inputs))!;
    for (final v in inputs.values) {
      v.release();
    }
    final mel = melOut.first!.value as List; // [1][80][T]
    final bands = (mel[0] as List).cast<List>();
    final t = bands.first.length;
    final flat = Float32List(80 * t);
    for (var b = 0; b < 80; b++) {
      final row = bands[b];
      for (var k = 0; k < t; k++) {
        flat[b * t + k] = (row[k] as num).toDouble();
      }
    }
    for (final v in melOut) {
      v?.release();
    }

    final melIn = OrtValueTensor.createTensorWithDataList(flat, [1, 80, t]);
    final strength =
        OrtValueTensor.createTensorWithDataList(Float32List.fromList([0.005]), [1]);
    final waveOut =
        (await _voc!.runAsync(run, {'mel_spec': melIn, 'denoise': strength}))!;
    melIn.release();
    strength.release();
    final wave = (waveOut.first!.value as List)[0] as List; // [1][S]
    final out = Float32List.fromList([for (final s in wave) (s as num).toDouble()]);
    for (final v in waveOut) {
      v?.release();
    }
    run.release();

    var peak = 0.0;
    for (final s in out) {
      peak = math.max(peak, s.abs());
    }
    if (peak > 0) {
      final g = 0.9 / peak;
      for (var i = 0; i < out.length; i++) {
        out[i] *= g;
      }
    }
    return out;
  }

  /// 16-bit PCM mono WAV bytes, for just_audio.
  static Uint8List wav(Float32List samples) {
    final n = samples.length;
    final b = ByteData(44 + n * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }
}

@visibleForTesting
Uint8List openVoiceWavForTest(Float32List s) => OpenVoice.wav(s);
