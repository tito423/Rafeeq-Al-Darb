import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('display sheet reveals the auto-scroll speed while enabled', () {
    final sheet = File(
      'lib/features/quran/presentation/widgets/mushaf/quran_display_sheet.dart',
    ).readAsStringSync();

    expect(sheet, contains('required double autoScrollSpeed'));
    expect(sheet, contains('AutoScrollSpeedBar('));
    expect(sheet, contains('if (_textOnly && _auto)'));
  });

  test('a page tap clears a selected ayah before toggling full screen', () {
    final screen = File(
      'lib/features/quran/presentation/screens/quran_screen.dart',
    ).readAsStringSync();
    final tap = screen.substring(
      screen.indexOf('void _onPageTap()'),
      screen.indexOf('Widget _toolbarFor', screen.indexOf('void _onPageTap()')),
    );

    expect(tap, contains('_highlightSurah = null'));
    expect(tap, contains('_highlightAyah = null'));
    expect(
      tap.indexOf('_highlightSurah = null'),
      lessThan(tap.indexOf('_togglePageFillScreen()')),
    );
  });

  test('khatma previous and upcoming counts are real navigation buttons', () {
    final card = File(
      'lib/features/khatma/presentation/khatma_card.dart',
    ).readAsStringSync();

    expect(card, contains('onOpenPage'));
    expect(card, contains('showKhatmaWirdsSheet('));
    expect(card, contains('previousWirds('));
  });
}
