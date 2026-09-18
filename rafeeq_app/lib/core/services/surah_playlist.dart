import '../db/models.dart';

/// One surah's continuous-recitation playlist, planned.
///
/// THE BASMALA. «بيظلل على بسم الله الرحمن الرحيم واللي بعدها مع إن القارئ
/// مش بيقول البسملة». The text of verse 1 carries the basmala in front of it,
/// so it was highlighted, but the verse-1 recording holds the verse alone. A
/// murattal reading opens every surah with the basmala — except al-Fatiha,
/// where it IS verse 1, and at-Tawba, which has none — so the reciter's own
/// basmala (his recording of 1:1) is played first, under verse 1's highlight.
/// [ayahs] then holds verse 1 twice: index 0 is the basmala, index 1 the
/// verse, and [lead] is 1.
class SurahPlaylist {
  final List<Ayah> ayahs;
  final int initialIndex;
  final bool basmala;

  const SurahPlaylist(this.ayahs, this.initialIndex, this.basmala);

  int get lead => basmala ? 1 : 0;

  /// Whether child [k] of the playlist is the basmala.
  bool isBasmalaAt(int k) => basmala && k == 0;

  factory SurahPlaylist.plan(List<Ayah> all, int surahId, int startAyahNumber) {
    final startIndex = all.indexWhere((a) => a.ayahNumber == startAyahNumber);
    final basmala = surahId != 1 && surahId != 9 && all.isNotEmpty;
    final ayahs = basmala ? [all.first, ...all] : all;
    // Starting at verse 1 starts on the basmala; anywhere later skips it.
    final initial = startIndex < 0
        ? 0
        : (basmala && startIndex > 0 ? startIndex + 1 : startIndex);
    return SurahPlaylist(ayahs, initial, basmala);
  }
}
