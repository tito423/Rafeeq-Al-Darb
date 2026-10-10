import 'package:flutter_test/flutter_test.dart';

import 'support/ayah_queue_cancellation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(disposeQueueService);
  for (final failure in [true, false]) {
    test(
      'cancelled queue ignores late ${failure ? 'failed' : 'successful'} lookup',
      () => verifyCancelledQueue(lookupFails: failure),
    );
  }
}
