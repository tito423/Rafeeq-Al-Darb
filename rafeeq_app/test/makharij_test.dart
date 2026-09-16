import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/articulation.dart';
import 'package:rafeeq_app/features/tajweed/data/makharij.dart';

/// The makharij data is a claim about a matn, and this is what checks it.
///
/// The matn states its own count in its first line on the subject: «مَخَارِجُ
/// الحُرُوفِ سَبْعَةَ عَشَرْ» (البيت ٩، ص٥٦), and the eleven lines after it
/// enumerate every letter of every one of them — ٣ للجوف، ٦ للحلق، ١٨
/// للسان، ٤ للشفتين. So the data is not graded against my reading of
/// it; it is graded against what ابن الجزري versified, which is the only
/// kind of check worth having here.
///
/// It used to be graded against «غاية المريد», a book by a modern author,
/// which the app quoted verbatim and no longer ships at all.
void main() {
  test('seventeen makharij, which is the number the book settles on', () {
    expect(makharij.length, 17);
  });

  test('the five general regions are all present, once each', () {
    expect(makhrajRegions.length, MakhrajRegion.values.length);
    expect(
      makhrajRegions.map((r) => r.region).toSet(),
      MakhrajRegion.values.toSet(),
    );
  });

  test('each region holds the number of makharij the book gives it', () {
    // الأبيات ١٠–١٩: الجوف واحد، الحلق ثلاثة، اللسان عشرة، الشفتان
    // مخرجان، الخيشوم واحد — والمجموع سبعة عشر.
    const expected = {
      MakhrajRegion.jawf: 1,
      MakhrajRegion.halq: 3,
      MakhrajRegion.lisan: 10,
      MakhrajRegion.shafatan: 2,
      MakhrajRegion.khayshum: 1,
    };
    for (final entry in expected.entries) {
      final count = makharij.where((m) => m.region == entry.key).length;
      expect(count, entry.value, reason: '${entry.key}');
    }
  });

  test('the letters come to the tally the matn enumerates', () {
    for (final entry in makharijLetterCountByRegion.entries) {
      final letters = makharij
          .where((m) => m.region == entry.key)
          .expand((m) => m.letters)
          .length;
      expect(letters, entry.value,
          reason: '${entry.key}: the book says ${entry.value}');
    }
    // 3 + 6 + 18 + 4 = 31. الخيشوم is deliberately outside the tally: what
    // leaves it is الغنة, which is a sound, not one of the hija' letters —
    // and the matn names it that way, «وَغُنَّةٌ: مَخْرَجُهَا الخَيْشُومُ».
    final tallied = makharijLetterCountByRegion.values.reduce((a, b) => a + b);
    expect(tallied, 31);
  });

  test('every makhraj is answerable: a place, letters, and a page', () {
    final ids = <String>{};
    for (final m in makharij) {
      expect(m.id.trim(), isNotEmpty);
      expect(ids.add(m.id), isTrue, reason: 'duplicate id ${m.id}');
      expect(m.place.trim(), isNotEmpty, reason: m.id);
      // The quotation is the whole point of the entry: without it the place
      // is the app's own wording with nothing behind it.
      expect(m.matn.trim(), isNotEmpty, reason: m.id);
      expect(m.letters, isNotEmpty, reason: m.id);
      for (final l in m.letters) {
        expect(l.trim(), isNotEmpty, reason: m.id);
      }
      // في معرفة مخارج الحروف runs from printed 56 to 58 in the printing
      // this app hosts, and the whole chapter is on those three pages.
      expect(m.page, inInclusiveRange(56, 58), reason: m.id);
    }
  });

  test('the makharij are walked in the book’s order, region by region', () {
    // الجوف ثم الحلق ثم اللسان ثم الشفتان ثم الخيشوم — the order the matn
    // itself walks, مذهب الخليل بن أحمد واختيار الناظم. A shuffled list
    // would teach the mouth in the wrong direction.
    final order = makharij.map((m) => m.region).toList();
    final seen = <MakhrajRegion>[];
    for (final r in order) {
      if (seen.isEmpty || seen.last != r) {
        expect(seen.contains(r), isFalse,
            reason: '$r is split into two runs');
        seen.add(r);
      }
    }
    expect(seen, MakhrajRegion.values);
  });

  test('the source is named, with the edition and the pages', () {
    expect(makharijSourceLabel, contains('المقدمة الجزرية'));
    expect(makharijSourceLabel, contains('ابن الجزري'));
    expect(makharijSourceLabel, contains('٥٦'));
    // And nothing of the book that was taken out for copyright reasons.
    expect(makharijSourceLabel, isNot(contains('غاية المريد')));
    for (final m in makharij) {
      expect(m.place, isNot(contains('غاية')), reason: m.id);
    }
  });

  test('every makhraj has a movement, and a tongue one has a contact point',
      () {
    // The diagram shows articulation, not a dot. A makhraj with no spec would
    // silently render as a mouth that does nothing — which is precisely the
    // complaint the movement was built to answer.
    for (final m in makharij) {
      final spec = articulationByMakhraj[m.id];
      expect(spec, isNotNull, reason: '${m.id} has no articulation');
      if (spec!.articulator == Articulator.tongue) {
        expect(spec.contactX, isNotNull,
            reason: '${m.id} moves the tongue but names no contact point');
        expect(spec.contactX, inInclusiveRange(0.0, 1.0), reason: m.id);
      }
      expect(spec.closure, inInclusiveRange(0.0, 1.0), reason: m.id);
    }
  });

  test('no articulation is described for a makhraj that does not exist', () {
    final ids = makharij.map((m) => m.id).toSet();
    for (final key in articulationByMakhraj.keys) {
      expect(ids, contains(key), reason: '$key is not a makhraj');
    }
  });

  test('the ghunnah letters send their air out through the nose', () {
    // الخيشوم is where الغنة leaves, and النون المظهرة carries one.
    expect(articulationByMakhraj['khayshum']!.air, AirPath.outNose);
    expect(articulationByMakhraj['lisan_taraf_nun']!.air, AirPath.outNose);
    // حروف المد close nothing at all.
    expect(articulationByMakhraj['jawf']!.articulator, Articulator.open);
    expect(articulationByMakhraj['jawf']!.air, AirPath.outMouth);
    // «ما بين الشفتين معًا، مع انطباق» — the lips shut.
    expect(articulationByMakhraj['shafa_bmw']!.articulator, Articulator.lips);
    expect(articulationByMakhraj['shafa_bmw']!.air, AirPath.blocked);
    // «بطن الشَّفة السفلى مع أطراف الثنايا العليا».
    expect(articulationByMakhraj['shafa_fa']!.articulator,
        Articulator.lipToTeeth);
  });
}
