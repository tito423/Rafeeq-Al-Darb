/// The kids' corner as a graded path, from nursery to the whole Qur'an
/// (owner, 2026-09-29: «متدرج من الحضانة لحد ١٣ أو ١٤ سنة … من أول جزء عم لحد
/// نص القرآن»; 2026-09-30: «كمل للقران كله … ٣ مراحل … يغطوا لاخر القران»).
///
/// Built on what children's Qur'an programmes recommend (checked online on
/// 2026-09-29, furqan.academy and others): start between 4 and 6, begin with
/// the short surahs for a quick sense of achievement, quality before quantity,
/// daily listening, repetition, review before new material, and a reward at
/// the end of every surah. So the path runs from the end of the mushaf
/// backwards, juz by juz - Juz ʿAmma, Juz Tabārak, Juz 28 and 27 - to the
/// first surah that opens inside Juz 16 (Maryam), where the second half of
/// the Qur'an begins. Within a stage the surahs follow the mushaf backwards
/// (only al-Fātiḥah is placed first); that is broadly short to long but not
/// strictly - adh-Dhāriyāt (60 ayahs) comes before Qāf (45).
///
/// The juz ranges below are checked against `quran_local.db` by
/// `test/kids_stages_test.dart`.
class KidsStage {
  /// `kids.stage_<id>`, `kids.stage_<id>_ages`.
  final String id;

  /// Surah numbers in the order the child learns them.
  final List<int> surahs;

  /// The juz the stage's surahs open in (inclusive; [juzHigh] >= [juzLow]).
  final int juzHigh;
  final int juzLow;

  /// ARGB of the stage's colour.
  final int color;

  const KidsStage(this.id, this.surahs, this.juzHigh, this.juzLow, this.color);
}

List<int> _desc(int from, int to) => [for (var s = from; s >= to; s--) s];

final kidsStages = <KidsStage>[
  // Nursery, 3-5: al-Fātiḥah and the ten shortest surahs.
  KidsStage('buds', [1, ..._desc(114, 105)], 30, 30, 0xFFF79F1F),
  // 6-7: the rest of Juz ʿAmma.
  KidsStage('cubs', _desc(104, 78), 30, 30, 0xFF10AC84),
  // 8-9: Juz Tabārak.
  KidsStage('knights', _desc(77, 67), 29, 29, 0xFF2E86DE),
  // 10-11: Juz 28 and 27 (at-Tūr opens Juz 27; adh-Dhāriyāt opens in 26,
  // which the stages test caught when it was placed here).
  KidsStage('stars', _desc(66, 52), 28, 27, 0xFF8854D0),
  // 12-14: adh-Dhāriyāt back to the surahs that open in Juz 16 - half the
  // Qur'an. «طلائع الحفّاظ» (was «الحفّاظ»; the owner offered «أشبال الحفاظ»,
  // but «الأشبال» is already the second stage).
  KidsStage('hafiz', _desc(51, 19), 26, 16, 0xFFEE5253),
  // The second half, in three stages of about five juz each (boundaries
  // from quran_local.db: al-Kahf opens Juz 15, Yūnus 11, at-Tawbah 10,
  // al-Māʾidah 6, an-Nisāʾ 4, al-Baqarah 1).
  KidsStage('sabiqun', _desc(18, 10), 15, 11, 0xFF0ABDE3),
  KidsStage('hamala', _desc(9, 5), 10, 6, 0xFFB8860B),
  KidsStage('ahl', _desc(4, 2), 4, 1, 0xFF1E8449),
];
