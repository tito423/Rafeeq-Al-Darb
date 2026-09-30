import '../../../core/db/models.dart';
import 'quran_jump_provider.dart';

/// Where continuous recitation begins on [page], whose verses are [ayahs].
///
/// In order: the verse the reader has selected; the verse opened by name
/// ([opened]) if it is on this page; otherwise the page's first verse.
Ayah continuousStartOnPage(
  List<Ayah> ayahs, {
  required int page,
  int? selectedSurah,
  int? selectedAyah,
  OpenedAyah? opened,
}) {
  for (final a in ayahs) {
    if (a.surahId == selectedSurah && a.ayahNumber == selectedAyah) return a;
  }
  if (opened != null && opened.page == page) {
    for (final a in ayahs) {
      if (a.surahId == opened.surah && a.ayahNumber == opened.ayah) return a;
    }
  }
  return ayahs.first;
}
