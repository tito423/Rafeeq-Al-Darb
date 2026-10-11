import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/action_contrast.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final theme in contrastThemes) {
    for (final locale in contrastLocales) {
      testWidgets(
        'Android $theme/$locale action and source labels read at 4.5:1',
        (tester) => verifyActionContrast(tester, locale, theme),
      );
    }
  }
}
