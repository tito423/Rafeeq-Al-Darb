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

  test('the page tap is still one gesture with two jobs, in both modes', () {
    // Both the text page and the image page route their tap to the same
    // handler — that has not changed.
    expect(RegExp('onBackgroundTap: _onPageTap').allMatches(screen).length, 2);
    final at = screen.indexOf('void _onPageTap()');
    expect(at, greaterThan(0));
    // To the end of the method, not to the first `}` — the handler now has
    // an `if` block inside it, and stopping at the first brace would read
    // half the body and silently assert against a fragment.
    final body = screen.substring(at, screen.indexOf('\n  }', at));
    expect(body, contains('Orientation.landscape'),
        reason: 'landscape has no options, so the tap does nothing there');

    // WHAT CHANGED ON 2026-09-17. Full screen became the default and
    // permanent state — «خلي دايما الصفحة في وضع ملء الشاشة» — so the tap's
    // old meaning («enter or leave full screen») was free, and it now shows
    // and hides `MushafChrome`, the controls that float over the page. No
    // new gesture was invented: the page already owns a long-press, a
    // horizontal swipe and a vertical scroll, and a fifth would have had to
    // fight one of them.
    expect(body, contains('_chromeVisible = !_chromeVisible'),
        reason: 'in full screen the tap must toggle the floating controls');
    expect(body, contains('_togglePageFillScreen()'),
        reason: 'from normal mode the tap still enters full screen, so a '
            'reader who turned full screen off can get back in');
  });

  test('the floating controls cannot be left with no way out', () {
    // Full screen hides AppShell's navigation bar, so if the panel were the
    // only thing that could restore it AND the panel could not be summoned,
    // the reader would be stuck in the Qur'an tab. Two independent things
    // prevent that and both are asserted: the tap always toggles the panel
    // (above), and the panel carries the Display sheet, whose «full screen»
    // switch turns the mode off.
    final sheet = File(
      'lib/features/quran/presentation/widgets/mushaf/quran_display_sheet.dart',
    ).readAsStringSync();
    expect(sheet, contains('onTogglePageFill'),
        reason: 'the Display sheet is the way back out of full screen');
    expect(sheet, contains("'quran.page_fit_full'.tr()"));
  });

  test('the reader marker plays one verse, not the continuous recitation', () {
    final at = screen.indexOf('onPlayTap:');
    expect(at, greaterThan(0));
    final handler = screen.substring(at, at + 200);
    expect(handler, isNot(contains('startContinuous')));
    expect(handler, contains('.play('));
  });
}
