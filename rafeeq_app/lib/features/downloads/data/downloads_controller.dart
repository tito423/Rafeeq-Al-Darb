import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quran_audio/data/quran_audio_library.dart';
import '../../../core/services/download_manager.dart';
import '../../../core/services/mushaf_page_service.dart';
import '../../quran/data/mushaf_edition.dart';

/// P2‑5 — a read-only aggregator over every place the app stores downloaded
/// content, so the Downloads hub can show one storage picture and free space
/// per category. It does **not** own the downloads: each service keeps its own
/// engine (`MushafPageService`, `AyahAudioService`, `DownloadManager`); this
/// only observes them and delegates "free space" back to the owner.
/// The buckets the Downloads hub counts and can free.
///
/// There used to be a sixth, `adhan`. The clips it counted were deleted from
/// the app in 3.19 and `DownloadManager.purgeAdhanVideos()` frees whatever a
/// phone still held, once, on the first launch after that - so the row had
/// nothing left to show and nothing left to do. The owner put it plainly:
/// «شيل الاذان من التنزيلات مالوش لازمة». Its two manager categories are
/// swept by `freeAllStorage` below so no orphaned bytes are left uncounted.
enum DownloadCategory { mushafs, recitations, hadith, books }

extension DownloadCategoryX on DownloadCategory {
  String get labelKey => switch (this) {
        DownloadCategory.mushafs => 'downloads.cat_mushafs',
        DownloadCategory.recitations => 'downloads.cat_recitations',
        DownloadCategory.hadith => 'downloads.cat_hadith',
        DownloadCategory.books => 'downloads.cat_books',
      };

  /// [DownloadManager] `category` string(s) that map to this bucket.
  ///
  /// **Every** string any screen passes as `DownloadManager.enqueue(category:)`
  /// has to appear here, or that download becomes invisible: it occupies disk
  /// and the storage hub neither counts it nor can free it. That is exactly
  /// what happened to `hadeethenc` (the per-language hadith packs, ~1-4 MB
  /// each) and `ruqyah` (audio, tens of MB) — both shipped enqueueing under a
  /// category no bucket claimed. `downloads_categories_test.dart` reads the
  /// enqueue sites out of `lib/` and fails if a new one is unclaimed.
  ///
  /// `mushafs` and `recitations` also hold content of their own outside
  /// DownloadManager (MushafPageService / QuranAudioLibrary); for those two the
  /// two sources are added together below.
  List<String> get managerCategories => switch (this) {
        DownloadCategory.mushafs => const [],
        DownloadCategory.recitations => const ['ruqyah'],
        DownloadCategory.hadith => const ['hadith'],
        DownloadCategory.books => const ['books', 'books_text'],
      };
}

class CategoryUsage {
  final DownloadCategory category;
  final int bytes;
  final int itemCount;
  const CategoryUsage(this.category, this.bytes, this.itemCount);
}

class StorageSummary {
  final List<CategoryUsage> categories;

  /// One entry per bucket, enforced. A category listed twice reads as a
  /// plausible screen — the row shows the first entry's size while the
  /// "Storage used" total silently doubles it. That shipped for one build of
  /// this file: 348.1 MB of mushaf pages, one row, and a headline of 696.2 MB.
  StorageSummary(this.categories)
      : assert(
          categories.map((c) => c.category).toSet().length ==
              categories.length,
          'a category is listed twice; totalBytes would double-count it',
        );

  int get totalBytes =>
      categories.fold(0, (sum, c) => sum + c.bytes);
  int get totalItems =>
      categories.fold(0, (sum, c) => sum + c.itemCount);

  CategoryUsage usage(DownloadCategory c) => categories.firstWhere(
        (u) => u.category == c,
        orElse: () => CategoryUsage(c, 0, 0),
      );
}

/// Recomputed on demand (invalidate it after a download finishes or a
/// "free space" action).
final storageSummaryProvider = FutureProvider<StorageSummary>((ref) async {
  final out = <CategoryUsage>[];

  // ── Mushafs (MushafPageService, one cache dir per edition) ──
  final editions = await ref.watch(mushafEditionsProvider.future);
  var mushafBytes = 0;
  var mushafItems = 0;
  for (final e in editions) {
    final b = await MushafPageService.instance.cacheSizeBytes(e.id);
    if (b > 0) {
      mushafBytes += b;
      mushafItems++;
    }
  }
  // ── Recitations («تحميل تلاوات القرآن»: whole surahs + imported files) ──
  final library = QuranAudioLibrary.instance;
  await library.ensureReady();
  final (reciteBytes, reciteItems) = await library.usage();
  // ── DownloadManager artifacts, folded into whichever bucket claims them ──
  // Ruqyah audio lands in `recitations` on top of the per-reciter caches, so
  // the loop covers every bucket rather than only the three that have no
  // service of their own.
  final artifacts = await DownloadManager.instance.registeredArtifacts();
  for (final cat in DownloadCategory.values) {
    final ids = artifacts
        .where((a) => cat.managerCategories.contains(a['category']))
        .map((a) => a['id'] as String)
        .toList();
    var bytes = 0;
    for (final id in ids) {
      bytes += await DownloadManager.instance.artifactSize(id);
    }
    if (cat == DownloadCategory.mushafs) {
      out.add(CategoryUsage(cat, mushafBytes + bytes, mushafItems + ids.length));
    } else if (cat == DownloadCategory.recitations) {
      out.add(CategoryUsage(cat, reciteBytes + bytes, reciteItems + ids.length));
    } else {
      out.add(CategoryUsage(cat, bytes, ids.length));
    }
  }

  return StorageSummary(out);
});

/// Free every byte in [category] and refresh the summary.
Future<void> freeCategory(WidgetRef ref, DownloadCategory category) async {
  switch (category) {
    case DownloadCategory.mushafs:
      final editions = await ref.read(mushafEditionsProvider.future);
      for (final e in editions) {
        await MushafPageService.instance.clearCache(e.id);
      }
    case DownloadCategory.recitations:
      await QuranAudioLibrary.instance.freeAll();
    case DownloadCategory.hadith:
    case DownloadCategory.books:
      break;
  }
  // Whatever the bucket also owns in DownloadManager goes with it — for
  // `recitations` that is the ruqyah audio, which the per-reciter caches above
  // know nothing about.
  final artifacts = await DownloadManager.instance.registeredArtifacts();
  for (final a in artifacts) {
    if (category.managerCategories.contains(a['category'])) {
      await DownloadManager.instance.remove(a['id'] as String);
    }
  }
  ref.invalidate(storageSummaryProvider);
}
