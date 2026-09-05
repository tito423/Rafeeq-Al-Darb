import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../quran/data/mushaf_data_provider.dart';
import 'khatma_store.dart';

/// The real surah/ayah/page boundaries of a khatma's *today's portion* —
/// P3‑6's "من سورة ... آية ... صفحة ..." / "إلى ..." range, resolved from
/// the actual mushaf data (`ayahsOfPage`), never fabricated. Mirrors the
/// owner's real reference app screen
/// (`design_refs/khatma_app_ref/1_daily_wird_card.jpg`).
class KhatmaPortionRange {
  final Ayah start;
  final Ayah end;
  final int startPage;
  final int endPage;
  final int juz;

  const KhatmaPortionRange({
    required this.start,
    required this.end,
    required this.startPage,
    required this.endPage,
    required this.juz,
  });
}

/// Resolves today's due portion for [khatma] into real surah/ayah/page
/// boundaries. Returns null only when the mushaf data (or the ayah lists
/// for the pages in question) genuinely isn't available yet — callers
/// should treat that the same as "still loading", not render a fabricated
/// range.
Future<KhatmaPortionRange?> resolveKhatmaPortionRange(
  Khatma khatma,
  MushafData mushaf,
) async {
  final due = khatma.duePages(mushaf.juzStartPages, mushaf.rubElHizbPages);
  final startPage = khatma.currentPage;
  final endPage = (startPage + (due > 0 ? due - 1 : 0)).clamp(
    startPage,
    Khatma.totalPages,
  );

  final startAyahs = await mushaf.repo.ayahsOfPage(startPage);
  if (startAyahs.isEmpty) return null;
  final endAyahs = endPage == startPage
      ? startAyahs
      : await mushaf.repo.ayahsOfPage(endPage);
  if (endAyahs.isEmpty) return null;

  return KhatmaPortionRange(
    start: startAyahs.first,
    end: endAyahs.last,
    startPage: startPage,
    endPage: endPage,
    juz: startAyahs.first.juzNumber,
  );
}

/// Family-keyed by the exact `(Khatma, MushafData)` instances — `Khatma`
/// only ever changes identity via an explicit `copyWith` in `KhatmaStore`
/// (create/readToday/setReminder/restore), so between those operations the
/// same object reference persists in provider state and this family cache
/// hits, rather than flashing back to a loading state on unrelated rebuilds.
final khatmaPortionRangeProvider = FutureProvider.family
    .autoDispose<KhatmaPortionRange?, (Khatma, MushafData)>((ref, args) {
      return resolveKhatmaPortionRange(args.$1, args.$2);
    });
