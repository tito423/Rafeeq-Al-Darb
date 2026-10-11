import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/kids_story_lifetime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  kidsStoryLifetimeTests(
    screenshotReady: () async {
      debugPrint('A35_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
