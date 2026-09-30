import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/continuous_start.dart';

Ayah _a(int surah, int n) => Ayah(
      id: surah * 1000 + n,
      surahId: surah,
      ayahNumber: n,
      textUthmani: '',
      pageNumber: 440,
      juzNumber: 22,
    );

void main() {
  // Page 440 as quran_local.db has it: Fatir 45, then Ya-Sin 1-12.
  final page440 = [
    _a(35, 45),
    for (var n = 1; n <= 12; n++) _a(36, n),
  ];

  test('opening Ya-Sin by name starts at Ya-Sin 1, not the end of Fatir', () {
    final s = continuousStartOnPage(page440,
        page: 440, opened: (surah: 36, ayah: 1, page: 440, mark: false, card: null));
    expect((s.surahId, s.ayahNumber), (36, 1));
  });

  test('a selected verse wins over the opened surah', () {
    final s = continuousStartOnPage(page440,
        page: 440,
        selectedSurah: 35,
        selectedAyah: 45,
        opened: (surah: 36, ayah: 1, page: 440, mark: false, card: null));
    expect((s.surahId, s.ayahNumber), (35, 45));
  });

  test('an opened verse on another page is ignored', () {
    final s = continuousStartOnPage(page440,
        page: 440, opened: (surah: 36, ayah: 1, page: 441, mark: false, card: null));
    expect((s.surahId, s.ayahNumber), (35, 45));
  });

  test('nothing opened or selected: the top of the page', () {
    final s = continuousStartOnPage(page440, page: 440);
    expect((s.surahId, s.ayahNumber), (35, 45));
  });
}
