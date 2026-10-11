import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';

import 'support/action_contrast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
    ('rgb', AppTheme.rgb()),
  ]) {
    for (final (kind, style) in [
      ('text', theme.textButtonTheme.style!),
      ('outlined', theme.outlinedButtonTheme.style!),
    ]) {
      test(
        '$name/$kind labels remain readable through Material state layers',
        () {
          verifyActionStateContrast(
            style,
            theme.colorScheme.surface.withAlpha(255),
            '$name/$kind',
          );
        },
      );
    }
  }
}
