import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/models.dart';
import 'package:rafeeq_app/features/quran/data/page_surahs.dart';

/// The running header of the Qur'an screen, pinned on real Madinah page
/// numbers read out of `quran_local.db` (MIN/MAX `page_number` per surah):
///
///     10 يونس   208–221      11 هود    221–235
///     12 يوسف   235–248      13 الرعد  249–255
///     14 إبراهيم 255–261     112–114   604–604
///
/// Two photographs from the owner are behind it: «سورة يوسف» over the close of
/// Hud on page 235, and «سورة الرعد سورة يوسف» on a page that is al-Ra'd alone.
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
    _s(14, 'إِبْرَاهِيم'),
    _s(112, 'الإِخْلَاص'),
    _s(113, 'الفَلَق'),
    _s(114, 'النَّاس'),
  ];
  const starts = {10: 208, 11: 221, 12: 235, 13: 249, 14: 255, 112: 604, 113: 604, 114: 604};
  const ends = {10: 221, 11: 235, 12: 248, 13: 255, 14: 261, 112: 604, 113: 604, 114: 604};

  List<String> at(int page) => surahNamesOnPage(
      surahs: surahs, startPages: starts, endPages: ends, page: page);

  test('a page where one surah ends and another begins names both', () {
    expect(at(235), ['هُود', 'يُوسُف']);
    expect(at(221), ['يُونُس', 'هُود']);
    expect(at(255), ['الرَّعْد', 'إِبْرَاهِيم']);
  });

  test('a surah that opens a clean page does not drag the previous one in', () {
    // The reported page: Yusuf's last verse is on 248, al-Ra'd opens 249.
    // The previous rule returned ['يُوسُف', 'الرَّعْد'].
    expect(at(249), ['الرَّعْد']);
    expect(at(248), ['يُوسُف']);
  });

  test('a page inside one surah names only that surah', () {
    expect(at(230), ['هُود']);
    expect(at(240), ['يُوسُف']);
  });

  test('three surahs on one page are all named', () {
    expect(at(604), ['الإِخْلَاص', 'الفَلَق', 'النَّاس']);
  });

  test('a page with no data still names something', () {
    expect(at(1), ['يُونُس']);
    expect(
      surahNamesOnPage(
          surahs: const [], startPages: const {}, endPages: const {}, page: 5),
      isEmpty,
    );
  });
}
