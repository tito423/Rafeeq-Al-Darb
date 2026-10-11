import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/page_scrub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final locale in scrubLocales) {
    for (final end in ScrubEnd.values) {
      testWidgets(
        '$locale/${end.name} thumb follows later page changes',
        (tester) => verifyPageScrub(tester, locale, end),
      );
    }
  }
}
