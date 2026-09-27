import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/content_mirrors.dart';

/// One file of «رفيق»'s voice pack, as it is on the bucket.
class VoicePackFile {
  const VoicePackFile(this.name, this.bytes, this.sha256);
  final String name;
  final int bytes;
  final String sha256;

  String get url => '${AppConfig.contentBaseUrl}/asr/rafeeq_v1/$name';
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

/// «رفيق» works only with this pack on the phone - owner, 2026-09-27: «لو
/// منزلوش الأفضل مايشتغلش بدل ما يشتغل بسوء». Downloaded once, checked by
/// byte count and SHA-256, kept in its own folder (not the tasmee model's,
/// which is deleted whole when that model is removed).
class RafeeqVoicePack {
  RafeeqVoicePack._();
  static final instance = RafeeqVoicePack._();

  static const _verified = '.verified';

  /// Last known state; null until [check] ran.
  final ValueNotifier<bool?> installed = ValueNotifier(null);

  /// 0..1 while downloading, null otherwise.
  final ValueNotifier<double?> progress = ValueNotifier(null);

  final Dio _dio = Dio();
  CancelToken? _cancel;
  Future<void>? _inFlight;

  Future<Directory> dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'rafeeq_voice_v1'));
  }

  Future<bool> check() async {
    final d = await dir();
    for (final f in voicePackFiles) {
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
        _cancel = CancelToken();
        progress.value = 0;
        try {
          final d = await dir();
          await d.create(recursive: true);
          var done = 0;
          for (final f in voicePackFiles) {
            final path = p.join(d.path, f.name);
            if (File('$path$_verified').existsSync() &&
                File(path).existsSync() &&
                await File(path).length() == f.bytes) {
              done += f.bytes;
              continue;
            }
            final tmp = '$path.part';
            await ContentMirrors.fetchFirst<void>(f.url, (url) async {
              await _dio.download(url, tmp,
                  cancelToken: _cancel,
                  onReceiveProgress: (got, _) =>
                      progress.value = (done + got) / voicePackBytes);
              final got = await File(tmp).length();
              final hash = await Isolate.run(() async =>
                  (await sha256.bind(File(tmp).openRead()).first).toString());
              if (got != f.bytes || hash != f.sha256) {
                await File(tmp).delete();
                throw StateError('${f.name}: $got bytes, sha256 $hash');
              }
            });
            if (File(path).existsSync()) await File(path).delete();
            await File(tmp).rename(path);
            await File('$path$_verified').writeAsString(f.sha256);
            done += f.bytes;
            progress.value = done / voicePackBytes;
          }
          installed.value = true;
        } finally {
          progress.value = null;
          _cancel = null;
          _inFlight = null;
        }
      }();

  void cancel() => _cancel?.cancel();

  Future<void> delete() async {
    final d = await dir();
    if (d.existsSync()) await d.delete(recursive: true);
    installed.value = false;
  }
}
