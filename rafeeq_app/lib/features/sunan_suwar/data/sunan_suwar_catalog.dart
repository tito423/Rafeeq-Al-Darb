/// The 4 surahs P2‑12 lists — real Quranic surah ids only, page ranges
/// resolved at runtime from `mushafDataProvider.surahStartPages` (never
/// hardcoded — the exact reason is honesty: a hardcoded page boundary could
/// silently drift from the bundled `quran_local.db` and lock the reader out
/// of real ayahs).
///
/// Each virtue note below is a short paraphrase of one specific, named,
/// authenticated hadith — never an invented fadl (§3 rule). Sources:
///  • al-Baqarah: "اقرءوا سورة البقرة فإن أخذها بركة وتركها حسرة" +
///    "لا تجعلوا بيوتكم مقابر، إن الشيطان ينفر من البيت الذي تُقرأ فيه
///    سورة البقرة" — Sahih Muslim.
///  • al-Kahf: "من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين
///    الجمعتين" — al-Hakim/al-Bayhaqi, graded sahih by al-Albani; and
///    "من حفظ عشر آيات من أول سورة الكهف عُصم من الدجال" — Sahih Muslim.
///  • al-Mulk: "سورة من القرآن ثلاثون آية شفعت لصاحبها حتى غُفر له، وهي
///    سورة تبارك" — Sunan Abi Dawud/al-Tirmidhi (hasan).
///  • as-Sajdah: the Prophet ﷺ used to recite it (with al-Insan) in the
///    Fajr prayer on Friday — Sahih al-Bukhari. No "before sleep" claim is
///    made for it here — that practice is authenticated for al-Mulk alone,
///    not the pair, and this project doesn't repeat an unsourced pairing.
class SunanSurah {
  final int surahId;
  final String virtueNoteKey; // translation key under sunan_suwar.*
  final String sourceKey; // translation key naming the hadith source
  const SunanSurah(this.surahId, this.virtueNoteKey, this.sourceKey);
}

const List<SunanSurah> sunanSuwarCatalog = [
  SunanSurah(2, 'sunan_suwar.note_baqarah', 'sunan_suwar.source_baqarah'),
  SunanSurah(18, 'sunan_suwar.note_kahf', 'sunan_suwar.source_kahf'),
  SunanSurah(67, 'sunan_suwar.note_mulk', 'sunan_suwar.source_mulk'),
  SunanSurah(32, 'sunan_suwar.note_sajdah', 'sunan_suwar.source_sajdah'),
];
