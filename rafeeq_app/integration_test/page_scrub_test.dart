import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/page_scrub.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('audit_A25.');
  setUpAll(EasyLocalization.ensureInitialized);
  tearDownAll(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('locale');
  });
  for (final locale in scrubLocales) {
    for (final end in ScrubEnd.values) {
      testWidgets(
        'Android $locale/${end.name} thumb follows later page changes',
        (tester) => verifyPageScrub(tester, locale, end),
      );
    }
  }
}
