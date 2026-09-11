import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gestures on a mushaf page, as the owner set them in the tenth batch:
/// «ضغطة واحدة خفيفة على الصفحة في أي مكان أو آية = ملء الشاشة أو خروج منه،
/// نصي أو مصوّر» and «ضغطة مطولة على الآية تظليل وكارت الآية».
///
/// History: through v3.18.0 a tap on a verse started the continuous
/// recitation and the page scrolled on; v3.18.0 made the tap open the card.
/// Now a tap belongs to the page and the card is the long press.
void main() {
  final page = File('lib/features/quran/presentation/widgets/mushaf_text_page.dart')
      .readAsStringSync();
  final image = File('lib/features/quran/presentation/widgets/mushaf_page_view.dart')
      .readAsStringSync();
  final screen = File('lib/features/quran/presentation/screens/quran_screen.dart')
      .readAsStringSync();

  test('a tap on a verse is the page\'s, the card is the long press', () {
    expect(page, isNot(contains('onAyahTap')));
    expect(page, contains('onAyahLongPress: widget.onAyahLongPress'));
    expect(image, isNot(contains('onAyahTap')));
    expect(image, contains('onLongPressStart'));
  });

  test('the page tap toggles full screen in both modes', () {
    expect(RegExp('onBackgroundTap: _onPageTap').allMatches(screen).length, 2);
    final at = screen.indexOf('void _onPageTap()');
    expect(at, greaterThan(0));
    final body = screen.substring(at, screen.indexOf('}', at));
    expect(body, contains('Orientation.landscape'));
    expect(body, contains('_togglePageFillScreen()'));
  });

  test('the reader marker plays one verse, not the continuous recitation', () {
    final at = screen.indexOf('onPlayTap:');
    expect(at, greaterThan(0));
    final handler = screen.substring(at, at + 200);
    expect(handler, isNot(contains('startContinuous')));
    expect(handler, contains('.play('));
  });
}
