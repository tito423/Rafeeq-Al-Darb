import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../../../../core/config/app_config.dart';
import '../../../../core/services/download_manager.dart';

/// The downloadable Arabic voice that reads books: Supertone's Supertonic-3
/// (31 languages, Arabic among them; code MIT, weights BigScience OpenRAIL-M)
/// as sherpa-onnx packages it in int8, run on the device through the
/// `sherpa_onnx` package the app already carries for speech recognition.
/// Mirrored on R2 under `tts/supertonic3_ar_v1/` (~139 MB).
///
/// WHY IT REPLACED THE FASTPITCH VOICE. «النموذج اللي بيقرا الكلام بجد مش
/// حلو … حتى لو حجمه كبير» (owner, 2026-10-19). Measured 2026-10-19/20 on 30
/// diacritised hadith matns from Bukhari and Muslim (E:\DevEnv\tts_eval):
///  * naturalness, UTMOS22-strong: 3.27 against 2.69 for FastPitch+Vocos;
///  * words, NVIDIA's Arabic FastConformer reading it back: 5.4% CER
///    against 5.3%, and a worst sentence of 13.6% against 30%;
///  * the divine name (scripts/measure_jalala_tafkhim.py, F2 of the vowel
///    after the lam): «اللَّهُ» 1262 Hz and «قَالَ اللَّهُ» 1209 Hz heavy,
///    «بِاللَّهِ» 1421 Hz light after the kasra - the same pattern the owner
///    chose FastPitch for (1230 / 1102 / 1437).
/// fp32 weights measured no better than int8; Nabra-82M and four Piper
/// voices measured worse on both counts.
///
/// THE HARAKAT REACH THE MODEL. It reads characters, not phonemes, and its
/// `unicode_indexer.bin` gives every haraka its own id (fatha 324 … sukun
/// 328), so the book's vowelled text is passed through untouched.
///
/// Voice 6 (`sid`), a male voice (median F0 89 Hz), the best of the five
/// male presets on both scores. 8 flow steps: 5 scored 2.7-2.9, 12 no better
/// than 8. A phone too slow for 8 drops to [_slowSteps] - see [synthesize].
class OpenVoice {
  OpenVoice._();
  static final OpenVoice instance = OpenVoice._();

  static const sampleRate = 44100;
  static const _sid = 6;
  static const _steps = 8;
  static const _slowSteps = 6;

  static const _pack = 'supertonic3_ar_v1';
  static const _sizes = {
    'duration_predictor.int8.onnx': 3700147,
    'text_encoder.int8.onnx': 36416150,
    'vector_estimator.int8.onnx': 78400833,
    'vocoder.int8.onnx': 25991073,
    'tts.json': 8253,
    'unicode_indexer.bin': 262144,
    'voice.bin': 517168,
  };
  static final files = _sizes.keys.toList(growable: false);
  static const totalBytes =
      3700147 + 36416150 + 78400833 + 25991073 + 8253 + 262144 + 517168;

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'tts', _pack));
  }

  /// The FastPitch pack this one replaced (fp_ms.onnx + vocos44.onnx,
  /// 261 MB). Nothing reads it any more, so it is removed rather than left
  /// as space the reader can neither use nor see.
  static Future<void> _dropRetired() async {
    final base = await getApplicationSupportDirectory();
    final old = Directory(p.join(base.path, 'tts', 'open_ar_v1'));
    try {
      if (old.existsSync()) await old.delete(recursive: true);
    } on FileSystemException {
      // Tried again next time.
    }
  }

  static String urlFor(String name) =>
      '${AppConfig.contentBaseUrl}/tts/$_pack/$name';

  /// Every file present at its full size.
  static Future<bool> isInstalled() async {
    await _dropRetired();
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
    await _dropRetired();
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
  static String taskId(String f) => 'tts_${_pack}_$f';

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

  /// Stops a running download and removes what it wrote, so a pack started
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
    // A pack the background downloader finished while this screen was not
    // looking still sits in `downloads/`; counted from the voice folder alone
    // it read «لا يوجد محتوى منزَّل» with the voice on the phone (owner,
    // 2026-09-26). Move it in first, exactly as `isInstalled` does.
    await _adoptFinished();
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

  // ── The worker ─────────────────────────────────────────────────────────
  //
  // sherpa's `generate` is a synchronous FFI call of a second or more, so the
  // model lives in a worker isolate and the reader's frames never wait on
  // it. The worker is stopped by a message, never killed: sherpa_onnx 1.13.8
  // has no finalizer, and only `free()` gives the model's memory back.

  SendPort? _toWorker;
  Future<void>? _starting;
  final _pending = <int, Completer<Float32List>>{};
  int _nextId = 0;

  /// Flow steps for the next chunk; lowered once if this phone is slow.
  int _stepsNow = _steps;

  Future<void> _ensureLoaded() => _starting ??= () async {
        final dir = (await _dir()).path;
        final inbox = ReceivePort();
        final exited = ReceivePort();
        final ready = Completer<SendPort>();
        inbox.listen((m) {
          if (m is SendPort) {
            ready.complete(m);
          } else if (m is (int, Float32List?, String?)) {
            final c = _pending.remove(m.$1);
            if (c == null) return;
            final samples = m.$2;
            if (samples != null) {
              c.complete(samples);
            } else {
              c.completeError(StateError(m.$3 ?? 'synthesis failed'));
            }
          }
        });
        await Isolate.spawn(_workerMain, (inbox.sendPort, dir),
            onExit: exited.sendPort);
        unawaited(exited.first.then((_) {
          exited.close();
          inbox.close();
          // A worker that died (not one that was released) fails what it
          // still owed, so BookSpeaker falls back instead of waiting.
          for (final c in _pending.values) {
            if (!c.isCompleted) {
              c.completeError(StateError('voice worker exited'));
            }
          }
          _pending.clear();
          _toWorker = null;
          _starting = null;
        }));
        _toWorker = await ready.future;
      }();

  static void _workerMain((SendPort, String) a) {
    final (out, dir) = a;
    so.initBindings();
    final inbox = ReceivePort();
    final tts = so.OfflineTts(so.OfflineTtsConfig(
      model: so.OfflineTtsModelConfig(
        supertonic: so.OfflineTtsSupertonicModelConfig(
          durationPredictor: p.join(dir, 'duration_predictor.int8.onnx'),
          textEncoder: p.join(dir, 'text_encoder.int8.onnx'),
          vectorEstimator: p.join(dir, 'vector_estimator.int8.onnx'),
          vocoder: p.join(dir, 'vocoder.int8.onnx'),
          ttsJson: p.join(dir, 'tts.json'),
          unicodeIndexer: p.join(dir, 'unicode_indexer.bin'),
          voiceStyle: p.join(dir, 'voice.bin'),
        ),
        numThreads: math.min(4, Platform.numberOfProcessors),
      ),
    ));
    out.send(inbox.sendPort);
    inbox.listen((m) {
      if (m == null) {
        tts.free();
        inbox.close();
        Isolate.exit();
      }
      final (id, text, steps) = m as (int, String, int);
      try {
        final audio = tts.generateWithConfig(
          text: text,
          config: so.OfflineTtsGenerationConfig(
            sid: _sid,
            numSteps: steps,
            extra: const {'lang': 'ar'},
          ),
        );
        out.send((id, audio.samples, null));
      } catch (e) {
        out.send((id, null, '$e'));
      }
    });
  }

  /// Starts the worker ahead of the first «استماع», so loading the model is
  /// spent while the reader is reading rather than after they tap.
  Future<void> warmUp() async {
    if (_toWorker != null || !await isInstalled()) return;
    await _ensureLoaded();
  }

  /// Frees the model and ends the worker, after whatever it is rendering.
  Future<void> release() async {
    final starting = _starting;
    if (starting == null) return;
    await starting;
    _toWorker?.send(null);
    _toWorker = null;
    _starting = null;
  }

  /// Diacritised Arabic -> mono float samples at [sampleRate], peak 0.9.
  ///
  /// The reader hears chunk N while chunk N+1 renders, so rendering must
  /// stay faster than speech. The first chunk that takes longer than 85% of
  /// its own duration drops the rest to [_slowSteps] (6 steps: a little less
  /// natural, about a quarter faster) rather than leave gaps.
  Future<Float32List> synthesize(String text) async {
    await _ensureLoaded();
    final send = _toWorker;
    if (send == null) throw StateError('voice worker not running');
    final id = _nextId++;
    final done = _pending[id] = Completer<Float32List>();
    final watch = Stopwatch()..start();
    send.send((id, text, _stepsNow));
    final out = await done.future;
    final spoken = out.length / sampleRate;
    if (_stepsNow > _slowSteps &&
        spoken > 1 &&
        watch.elapsedMilliseconds / 1000 > 0.85 * spoken) {
      _stepsNow = _slowSteps;
      debugPrint('OpenVoice: ${watch.elapsedMilliseconds} ms for '
          '${spoken.toStringAsFixed(1)} s - $_slowSteps steps from now on');
    }
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
