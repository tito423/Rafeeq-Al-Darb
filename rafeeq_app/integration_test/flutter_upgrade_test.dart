import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/adhan_recompute_entry.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

import '../test/support/flutter_upgrade_reorder.dart';

@pragma('vm:entry-point')
Future<void> adhanRecomputeMain() => runAdhanRecompute();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  test('A48 native sherpa and reading-voice runtime compatibility', () {
    so.initBindings();
    expect(so.getVersion(), '1.13.8');
    expect(so.getOnnxruntimeVersion(), '1.28.2');
    OrtEnv.instance.init();
    OrtEnv.instance.release();
  });
  test('A48 actual offline Arabic command inference', () async {
    final directory = Directory('${Directory.systemTemp.path}/audit_A48_model');
    expect(
      p.isWithin(
        Directory.systemTemp.resolveSymbolicLinksSync(),
        directory.resolveSymbolicLinksSync(),
      ),
      isTrue,
    );
    final model = File('${directory.path}/model.int8.onnx');
    final tokens = File('${directory.path}/tokens.txt');
    expect(
      sha256.convert(await model.readAsBytes()).toString(),
      '714fc79628cff1916194337117579167b32385dcaf70d4b525805f4fdf07913f',
    );
    expect(
      sha256.convert(await tokens.readAsBytes()).toString(),
      '9b938381a19a69bb279cdcfc299419f25a049ea1de192e0d10317274a0f20074',
    );
    so.initBindings();
    final recognizer = so.OfflineRecognizer(
      so.OfflineRecognizerConfig(
        model: so.OfflineModelConfig(
          nemoCtc: so.OfflineNemoEncDecCtcModelConfig(model: model.path),
          tokens: tokens.path,
          numThreads: 2,
        ),
      ),
    );
    final stream = recognizer.createStream();
    try {
      final wave = so.readWave('${directory.path}/command.wav');
      expect(wave.sampleRate, 16000);
      expect(wave.samples, isNotEmpty);
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);
      final text = recognizer.getResult(stream).text;
      debugPrint('A48_ACTUAL_OFFLINE_RESULT: $text');
      expect(normalizeArabic(text), contains(normalizeArabic('الأذكار')));
    } finally {
      stream.free();
      recognizer.free();
    }
    // Only this preflight-verified, app-owned fixture directory is removed.
    directory.deleteSync(recursive: true);
  });
  flutterUpgradeReorderTests(
    screenshotReady: (label) async {
      debugPrint('A48_SCREENSHOT_READY_$label');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
