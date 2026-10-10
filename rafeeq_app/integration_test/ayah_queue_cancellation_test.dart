import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/ayah_queue_cancellation.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(disposeQueueService);
  for (final failure in [true, false]) {
    testWidgets(
      'Android cancelled queue ignores late ${failure ? 'failed' : 'successful'} lookup',
      (_) => verifyCancelledQueue(lookupFails: failure),
    );
  }
}
