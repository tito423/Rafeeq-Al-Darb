import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rafeeq_app/adhan_recompute_entry.dart';
import '../test/support/jazariyyah_progress_cases.dart';
import '../test/support/jazariyyah_progress_ui.dart';

// Retain the production offline callback in this alternate test entrypoint.
// Android may re-arm existing alarms while the test APK is installed.
@pragma('vm:entry-point')
Future<void> adhanRecomputeMain() => runAdhanRecompute();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  jazariyyahProgressCases();
  jazariyyahProgressUiTests(
    screenshotReady: (language) async {
      debugPrint('A40_SCREENSHOT_READY_$language');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
