import 'package:flutter_test/flutter_test.dart';

import 'support/action_contrast.dart';

void main() {
  for (final theme in contrastThemes) {
    for (final locale in contrastLocales) {
      testWidgets(
        '$theme/$locale action and source labels read at 4.5:1',
        (tester) => verifyActionContrast(tester, locale, theme),
      );
    }
  }
}
