import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/makharij_hit_coordinates.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  makharijHitCoordinateTests(
    screenshotReady: () async {
      debugPrint('A41_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
