import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';

/// `QuranScreen` and `HomeScreen` are siblings kept alive together in
/// `AppShell`'s `IndexedStack` — there's no push/pop relationship between
/// them for a "jump to page X then switch tabs" request (e.g. a khatma
/// card's "اقرأ اليوم") to ride on the way `SearchScreen`'s `Navigator.pop`
/// does. This is that seam instead: whoever wants the reader open on a
/// specific page sets this, then switches to the Quran tab; `QuranScreen`
/// consumes it via `ref.listen` and resets it to null so it only fires once.
final quranJumpRequestProvider = StateProvider<int?>((ref) => null);

/// The verse the reader last opened BY NAME — a surah picked in the jump
/// sheet, or «افتح سورة يس» said to Rafeeq — and the page it sits on.
///
/// Continuous recitation starts from here while that page is still open.
/// Without it the play button began at the top of the page: the owner opened
/// Ya-Sin (page 440), pressed it, and heard the end of Fatir first
/// (2026-09-30, on his phone, v3.72.0).
/// [mark]: the verse was asked for, so it is marked and brought on screen;
/// [card]: its card opened on that tab (0 tafsir, 1 translation, 2 i'rab).
typedef OpenedAyah = ({int surah, int ayah, int page, bool mark, int? card});

final quranOpenedAyahProvider = StateProvider<OpenedAyah?>((ref) => null);

/// Opens the mushaf on [a]'s page with [a] as the opened verse — for callers
/// outside the widget tree (Rafeeq), which hold a [ProviderContainer].
void requestQuranAyah(ProviderContainer c, Ayah a,
    {bool mark = false, int? card}) {
  c.read(quranOpenedAyahProvider.notifier).state = (
    surah: a.surahId,
    ayah: a.ayahNumber,
    page: a.pageNumber,
    mark: mark,
    card: card,
  );
  c.read(quranJumpRequestProvider.notifier).state = a.pageNumber;
}
