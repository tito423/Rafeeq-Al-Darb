import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/caravan_bank_completion.dart';

bool get _phoneViewport =>
    const bool.fromEnvironment('A42_PHONE_VIEWPORT', defaultValue: true);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  caravanBankCompletionTests(
    phoneViewport: _phoneViewport,
    screenshotReady: () async {
      debugPrint('A42_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
