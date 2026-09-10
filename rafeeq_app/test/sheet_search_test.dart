import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

/// «أضف بحث في أيقونة السور والأجزاء».
///
/// The matching rule the sheets use, held here because the sheets themselves
/// are `showModalBottomSheet` functions and the rule is the part worth
/// pinning: the stored surah names are fully vocalised, so a plainly typed
/// query cannot reach them with a `contains` (trap #2).
bool rowMatches(String query, String name, int number) {
  final q = normalizeArabic(query.trim()).toLowerCase();
  if (q.isEmpty) return true;
  if ('$number'.startsWith(q)) return true;
  final n = normalizeArabic(name).toLowerCase();
  return n.contains(q) || normalizeArabicLoose(name).toLowerCase().contains(q);
}

void main() {
  // As stored in quran_local.db — vocalised, with the alef wasla.
  const alFatiha = 'سُورَةُ ٱلْفَاتِحَة';
  const alBaqara = 'سُورَةُ ٱلْبَقَرَة';
  const yaSin = 'سُورَةُ يس';

  test('a plainly typed name reaches a vocalised one', () {
    expect(rowMatches('الفاتحة', alFatiha, 1), isTrue);
    expect(rowMatches('فاتحة', alFatiha, 1), isTrue);
    expect(rowMatches('البقرة', alBaqara, 2), isTrue);
  });

  test('a fragment from the middle works — this is a list, not a corpus', () {
    // Someone typing «قرة» wants البقرة. A word-boundary rule would refuse.
    expect(rowMatches('قرة', alBaqara, 2), isTrue);
  });

  test('the number is searchable too', () {
    expect(rowMatches('36', yaSin, 36), isTrue);
    expect(rowMatches('3', yaSin, 36), isTrue);
    expect(rowMatches('7', yaSin, 36), isFalse);
  });

  test('an empty query shows everything', () {
    expect(rowMatches('', alFatiha, 1), isTrue);
    expect(rowMatches('   ', alBaqara, 2), isTrue);
  });

  test('a name that does not match is filtered out', () {
    expect(rowMatches('الكهف', alFatiha, 1), isFalse);
  });
}
