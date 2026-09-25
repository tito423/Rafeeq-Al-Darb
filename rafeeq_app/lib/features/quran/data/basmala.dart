import '../../../core/db/models.dart';
import '../../../core/utils/arabic_normalize.dart';

/// Splitting the basmala off the first verse of a surah, **for display only**.
///
/// The bundled `quran_local.db` stores the basmala as part of verse 1's text
/// for 112 surahs — `2:1` is «بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ الٓمٓ».
/// Two surahs are already right and must stay untouched: al-Fatiha, where the
/// basmala **is** verse 1 and counts as one, and at-Tawbah, which has none.
///
/// A printed mushaf sets the basmala on its own centred line under the surah
/// banner, above verse 1. Keeping it inside verse 1 also made the recitation
/// highlight cover basmala + verse 1 as one block while the reciter was only
/// sounding the basmala — «بيظلل على بسم الله الرحمن الرحيم واللي بعدها مع إن
/// القارئ مش بيقول البسملة».
///
/// Nothing here rewrites scripture: [basmalaOf] returns a **verbatim
/// substring** of the stored text and [bodyOf] returns the rest of it, so
/// whatever the source prints is what the screen prints. The *match* is made
/// on a diacritic-stripped copy, which is what lets it recognise the basmala
/// of al-Tin (95) and al-Qadr (97) — the two surahs whose stored text writes
/// «بِّسْمِ» with a shadda.

/// Al-Fatiha: its verse 1 **is** the basmala, and it is counted as a verse.
const int kAlFatiha = 1;

/// At-Tawbah: the one surah that carries no basmala at all.
const int kAtTawbah = 9;

/// The basmala's four words, diacritics stripped, as [normalizeArabicLoose]
/// renders them — the dagger alif of ٱلرَّحْمَٰنِ is dropped, not expanded,
/// which is why the third word is «الرحمن» and not «الرحمان».
const List<String> _basmalaWords = ['بسم', 'الله', 'الرحمن', 'الرحيم'];

/// The index just past the basmala in [text], or -1 when it does not open
/// with one. A verse consisting of nothing but the basmala is not split —
/// there has to be a verse left after it.
int _basmalaEnd(int surahId, int ayahNumber, String text) {
  if (ayahNumber != 1 || surahId == kAlFatiha || surahId == kAtTawbah) {
    return -1;
  }
  var from = 0;
  var end = -1;
  for (final word in _basmalaWords) {
    final space = text.indexOf(' ', from);
    if (space < 0) return -1;
    if (normalizeArabicLoose(text.substring(from, space)) != word) return -1;
    end = space;
    from = space + 1;
  }
  return end;
}

/// Al-Fatiha 1:1 as the King Fahd Complex text writes it - the basmala
/// every other surah but at-Tawbah opens with.
///
/// Since 2026-09-25 the ayah text is the Complex's (hafsData v18,
/// scripts/build_quran_text_kfgqpc.py), which - like the printed Madinah
/// mushaf - does not weld the basmala into verse 1 of each surah; Tanzil,
/// the previous source, did. The line under each banner is the source's
/// own 1:1, copied here codepoint by codepoint from the database.
const String kBasmala =
    '\u{628}\u{650}\u{633}\u{6E1}\u{645}\u{650} '
    '\u{671}\u{644}\u{644}\u{651}\u{64E}\u{647}\u{650} '
    '\u{671}\u{644}\u{631}\u{651}\u{64E}\u{62D}\u{6E1}\u{645}\u{64E}\u{670}\u{646}\u{650} '
    '\u{671}\u{644}\u{631}\u{651}\u{64E}\u{62D}\u{650}\u{64A}\u{645}\u{650}';

/// The basmala that opens [ayah]'s surah, or null when this verse is not
/// the first of a surah that has one. Taken from the verse itself when the
/// source writes it there, otherwise [kBasmala].
String? basmalaOf(Ayah ayah) {
  if (ayah.ayahNumber != 1 ||
      ayah.surahId == kAlFatiha ||
      ayah.surahId == kAtTawbah) {
    return null;
  }
  final end = _basmalaEnd(ayah.surahId, ayah.ayahNumber, ayah.textUthmani);
  return end < 0 ? kBasmala : ayah.textUthmani.substring(0, end);
}

/// [ayah]'s own text with any leading basmala taken off — the verse as it
/// should be read, highlighted and counted. Unchanged for every verse that
/// does not open a surah, so an-Naml 27:30, which quotes the basmala inside
/// the verse, is never touched.
String bodyOf(Ayah ayah) {
  final end = _basmalaEnd(ayah.surahId, ayah.ayahNumber, ayah.textUthmani);
  return end < 0 ? ayah.textUthmani : ayah.textUthmani.substring(end + 1);
}
