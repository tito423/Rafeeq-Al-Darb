import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/hajj/presentation/widgets/madhahib_section.dart';

/// «في المذاهب الأربعة» under each Hajj step, from al-Jaziri. Holds the
/// bundled file to what `scripts/build_hajj_madhahib.py` promised: every step
/// it names exists in the guide, each step's sections are about that step,
/// and every note splits into the schools' own statements.
void main() {
  final m = HajjMadhahib.fromJson(
    jsonDecode(File('assets/data/hajj_madhahib.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final guideKeys = {for (final s in hajjSteps) s.key};

  String all(String step) => [
    for (final p in m.steps[step]!) ...[
      p.title,
      ...p.body,
      ...p.notes.expand((n) => n),
    ],
  ].join(' ');

  test('every step it names is a step of the guide', () {
    expect(m.steps, isNotEmpty);
    for (final k in m.steps.keys) {
      expect(guideKeys, contains(k), reason: k);
    }
  });

  test('each step carries its own rite', () {
    expect(all('tawaf'), contains('الطواف'));
    expect(all('sai'), contains('الصفا'));
    expect(all('arafah'), contains('عرفة'));
    expect(all('mawaqit'), contains('ذو الحليفة'));
    expect(all('hady'), contains('الهدي'));
    expect(all('nusuk'), contains('التمتع'));
    expect(all('umrah_miqaat'), contains('العمرة'));
  });

  test('a note is its schools, each named', () {
    final school = RegExp(r'^(الحنفية|المالكية|الشافعية|الحنابلة)');
    var statements = 0;
    for (final parts in m.steps.values) {
      for (final p in parts) {
        for (final note in p.notes) {
          expect(note, isNotEmpty);
          for (final s in note) {
            expect(s.trim(), isNotEmpty);
            if (school.hasMatch(s)) statements++;
          }
        }
      }
    }
    // Measured when the file was built: most notes are four statements.
    expect(statements, greaterThan(100));
  });

  test('steps with no counterpart in a topical book carry nothing', () {
    for (final k in ['preparation', 'counsel']) {
      expect(m.steps[k], isNull, reason: k);
    }
  });
}
