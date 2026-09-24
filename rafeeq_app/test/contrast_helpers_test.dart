import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/theme/app_colors.dart';
import 'package:rafeeq_app/features/azkar/data/tasbeeh_catalog.dart';

void main() {
  test('contrastRatio matches the WCAG reference values', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
    // Flat gold on white - the number the whole fix starts from.
    expect(contrastRatio(AppColors.gold, Colors.white), closeTo(2.10, 0.02));
  });

  test('readableOn reaches 4.5 : 1 on light and dark grounds', () {
    const grounds = [
      Colors.white,
      Color(0xFFF6F8F7), // light scaffold
      Color(0xFFEFE6D2), // Home header cream
      AppColors.night,
      AppColors.nightSurface,
    ];
    for (final g in grounds) {
      for (final c in [AppColors.gold, AppColors.goldSoft, Colors.lightBlue]) {
        expect(contrastRatio(readableOn(c, g), g), greaterThanOrEqualTo(4.5),
            reason: '$c on $g');
      }
    }
  });

  test('readableOn leaves a colour that already reads alone', () {
    expect(readableOn(AppColors.gold, AppColors.night), AppColors.gold);
  });

  test('every Tasbeeh pill carries its white text at 4.5 : 1', () {
    for (final o in [...tasbeehShortAdhkar, ...tasbeehLongAdhkar]) {
      expect(contrastRatio(Colors.white, fillForWhiteText(o.color)),
          greaterThanOrEqualTo(4.5),
          reason: o.textKey);
    }
  });
}
