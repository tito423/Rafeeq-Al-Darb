import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/content_mirrors.dart';
import 'voice_pack_http.dart';

/// One file of «رفيق»'s voice pack, as it is on the bucket.
class VoicePackFile {
  const VoicePackFile(this.name, this.bytes, this.sha256,
      {this.folder = 'rafeeq_v1'});
  final String name;
  final int bytes;
  final String sha256;

  /// The pack's folder under `asr/` on the host.
  final String folder;
  String get url => '${AppConfig.contentBaseUrl}/asr/$folder/$name';
}

/// Chosen by measurement on 2026-09-27 (TASK_FOLLOWUP 18:50): Meta's
/// omnilingual-asr 300M CTC v2 int8 as sherpa-onnx converts it (Apache-2.0,
/// 1600+ languages including all seven of the app's; ~0.5 s a command on a
/// desktop CPU, the best Arabic of four models tried) and silero VAD v5 (MIT),
/// which finds where speech starts and stops. Sizes and hashes printed by
/// scripts/publish_rafeeq_voice_pack.py; every file range-checked 206 on R2
/// and on the content-mirror release.
const voicePackFiles = <VoicePackFile>[
  VoicePackFile('model.int8.onnx', 365841453,
      'e3042b2f3b3ef0af2211bf99d2b4bf94a21f5ac0e9898827e7dd6d003a860e91'),
  VoicePackFile('tokens.txt', 90630,
      '7d99997ef207ff14c2cfe825f2aa037528ea250113cc3c6392bfe49326884ba6'),
  VoicePackFile('silero_vad.onnx', 2313101,
      '6b99cbfd39246b6706f98ec13c7c50c6b299181f2474fa05cbc8046acc274396'),
];

int get voicePackBytes => voicePackFiles.fold(0, (s, f) => s + f.bytes);

/// «دقة أعلى في العربية» - an optional second pack (owner, 2026-09-30:
/// «كمالي على حسب مزاج المستخدم» … «إلا البطء»): NVIDIA's Arabic
/// FastConformer (stt_ar_fastconformer_hybrid_large_pcd_v1.0, CC BY 4.0),
/// CTC head, int8, as packaged for sherpa-onnx by krut42 on Hugging Face.
/// Measured on this PC on the same clips (E:\DevEnv\asr\num_test.py):
/// the base pack wrote the owner's sentence as «…سورة البقرة آية٥» and lost
/// «مئتين وخمسة وخمسين» entirely; whisper-turbo (1 GB) got it at 4-7 s; this
/// one wrote «…سورة البقرة آية مئتان وخمسة وخمسون» and every number clip right
/// in 0.1 s. Arabic only, so it is used when the app is in Arabic, in place
/// of the base model (rafeeq_ear.dart).
const accuratePackFiles = <VoicePackFile>[
  VoicePackFile('model.int8.onnx', 173888072,
      '714fc79628cff1916194337117579167b32385dcaf70d4b525805f4fdf07913f',
      folder: 'rafeeq_ar_v1'),
  VoicePackFile('tokens.txt', 12858,
      '9b938381a19a69bb279cdcfc299419f25a049ea1de192e0d10317274a0f20074',
      folder: 'rafeeq_ar_v1'),
];

/// «رفيق» works only with this pack on the phone - owner, 2026-09-27: «لو
/// منزلوش الأفضل مايشتغلش بدل ما يشتغل بسوء». Downloaded once, checked by
/// byte count and SHA-256, kept in its own folder (not the tasmee model's,
/// which is deleted whole when that model is removed).
class RafeeqVoicePack {
  RafeeqVoicePack._(this.files, this._folder);
  static final instance = RafeeqVoicePack._(voicePackFiles, 'rafeeq_voice_v1');

  /// The optional higher-accuracy pack ([accuratePackFiles]).
  static final accurate =
      RafeeqVoicePack._(accuratePackFiles, 'rafeeq_ar_v1');

  final List<VoicePackFile> files;
  final String _folder;
  int get totalBytes => files.fold(0, (s, f) => s + f.bytes);

  static const _verified = '.verified';

  /// Last known state; null until [check] ran.
  final ValueNotifier<bool?> installed = ValueNotifier(null);

  /// 0..1 while downloading, null otherwise.
  final ValueNotifier<double?> progress = ValueNotifier(null);

  final Dio _dio = Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: createVoicePackHttpClient,
    );
  CancelToken? _cancel;
  Future<void>? _inFlight;

  Future<Directory> dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, _folder));
  }

  Future<bool> check() async {
    final d = await dir();
    for (final f in files) {
      final file = File(p.join(d.path, f.name));
      final mark = File('${file.path}$_verified');
      if (!file.existsSync() ||
          !mark.existsSync() ||
          mark.readAsStringSync().trim() != f.sha256 ||
          await file.length() != f.bytes) {
        installed.value = false;
        return false;
      }
    }
    installed.value = true;
    return true;
  }

  /// Starts the download, or joins the one running.
  Future<void> download() => _inFlight ??= () async {
        debugPrint('rafeeq voice pack: download started');
        _cancel = CancelToken();
        progress.value = 0;
        try {
          final d = await dir();
          await d.create(recursive: true);
          var done = 0;
          for (final f in files) {
            final path = p.join(d.path, f.name);
            if (File('$path$_verified').existsSync() &&
                File(path).existsSync() &&
                await File(path).length() == f.bytes) {
              done += f.bytes;
              continue;
            }
            final tmp = '$path.part';
            await ContentMirrors.fetchFirst<void>(f.url, (url) async {
              // A whole file left by an interrupted install is checked, not
              // fetched again (366 MB).
              final left = File(tmp);
              if (!(left.existsSync() && await left.length() == f.bytes)) {
                await _dio.download(url, tmp,
                  cancelToken: _cancel,
                  onReceiveProgress: (got, _) =>
                      progress.value = (done + got) / totalBytes);
              }
              final got = await File(tmp).length();
              final hash = await _sha256(tmp);
              if (got != f.bytes || hash != f.sha256) {
                await File(tmp).delete();
                throw StateError('${f.name}: $got bytes, sha256 $hash');
              }
            });
            if (File(path).existsSync()) await File(path).delete();
            await File(tmp).rename(path);
            await File('$path$_verified').writeAsString(f.sha256);
            done += f.bytes;
            progress.value = done / totalBytes;
          }
          installed.value = true;
        } finally {
          progress.value = null;
          _cancel = null;
          _inFlight = null;
        }
      }();

  /// Static on purpose: a closure made inside [download] would carry this
  /// object (its Dio, its notifiers) into the isolate, and they cannot be
  /// sent - the first download on emulator-5554 got all 366 MB and then
  /// failed right here.
  static Future<String> _sha256(String path) => Isolate.run(() async =>
      (await sha256.bind(File(path).openRead()).first).toString());

  void cancel() {
    debugPrintStack(
      label: 'rafeeq voice pack: cancel requested',
      stackTrace: StackTrace.current,
    );
    _cancel?.cancel('user requested voice-pack cancellation');
  }

  /// Bytes the pack takes on the phone (the downloads' storage row).
  Future<int> usageBytes() async {
    final d = await dir();
    if (!d.existsSync()) return 0;
    var n = 0;
    for (final f in d.listSync()) {
      if (f is File) n += f.lengthSync();
    }
    return n;
  }

  Future<void> delete() async {
    final d = await dir();
    if (d.existsSync()) await d.delete(recursive: true);
    installed.value = false;
  }
}
