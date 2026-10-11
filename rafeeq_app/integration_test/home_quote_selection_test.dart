import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/home_quote_selection.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  homeQuoteSelectionTests(
    screenshotReady: () async {
      debugPrint('A34_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
