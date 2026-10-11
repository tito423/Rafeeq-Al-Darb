import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/scrollbar_accessibility.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in scrollbarLocales) {
    testWidgets(
      'Android $locale rail has accessible targets and actions',
      (tester) => verifyScrollbarAccessibility(tester, locale),
    );
  }
}
