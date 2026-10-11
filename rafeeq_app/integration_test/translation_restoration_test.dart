import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/translation_restoration.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real Android preferences, isolated from every owner preference.
  SharedPreferences.setPrefix('audit_A24.');
  for (final entry in translationRestoreCases.entries) {
    testWidgets('Android ${entry.key}', (tester) async {
      try {
        await tester.runAsync(entry.value);
      } finally {
        await tester.runAsync(cleanTranslationTestPreferences);
      }
    });
  }
}
