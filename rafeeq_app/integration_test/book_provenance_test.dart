import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rafeeq_app/adhan_recompute_entry.dart';
import '../test/support/book_provenance_ui.dart';

@pragma('vm:entry-point')
Future<void> adhanRecomputeMain() => runAdhanRecompute();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  bookProvenanceTests(
    screenshotReady: (language) async {
      debugPrint('A28_SCREENSHOT_READY_$language');
      await Future<void>.delayed(const Duration(seconds: 4));
    },
  );
}
