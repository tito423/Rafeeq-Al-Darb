import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/articulation.dart';
import 'package:rafeeq_app/features/tajweed/data/makharij.dart';

/// The makharij data is a claim about a book, and this is what checks it.
///
/// «غاية المريد» states its own arithmetic on p.131: «أما عند مخارج الحروف
/// فيكون عددها واحدًا وثلاثين حرفًا. فالجوف يخرج منه ثلاثة أحرف، والحلق ستة،
/// واللسان ثمانية عشر، والشفتان أربعة» — and on p.127 it settles the count of
/// makharij at seventeen. So the data is not graded against my reading of it;
/// it is graded against numbers the book prints, which is the only kind of
/// check worth having here.
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
    // p.127-130: الجوف واحد، الحلق ثلاثة، اللسان عشرة، الشفتان مخرجان،
    // الخيشوم واحد.
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

  test('the letters come to the tally printed on p.131', () {
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
    // the book counts it that way too.
    final tallied = makharijLetterCountByRegion.values.reduce((a, b) => a + b);
    expect(tallied, 31);
  });

  test('every makhraj is answerable: a place, letters, and a page', () {
    final ids = <String>{};
    for (final m in makharij) {
      expect(m.id.trim(), isNotEmpty);
      expect(ids.add(m.id), isTrue, reason: 'duplicate id ${m.id}');
      expect(m.place.trim(), isNotEmpty, reason: m.id);
      expect(m.letters, isNotEmpty, reason: m.id);
      for (final l in m.letters) {
        expect(l.trim(), isNotEmpty, reason: m.id);
      }
      // The pages the chapter actually occupies in that printing.
      expect(m.page, inInclusiveRange(126, 131), reason: m.id);
    }
  });

  test('the makharij are walked in the book’s order, region by region', () {
    // الجوف ثم الحلق ثم اللسان ثم الشفتان ثم الخيشوم — the arrangement the
    // book attributes to الخليل بن أحمد and ابن الجزري. A shuffled list would
    // teach the mouth in the wrong direction.
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
    expect(makharijSourceLabel, contains('غاية المريد'));
    expect(makharijSourceLabel, contains('عطية قابل نصر'));
    expect(makharijSourceLabel, contains('١٢٦'));
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
