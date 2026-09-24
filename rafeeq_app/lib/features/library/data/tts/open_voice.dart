import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/download_manager.dart';
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
    await _adoptFinished();
    final d = await _dir();
    for (final f in files) {
      final file = File(p.join(d.path, f));
      if (!file.existsSync() || file.lengthSync() != _sizes[f]) {
        installed.value = false;
        return false;
      }
    }
    installed.value = true;
    return true;
  }

  /// 0..1 while the pack is downloading, null otherwise - app-wide, so a
  /// button on any screen says «جارٍ التحميل» after «متابعة في الخلفية»
  /// closed the dialog that started it (owner, 2026-09-24).
  static final ValueNotifier<double?> installProgress = ValueNotifier(null);

  /// Last known install state; null until [isInstalled] has run once.
  static final ValueNotifier<bool?> installed = ValueNotifier(null);

  static Future<void>? _inFlight;

  /// Starts the download or joins the one running. [onProgress] gets
  /// (bytesSoFar, totalBytes) for whichever caller asked.
  static Future<void> install(void Function(int, int)? onProgress) async {
    void relay() {
      final v = installProgress.value;
      if (v != null) onProgress?.call((v * totalBytes).round(), totalBytes);
    }

    installProgress.addListener(relay);
    try {
      await (_inFlight ??= () async {
        installProgress.value = 0;
        try {
          await _install((got, total) => installProgress.value = got / total);
          installed.value = true;
        } finally {
          installProgress.value = null;
          _inFlight = null;
        }
      }());
    } finally {
      installProgress.removeListener(relay);
    }
  }

  /// Downloads the pack through [DownloadManager] - Android's WorkManager,
  /// not this isolate - so it carries on when the app is sent to the
  /// background or killed, resumes a dropped connection from where it
  /// stopped, and shows in the status bar. The previous in-process
  /// `HttpClient` loop froze the moment the reader left the app, which is
  /// why «يكمل في الخلفية» restarted from zero (2026-09-19).
  /// [onProgress] gets (bytesSoFar, totalBytes).
  static Future<void> _install(void Function(int, int)? onProgress) async {
    _cancel = false;
    final d = await _dir();
    d.createSync(recursive: true);
    for (final r in _retired) {
      final old = File(p.join(d.path, r));
      if (old.existsSync()) old.deleteSync();
    }
    await _adoptFinished();
    final dm = DownloadManager.instance;
    final pending = [
      for (final f in files)
        if (!_complete(File(p.join(d.path, f)), f)) f,
    ];
    for (final f in pending) {
      await dm.enqueue(
        id: taskId(f),
        url: urlFor(f),
        category: downloadCategory,
        fileName: taskId(f),
        title: 'library.open_voice_title'.tr(),
      );
    }
    final done = Completer<void>();
    void check(List<DownloadTask> _) {
      if (done.isCompleted) return;
      var bytes = 0;
      var finished = 0;
      for (final f in files) {
        if (!pending.contains(f)) {
          bytes += _sizes[f]!;
          finished++;
          continue;
        }
        final t = dm.taskById(taskId(f));
        switch (t?.status) {
          case DownloadStatus.completed:
            bytes += _sizes[f]!;
            finished++;
          case DownloadStatus.failed:
            done.completeError(HttpException(t?.error ?? 'failed'));
            return;
          case DownloadStatus.canceled:
            _cancel = true;
            done.completeError(StateError('cancelled'));
            return;
          default:
            bytes += t?.received ?? 0;
        }
      }
      onProgress?.call(bytes, totalBytes);
      if (finished == files.length) done.complete();
    }

    final sub = dm.stream.listen(check);
    check(const []);
    try {
      await done.future;
    } finally {
      await sub.cancel();
    }
    // `_finish` registers the file a moment after it reports completion;
    // wait for the bytes to be where the registry says, then move them.
    for (var i = 0; i < 50 && !await _adoptFinished(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!await isInstalled()) throw const FileSystemException('incomplete');
  }

  /// The DownloadManager id (and download file name) for one file.
  static String taskId(String f) => 'tts_open_ar_v1_$f';

  /// The `category` these transfers are enqueued under; the Downloads hub's
  /// «الأصوات» bucket claims it.
  static const downloadCategory = 'tts_voice';

  static bool _complete(File f, String name) =>
      f.existsSync() && f.lengthSync() == _sizes[name];

  /// Moves any file the background downloader finished - possibly while the
  /// app was closed - into the voice folder. True when nothing is left
  /// waiting in `downloads/`.
  static Future<bool> _adoptFinished() async {
    final d = await _dir();
    d.createSync(recursive: true);
    final dl = await DownloadManager.instance.downloadDir;
    var ok = true;
    for (final f in files) {
      final target = File(p.join(d.path, f));
      if (_complete(target, f)) continue;
      final got = File(p.join(dl.path, taskId(f)));
      if (_complete(got, f)) {
        if (target.existsSync()) target.deleteSync();
        try {
          got.renameSync(target.path);
        } on FileSystemException {
          got.copySync(target.path);
          got.deleteSync();
        }
      } else {
        ok = false;
      }
    }
    return ok;
  }

  static bool _cancel = false;

  /// Whether the last install ended because the reader cancelled it.
  static bool get wasCancelled => _cancel;

  /// Stops a running download and removes what it wrote, so 261 MB started
  /// by mistake can be taken back. The pending [install] completes with a
  /// [StateError] ('cancelled').
  static Future<void> cancelInstall() async {
    _cancel = true;
    for (final f in files) {
      await DownloadManager.instance.remove(taskId(f));
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
    for (final f in files) {
      await DownloadManager.instance.remove(taskId(f));
    }
    final d = await _dir();
    if (d.existsSync()) d.deleteSync(recursive: true);
    installed.value = false;
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
