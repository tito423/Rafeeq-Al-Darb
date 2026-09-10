import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/page_surahs.dart';

/// The owner photographed the Qur'an screen showing the close of Surah Hud
/// with «سورة يوسف» in the running header. This pins the rule that fixes it.
///
/// The page numbers here are the Madinah mushaf's own: Hud opens on 221 and
/// Yusuf on 235, so page 235 carries the end of one and the start of the
/// other — exactly the case the old rule got wrong, and the case that occurs
/// at most surah boundaries in the mushaf rather than rarely.
Surah _s(int id, String name) => Surah(
      id: id,
      nameAr: name,
      nameEn: '',
      revelationType: '',
      ayahsCount: 1,
    );

void main() {
  final surahs = [
    _s(10, 'يُونُس'),
    _s(11, 'هُود'),
    _s(12, 'يُوسُف'),
    _s(13, 'الرَّعْد'),
  ];
  const starts = {10: 208, 11: 221, 12: 235, 13: 249};

  List<String> at(int page) =>
      surahNamesOnPage(surahs: surahs, startPages: starts, page: page);

  test('a page where one surah ends and another begins names both', () {
    // This is the reported page. The old rule returned ['يُوسُف'] alone.
    expect(at(235), ['هُود', 'يُوسُف']);
  });

  test('a page inside one surah names only that surah', () {
    expect(at(230), ['هُود']);
    expect(at(240), ['يُوسُف']);
  });

  test('the opening page of a surah still carries the previous one', () {
    // Written expecting ['هُود'] and corrected by the run: Hud opens on
    // 221, which means 221 also holds the last verses of Yunus. Naming only
    // Hud there would be the same defect as the reported one, mirrored.
    expect(at(221), ['يُونُس', 'هُود']);
  });

  test('the boundary belongs to both pages, not to the later one only', () {
    // 249 is where ar-Ra'd opens, so Yusuf's last verses share it.
    expect(at(249), ['يُوسُف', 'الرَّعْد']);
    expect(at(248), ['يُوسُف']);
  });

  test('the last surah in the list has no successor to bound it', () {
    expect(at(1000), ['الرَّعْد']);
  });

  test('a page before any recorded start still names something', () {
    expect(at(1), ['يُونُس']);
    expect(
      surahNamesOnPage(surahs: const [], startPages: const {}, page: 5),
      isEmpty,
    );
  });
}
