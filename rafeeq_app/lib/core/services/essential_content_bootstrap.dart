import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/data/reciters_provider.dart';
import '../../features/quran/data/mushaf_data_provider.dart';
import '../../features/quran/data/mushaf_edition.dart';
import '../config/app_config.dart';
import '../db/hadith_repository.dart';
import '../services/ayah_audio_service.dart';
import '../services/download_manager.dart';
import '../services/mushaf_page_service.dart';

/// P3‑41: the owner's real-device feedback was explicit — the default
/// mushaf, the default recitation, and the hadith library should all be
/// there "out of the box", not behind a download button the user has to
/// find and tap during onboarding. True APK-embedded bundling (shipping
/// the actual page/audio/hadith files inside the compiled app rather than
/// fetched at first run) would mean gigabytes added to the build and
/// re-plumbing every cache-lookup path in `MushafPageService`/
/// `AyahAudioService`/`HadithRepository` to also check the asset bundle —
/// real engineering risk for content this large. This delivers the same
/// *lived* outcome a different way: the moment the app can reach the
/// network, it starts fetching Hafs (the default mushaf), Abdul Basit's
/// Murattal recitation, and the full hadith library automatically — no
/// tap required — using the exact same resumable, de-duplicated download
/// primitives the manual "Download" buttons already call, so this is
/// genuinely a background job, not a blocking wait. By the time a user
/// who just finished onboarding reaches Home, at least some of it is
/// already there, and the rest keeps arriving in the background.
///
/// Idempotent by construction, not by a separate "already started" flag:
/// every primitive called here (`MushafPageService.prefetchEdition`,
/// `AyahAudioService.downloadSurah`, `DownloadManager.enqueue`) already
/// skips whatever's already on disk and de-dupes an in-flight job, so
/// calling this once per app start is always safe and self-healing if an
/// earlier attempt was interrupted (app killed mid-download, etc.).
const kEssentialMushafEditionId = 'hafs_kfqc';
const kEssentialReciterId = 'ar.abdulbasitmurattal';

Future<void> bootstrapEssentialContent(WidgetRef ref) async {
  // Fire all three independently — one failing (e.g. genuinely offline)
  // must never block the other two from starting.
  unawaited(_bootstrapMushaf(ref));
  unawaited(_bootstrapRecitation(ref));
  unawaited(_bootstrapHadith(ref));
}

Future<void> _bootstrapMushaf(WidgetRef ref) async {
  try {
    final editions = await ref.read(mushafEditionsProvider.future);
    final hafs = editions.where((e) => e.id == kEssentialMushafEditionId);
    if (hafs.isEmpty) return;
    final e = hafs.first;
    await MushafPageService.instance.prefetchEdition(
      editionId: e.id,
      sourcePath: e.sourcePath,
      title: e.nameAr,
    );
  } catch (_) {
    // No connectivity yet, or a transient failure — the manual "Download"
    // button in Downloads/onboarding is still there as a fallback, and
    // this same call retries harmlessly on the next app start.
  }
}

Future<void> _bootstrapRecitation(WidgetRef ref) async {
  try {
    final data = await ref.read(mushafDataProvider.future);
    final reciters = await ref.read(recitersProvider.future);
    final hasReciter = reciters.any((r) => r.identifier == kEssentialReciterId);
    if (!hasReciter) return;
    for (final s in data.surahs) {
      await AyahAudioService.instance.downloadSurah(
        surah: s.id,
        ayahCount: s.ayahsCount,
        repo: data.repo,
        edition: kEssentialReciterId,
        title: '${s.id}. ${s.nameAr}',
      );
    }
  } catch (_) {}
}

Future<void> _bootstrapHadith(WidgetRef ref) async {
  try {
    final repo = await ref.read(hadithRepositoryProvider.future);
    if (repo != null) return; // already downloaded
    await DownloadManager.instance.enqueue(
      id: hadithDbDownloadId,
      url: AppConfig.hadithDbUrl,
      category: 'hadith',
      fileName: 'hadith.zip',
      unzipToDatabases: true,
      dbVersion: AppConfig.hadithDbVersion,
    );
  } catch (_) {}
}
