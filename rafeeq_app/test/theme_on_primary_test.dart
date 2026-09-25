import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_colors.dart';
import 'package:rafeeq_app/core/theme/app_theme.dart';

/// Every filled button in the RGB theme carried white on #22E0C6 at
/// 1.67 : 1 (contrast scan, emulator-5554, 2026-09-25). Words on a primary
/// fill must read in every theme.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
    ('rgb', AppTheme.rgb()),
  ]) {
    test('$name: text on the primary fill reads at 4.5 : 1', () {
      final s = theme.colorScheme;
      expect(contrastRatio(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
      final fg = theme.filledButtonTheme.style!.foregroundColor!
          .resolve(<WidgetState>{})!;
      expect(contrastRatio(fg, s.primary), greaterThanOrEqualTo(4.5));
    });
  }
}
