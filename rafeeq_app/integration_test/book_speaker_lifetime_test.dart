import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/book_speaker_lifetime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  bookSpeakerLifetimeTests(
    screenshotReady: () async {
      debugPrint('A30_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
