import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app's surah→page and juz→page tables are the Madinah 604-page layout's.
/// Any printing that paginates its own way must declare `hafs_pagination:
/// false`, or the surah index will navigate to a page of a different surah —
/// the owner's «عدم اتساق بين اسم السورة اللي بختاره والسورة اللي بتطلع على
/// الشاشة فعليا».
///
/// The page count is the giveaway: a printing with 604 pages sets the Madinah
/// grid; one with 521, 564 or 611 cannot.
void main() {
  test('page count and the pagination flag agree, edition by edition', () {
    final doc = jsonDecode(
      File('assets/data/mushaf/editions.json').readAsStringSync(),
    );
    final list = (doc is Map<String, dynamic> ? doc['editions'] : doc) as List;
    expect(list, isNotEmpty);

    final wrong = <String>[];
    for (final e in list.cast<Map<String, dynamic>>()) {
      final pages = e['pages'] as int?;
      final hafs = e['hafs_pagination'] as bool? ?? true;
      if (pages == null) continue;
      if (pages != 604 && hafs) {
        wrong.add('${e['id']}: $pages pages but claims the Madinah layout — '
            'its surah index would land on the wrong surah');
      }
      if (pages == 604 && !hafs) {
        wrong.add('${e['id']}: 604 pages but the surah index is switched off '
            'for it, so navigation is withheld for no reason');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });
}
