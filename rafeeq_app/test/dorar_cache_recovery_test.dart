import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dorar_cache_recovery.dart';

class _LoopbackBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LoopbackBinding();
  dorarCacheRecoveryTests(
    loadFixture: (name) => File('test/fixtures/$name').readAsBytes(),
  );
}
