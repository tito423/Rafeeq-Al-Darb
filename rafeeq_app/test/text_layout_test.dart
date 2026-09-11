import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/text_layout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A third text layout was added at the owner's request — «انت تضيف وضع نصي
/// زي بتاع ختمة بالظبط يبقى المجموع نصي ٣».
///
/// Two things break quietly when an enum like this grows: a control that
/// flipped between two values silently swallows the third, and a
/// `== QuranTextLayout.page` check starts treating the new value as `cards`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('there are three layouts and cycling reaches every one of them',
      () async {
    expect(QuranTextLayout.values.length, 3);

    final notifier = QuranTextLayoutNotifier();
    final start = notifier.state;
    final seen = <QuranTextLayout>{start};
    // One lap must visit each layout exactly once and come back to the start.
    for (var i = 0; i < QuranTextLayout.values.length - 1; i++) {
      await notifier.toggle();
      expect(seen.contains(notifier.state), isFalse,
          reason: '${notifier.state} came round before the lap finished');
      seen.add(notifier.state);
    }
    expect(seen, QuranTextLayout.values.toSet());
    await notifier.toggle();
    expect(notifier.state, start);
  });

  test('the two running-text layouts are grouped, cards is not', () {
    // `isFlowing` exists so a caller cannot write `== page` and quietly send
    // the reading layout down the cards branch.
    expect(QuranTextLayout.page.isFlowing, isTrue);
    expect(QuranTextLayout.reading.isFlowing, isTrue);
    expect(QuranTextLayout.cards.isFlowing, isFalse);
  });

  test('an unknown stored name falls back rather than throwing', () {
    expect(QuranTextLayout.fromName('reading'), QuranTextLayout.reading);
    expect(QuranTextLayout.fromName('nonsense'), QuranTextLayout.page);
    expect(QuranTextLayout.fromName(null), QuranTextLayout.page);
  });

  test('every layout has a name in all seven locales', () {
    // Trap #8: a missing key renders as the raw key on screen.
    const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];
    for (final loc in locales) {
      final doc = jsonDecode(
        File('assets/translations/$loc.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final quran = doc['quran'] as Map<String, dynamic>;
      for (final layout in QuranTextLayout.values) {
        final key = 'layout_${layout.name}';
        expect(quran[key], isA<String>(),
            reason: '$loc is missing quran.$key');
        expect((quran[key] as String).trim(), isNotEmpty, reason: '$loc.$key');
      }
    }
  });
}
