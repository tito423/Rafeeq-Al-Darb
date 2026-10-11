import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/more_settings_lifetime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  moreSettingsLifetimeTests(
    screenshotReady: () async {
      debugPrint('A36_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
    themeScreenshotReady: () async {
      debugPrint('A36_THEME_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
