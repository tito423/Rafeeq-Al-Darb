import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran_audio/data/ayah_recitation_library.dart';

/// The per-ayah download library decides which files exist from its own
/// table of ayah counts. That table was wrong from surah 108 on, and the
/// owner's phone showed every error: a reciter stuck at 6,232 / 6,236,
/// an-Nasr «٣ / ٦», an-Nas «٦ / ٨», al-Kafirun «complete» at 3 of 6.
///
/// The expected values below were read out of the bundled
/// `assets/data/quran_local.db` on 2026-09-22 — `COUNT(*)` of `ayahs` per
/// `surah_id`, which matched that database's own `surahs.ayahs_count` for
/// all 114 and summed to 6,236. The database is gitignored, so its answer
/// is pinned here rather than read at test time.
void main() {
  const expected = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, //
    123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
    34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
    60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
    28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
    15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
    5, 4, 5, 6,
  ];

  test('every surah has the Hafs ayah count', () {
    expect(expected.length, 114);
    for (var s = 1; s <= 114; s++) {
      expect(AyahRecitationLibrary.ayahCount(s), expected[s - 1],
          reason: 'surah $s');
    }
    expect(AyahRecitationLibrary.ayahCount(0), 0);
    expect(AyahRecitationLibrary.ayahCount(115), 0);
  });

  test('the counts add up to the total the progress bar divides by', () {
    var sum = 0;
    for (var s = 1; s <= 114; s++) {
      sum += AyahRecitationLibrary.ayahCount(s);
    }
    expect(sum, AyahRecitationLibrary.totalAyahs);
    expect(sum, 6236);
  });
}
