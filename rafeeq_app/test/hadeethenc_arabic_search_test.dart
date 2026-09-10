import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The "find this hadith's explanation" flow searches with an **Arabic** matn
/// lifted from the nine books. It has to match against Arabic.
///
/// `HadeethEncRepository.search` matches the pack's `search` column, and in a
/// non-Arabic pack that column holds the **translation** — measured in the
/// real `hadeethenc_en.db`, row 3377's `search` begins
/// «‘umar (may allah be pleased with him) used to make me sit with…» while its
/// `hadeeth_ar` begins «عن عبد الله ابن عباس رضي الله عنهما…». An Arabic query
/// against the English column can never match, so the screen said «Nothing
/// close to its wording was found» to every reader whose app was not in
/// Arabic: six of the seven locales, seen on emulator-5554.
///
/// `searchArabic` reads `hadeeth_ar`, which every pack carries whatever its
/// language. These tests hold that in place at the source level, because the
/// packs themselves are built artefacts and not in the repository.
void main() {
  final repo = File('lib/core/db/hadeethenc_repository.dart').readAsStringSync();
  final screen = File(
    'lib/features/library/presentation/screens/hadith_explanation_screen.dart',
  ).readAsStringSync();

  test('the explanation screen searches the Arabic column', () {
    expect(screen.contains('repo.searchArabic('), isTrue,
        reason: 'an Arabic matn searched against a translated column matches '
            'nothing in six of the seven locales');
    expect(
      RegExp(r'repo\.search\(').hasMatch(screen),
      isFalse,
      reason: 'this is the call that only worked in Arabic',
    );
  });

  test('searchArabic reads hadeeth_ar, which every pack carries', () {
    final body = repo.substring(repo.indexOf('Future<List<HadeethItem>> '
        'searchArabic'));
    final end = body.indexOf('\n  }');
    final method = body.substring(0, end);
    expect(method.contains("'hadeeth_ar'"), isTrue);
    // Trap #2: the stored Arabic is fully diacritised, so the query and the
    // haystack both have to be normalised — a plain contains() would fail.
    expect(method.contains('normalizeArabic('), isTrue);
    expect(method.contains('wordBoundaryContains('), isTrue);
    // Trap #4: never load the corpus in one query.
    expect(method.contains('offset'), isTrue);
  });

  test('the localised search is still there for the encyclopaedia tab', () {
    // The tab's own search box searches what the reader is reading, which is
    // the translation — that one is correct as it is and must not be
    // "fixed" into the Arabic path.
    expect(repo.contains('Future<List<HadeethItem>> search(String query'),
        isTrue);
  });
}
