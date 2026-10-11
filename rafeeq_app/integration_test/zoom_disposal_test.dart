import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/zoom_disposal.dart';

/// Seed the unchanged test/fixtures/page_303.json into the app's documents
/// directory at audit_A26/page_303.json before launching this fixture APK.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('audit_A26.');
  late Directory documents;
  late String ayahJson;
  setUpAll(() async {
    await SharedPreferences.getInstance();
    documents = await getApplicationDocumentsDirectory();
    ayahJson = await File(
      '${documents.path}/audit_A26/page_303.json',
    ).readAsString();
    await prepareZoomImage(documents);
  });
  tearDownAll(() async {
    // Delete only the two files created specifically for this test. Empty
    // directory deletion refuses to remove any unexpected additional files.
    for (final relative in [
      'audit_A26/page_303.json',
      'mushaf/audit_A26/001.svg',
    ]) {
      final file = File('${documents.path}/$relative');
      await file.delete();
      await file.parent.delete();
    }
  });
  for (final mode in zoomModes) {
    for (final destroyScope in [false, true]) {
      for (final zoomed in [false, true]) {
        testWidgets(
          'Android $mode zoom=$zoomed destroyScope=$destroyScope',
          (tester) => verifyZoomExit(
            tester,
            mode,
            zoomAyahs(ayahJson),
            destroyScope: destroyScope,
            zoomed: zoomed,
          ),
        );
      }
    }
  }
}
