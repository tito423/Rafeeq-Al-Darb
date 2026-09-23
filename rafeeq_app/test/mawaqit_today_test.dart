import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/hajj/presentation/widgets/mawaqit_today_card.dart';

/// «المواقيت اليوم» — the Saudi Ministry of Hajj and Umrah's own sentences,
/// read from https://haj.gov.sa/ar/Umrah/Miqaats on 2026-09-23.
void main() {
  final data = MawaqitToday.parse(
    File('assets/data/mawaqit_today.json').readAsStringSync(),
  );

  test('the five miqats, each with the ministry\'s sentence', () {
    expect(data.mawaqit.length, 5);
    expect(data.sourceUrl, 'https://haj.gov.sa/ar/Umrah/Miqaats');
    for (final m in data.mawaqit) {
      expect(m.text, contains('ميقات أهل'), reason: m.name);
      expect(RegExp(r'\(\d+\) كلم').hasMatch(m.text), isTrue, reason: m.name);
    }
  });

  test('a modern name is only one the sentence itself gives', () {
    for (final m in data.mawaqit) {
      if (m.today != null) expect(m.text, contains(m.today!), reason: m.name);
    }
    expect(
      data.mawaqit.map((m) => m.today),
      ['أبيار علي', 'رابغ', 'السيل الكبير', 'السعدية', null],
      reason: 'the ministry gives Dhat Irq no modern name, so neither do we',
    );
  });

  test('the card sits under steps that exist', () {
    final keys = {for (final s in hajjSteps) s.key};
    for (final k in mawaqitStepKeys) {
      expect(keys, contains(k));
    }
  });
}
