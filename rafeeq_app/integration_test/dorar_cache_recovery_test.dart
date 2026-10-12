import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/dorar_cache_recovery.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  dorarCacheRecoveryTests(
    loadFixture: (name) =>
        File('${Directory.systemTemp.path}/audit_A39_$name').readAsBytes(),
    screenshotReady: () async {
      debugPrint('A39_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
