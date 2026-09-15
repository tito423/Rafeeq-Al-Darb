import 'package:flutter_test/flutter_test.dart';
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
}
