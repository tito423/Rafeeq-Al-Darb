import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quran_audio/data/quran_audio_library.dart';
import '../../quran_audio/data/ayah_recitation_library.dart';
import '../../../core/services/download_manager.dart';
import '../../../core/services/mushaf_page_service.dart';
import '../../quran/data/mushaf_edition.dart';
import '../../library/data/library_api_service.dart';
import '../../library/data/tts/open_voice.dart';
import '../../../core/db/db_helper.dart';
import '../../../core/db/sciences_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
///
/// `voices` is the book reader's open voice (~252 MB, `OpenVoice`): the
/// largest single download in the app, so it has to be visible here and
/// freeable, not only installable from the reader.
/// There is deliberately NO `hadith` bucket. «شيل الحديث خالص من التنزيلات»
/// (2026-09-21): the nine collections ship INSIDE the APK as
/// `assets/data/hadith.zip` and [installBundledHadith] unpacks them on first
/// open, so nothing about them is a download. The row could only ever say
/// «لا يوجد محتوى منزّل» (before the first open) or offer a «تفريغ» that
/// frees 109 MB the next open puts straight back from the asset bundle.
/// The one path that does hit the network — `hadith_tab.dart`'s gate, kept
/// for the case where unpacking the asset fails — enqueues under `hadith`,
/// which [DownloadCategory.books] claims, so those bytes stay countable and
/// freeable exactly as `downloads_categories_test.dart` requires.
enum DownloadCategory {
  mushafs,
  recitations,
  ayahRecitations,
  books,
  voices,
  /// علوم القرآن - the tafsir/translation/i'rab/word-meanings pack that
  /// left the APK in 3.45.0. 31.70 MB is worth a row of its own.
  quranSciences,
}

extension DownloadCategoryX on DownloadCategory {
  String get labelKey => switch (this) {
        DownloadCategory.mushafs => 'downloads.cat_mushafs',
        DownloadCategory.recitations => 'downloads.cat_recitations',
        DownloadCategory.ayahRecitations => 'downloads.cat_ayah_recitations',
        DownloadCategory.books => 'downloads.cat_books',
        DownloadCategory.voices => 'downloads.cat_voices',
        DownloadCategory.quranSciences => 'downloads.cat_quran_sciences',
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
        DownloadCategory.ayahRecitations => const [],
        // `hadith` rides here: see the note on the enum.
        DownloadCategory.books => const ['books', 'books_text', 'hadith'],
        DownloadCategory.voices => const ['tts_voice'],
        DownloadCategory.quranSciences => const ['sciences'],
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

/// Bytes of a database sitting in the app's `databases/` directory.
///
/// `quran_sciences.db` never has to have passed through `DownloadManager`:
/// an install that ADOPTED the copy an older build left there
/// (`_adoptBundledCopy`) downloaded nothing, so the artifact registry knows
/// nothing about it, and a row that counts only artifacts reports zero over
/// a hundred megabytes.
Future<int> downloadedDbBytes(String fileName) async {
  final support = await getApplicationSupportDirectory();
  final file = File(p.join(support.path, 'databases', fileName));
  return file.existsSync() ? file.lengthSync() : 0;
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
  // ── Per-ayah recitations (per-ayah files from everyayah.com) ──
  final ayahLib = AyahRecitationLibrary.instance;
  await ayahLib.ensureReady();
  final (ayahBytes, ayahItems) = await ayahLib.usage();
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
    } else if (cat == DownloadCategory.ayahRecitations) {
      out.add(CategoryUsage(cat, ayahBytes, ayahItems));
    } else if (cat == DownloadCategory.books) {
      // Library books are fetched by LibraryApiService, not DownloadManager,
      // so the manager artifacts alone left this row at «لا يوجد محتوى»
      // with a book on the device.
      final (bb, bn) = await LibraryApiService.instance.storageUsage();
      out.add(CategoryUsage(cat, bytes + bb, ids.length + bn));
    } else if (cat == DownloadCategory.quranSciences) {
      // Same hole, and it would have been the same bug: an install that
      // ADOPTED the old bundled copy (`_adoptBundledCopy`) never downloaded
      // anything either.
      final sb = await downloadedDbBytes('quran_sciences.db');
      out.add(CategoryUsage(cat, sb, sb > 0 ? 1 : 0));
    } else if (cat == DownloadCategory.voices) {
      final vb = await OpenVoice.usageBytes();
      out.add(CategoryUsage(cat, vb, vb > 0 ? 1 : 0));
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
    case DownloadCategory.ayahRecitations:
      await AyahRecitationLibrary.instance.freeAll();
    case DownloadCategory.voices:
      await OpenVoice.uninstall();
    case DownloadCategory.books:
      await LibraryApiService.instance.deleteAllBooks();
    case DownloadCategory.quranSciences:
      // Nothing outside DownloadManager: the pack IS the artifact, and
      // the loop below removes it. The ayah card reopens its download
      // gate on the next build because the provider then finds no file.
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
  if (category == DownloadCategory.quranSciences) {
    // The ayah card holds an open handle on the file that was just removed;
    // without this it keeps serving from it and never shows its gate again.
    await DbHelper.instance.deleteDownloaded('quran_sciences.db');
    ref.invalidate(sciencesRepositoryProvider);
  }
  ref.invalidate(storageSummaryProvider);
}
