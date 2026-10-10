import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/sync_account_restore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final reject in [false, true]) {
    testWidgets(
      'Android account restore ${reject ? 'preserves a rejected upload' : 'sends the persisted queue first'}',
      (tester) => verifyAccountRestoreQueue(rejectPush: reject),
    );
  }
}
