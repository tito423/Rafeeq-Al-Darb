import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tap on a verse in the text mushaf selects it and opens its card. It must
/// not start the recitation.
///
/// Through v3.18.0 the flowing layouts wired `_FlowingAyahs(onAyahTap:
/// widget.onPlayTap)` — the tap started continuous recitation and the page
/// scrolled on to the next verse: «لما بضغط على آية في المصحف النصي بيقوم
/// مشغّل تلقائي التلاوة … وينزل بالشاشة لتحت على اللي بعدها». The card
/// layout did the same on the verse's text.
void main() {
  final page = File('lib/features/quran/presentation/widgets/mushaf_text_page.dart')
      .readAsStringSync();

  test('a tap in the flowing layouts opens the card', () {
    expect(page, isNot(contains('onAyahTap: widget.onPlayTap')));
    expect(page, contains('onAyahTap: widget.onAyahTap'));
  });

  test('the reader marker plays one verse, not the continuous recitation', () {
    final screen = File('lib/features/quran/presentation/screens/quran_screen.dart')
        .readAsStringSync();
    final at = screen.indexOf('onPlayTap:');
    expect(at, greaterThan(0));
    final handler = screen.substring(at, at + 200);
    expect(handler, isNot(contains('startContinuous')));
    expect(handler, contains('.play('));
  });
}
