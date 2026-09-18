import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/core/services/surah_playlist.dart';

/// The basmala is recited before verse 1 of every surah but al-Fatiha and
/// at-Tawba, under verse 1's highlight.
void main() {
  List<Ayah> surah(int id, int n) => [
        for (var i = 1; i <= n; i++)
          Ayah.fromRow({
            'id': i,
            'surah_id': id,
            'ayah_number': i,
            'text': 'x',
            'page_number': 1,
            'juz_number': 1,
          }),
      ];

  test('Maryam from verse 1: basmala first, then verse 1', () {
    final p = SurahPlaylist.plan(surah(19, 98), 19, 1);
    expect(p.basmala, isTrue);
    expect(p.ayahs.length, 99);
    expect(p.initialIndex, 0);
    expect(p.isBasmalaAt(0), isTrue);
    expect(p.ayahs[0].ayahNumber, 1);
    expect(p.ayahs[1].ayahNumber, 1);
  });

  test('Maryam from verse 5 skips the basmala', () {
    final p = SurahPlaylist.plan(surah(19, 98), 19, 5);
    expect(p.ayahs[p.initialIndex].ayahNumber, 5);
    expect(p.isBasmalaAt(p.initialIndex), isFalse);
  });

  test('al-Fatiha and at-Tawba get none', () {
    for (final id in [1, 9]) {
      final p = SurahPlaylist.plan(surah(id, 7), id, 1);
      expect(p.basmala, isFalse, reason: '$id');
      expect(p.ayahs.length, 7);
      expect(p.lead, 0);
    }
  });
}
