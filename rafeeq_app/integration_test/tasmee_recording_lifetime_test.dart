import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/tasmee_recording_lifetime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tasmeeRecordingLifetimeTests(
    screenshotReady: () async {
      debugPrint('A33_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
