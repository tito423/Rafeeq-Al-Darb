import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/sync_conflict_cases.dart';
import '../test/support/sync_conflict_restore.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  syncConflictRestoreCases();
  testWidgets('A04 real Home reading card reflects accepted sync state', (
    tester,
  ) async {
    await verifySyncConflict(
      localPage: null,
      remotePage: 540,
      remoteTimestamp: 100,
      expectedPage: 540,
      observeLastPage: true,
      visualTester: tester,
      screenshotReady: () async {
        debugPrint('A04_SCREENSHOT_READY');
        await Future<void>.delayed(const Duration(seconds: 4));
      },
    );
  });
}
