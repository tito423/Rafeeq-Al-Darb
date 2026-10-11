import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/zoom_disposal.dart';

void main() {
  late Directory documents;
  final ayahs = zoomAyahs(
    File('test/fixtures/page_303.json').readAsStringSync(),
  );
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('rafeeq_A26_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.path,
        );
    await prepareZoomImage(documents);
  });
  tearDownAll(() => documents.delete(recursive: true));
  for (final mode in zoomModes) {
    for (final destroyScope in [false, true]) {
      for (final zoomed in [false, true]) {
        testWidgets(
          '$mode zoom=$zoomed destroyScope=$destroyScope',
          (tester) => verifyZoomExit(
            tester,
            mode,
            ayahs,
            destroyScope: destroyScope,
            zoomed: zoomed,
          ),
        );
      }
    }
  }
}
