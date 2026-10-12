import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dorar_search_lifetime.dart';

class _LoopbackBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LoopbackBinding();
  dorarSearchLifetimeTests(
    loadFixture: () => File(
      'test/fixtures/dorar_innama_al_amal_2026-09-26.json',
    ).readAsBytes(),
  );
}
