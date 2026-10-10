import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sync_account_restore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  for (final reject in [false, true]) {
    test(
      'account restoration ${reject ? 'keeps a failed push pending' : 'drains the saved queue before pulling'}',
      () => verifyAccountRestoreQueue(rejectPush: reject),
    );
  }
}
