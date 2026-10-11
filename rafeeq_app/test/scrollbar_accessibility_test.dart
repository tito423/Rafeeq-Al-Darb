import 'package:flutter_test/flutter_test.dart';

import 'support/scrollbar_accessibility.dart';

void main() {
  for (final locale in scrollbarLocales) {
    testWidgets(
      '$locale rail has accessible targets and actions',
      (tester) => verifyScrollbarAccessibility(tester, locale),
    );
  }
}
