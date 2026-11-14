import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rafeeq_app/features/hifz/data/tasmee_engine.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

/// The tasmee' recogniser (quran-asr-small, 2026-11-14) on a real Android
/// build: downloaded from R2 by the app's own pack code (size + SHA-256
/// checked), loaded through sherpa's zipformer-CTC config, and run through
/// [TasmeeEngine]'s whole-file and live paths on recitations of two
/// EveryAyah reciters held out of the model's training, put through a
/// phone-like band on the PC and pushed with
///   `adb push <wav> /data/local/tmp/tasmee_<reciter>_<sssaaa>.wav`
/// The live microphone itself is not exercised here.
// Ayah text: `text_uthmani` from quran_local.db, unaltered.
const _ayahs = {
  '067001':
      'تَبَٰرَكَ ٱلَّذِي بِيَدِهِ ٱلۡمُلۡكُ وَهُوَ عَلَىٰ كُلِّ شَيۡءٖ قَدِيرٌ',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('quran-asr-small downloads, loads and hears a held-out reciter',
      () async {
    so.initBindings();
    final engine = TasmeeEngine.instance;
    final sw = Stopwatch()..start();
    await engine.startDownload();
    expect(await engine.isInstalled(), isTrue);
    debugPrint('TASMEE_DOWNLOAD_MS ${sw.elapsedMilliseconds} '
        'bytes $tasmeeDownloadBytes');

    final tmp = await getTemporaryDirectory();
    for (final name in ['alalaqimy_067001', 'sahlyassin_018001']) {
      final src = File('/data/local/tmp/tasmee_$name.wav');
      final wav = p.join(tmp.path, '$name.wav');
      await src.copy(wav);

      sw.reset();
      final heard = await engine.transcribeFile(wav);
      debugPrint('TASMEE_FILE $name ${sw.elapsedMilliseconds} ms: $heard');
      expect(heard, isNotEmpty);

      // The live path: the long-lived worker reading the WAV's tail.
      await engine.startLive();
      String? live;
      for (var i = 0; i < 20 && (live == null || live.isEmpty); i++) {
        live = await engine.liveTail(wav);
      }
      debugPrint('TASMEE_LIVE $name: $live');
      expect(live, isNotEmpty);
      await engine.stopLive();

      final key = name.split('_').last;
      final ayah = _ayahs[key];
      if (ayah != null) {
        final r = TasmeeEngine.compare(
            ayahText: ayah, heard: heard, surahId: 67, ayahNumber: 1);
        debugPrint('TASMEE_MATCH $name ${r.matched}/${r.total}');
        expect(r.ratio, greaterThanOrEqualTo(0.9));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
