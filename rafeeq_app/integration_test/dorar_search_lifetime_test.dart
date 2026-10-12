import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/dorar_search_lifetime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  dorarSearchLifetimeTests(
    loadFixture: () => File(
      '${Directory.systemTemp.path}/audit_A38_dorar_original.json',
    ).readAsBytes(),
    screenshotReady: () async {
      debugPrint('A38_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
