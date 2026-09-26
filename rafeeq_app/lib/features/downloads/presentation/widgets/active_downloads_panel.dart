import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../../core/services/quran_translation_store.dart';
import '../../../hifz/data/tasmee_engine.dart';
import '../../../library/data/book_catalog.dart';
import '../../../library/data/library_api_service.dart';
import '../../../library/data/tts/open_voice.dart';
import '../../../quran/data/quran_translation_catalog.dart';
import '../../data/reciters_provider.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../../quran_audio/data/ayah_download_notice.dart';
import '../../../quran_audio/data/ayah_recitation_library.dart';
import '../../../quran_audio/data/mp3quran_api.dart';
import '../../../quran_audio/data/quran_audio_library.dart';
import '../../../quran_audio/presentation/ayah_download_screen.dart';
import '../../../quran_audio/presentation/reciter_screen.dart';
import '../../../quran_audio/presentation/widgets/audio_common.dart';

/// «جارٍ التنزيل الآن» on the Downloads hub: every transfer running, each
/// with what it is and how far it has got. Moved out of downloads_screen.dart
/// (800-line ceiling) when the per-ayah reciters and the reader voice joined
/// it - neither was listed before, so a 383 MB ayah download ran with no
/// trace on this screen.
class ActiveDownloadsPanel extends ConsumerStatefulWidget {
  const ActiveDownloadsPanel({super.key});

  @override
  ConsumerState<ActiveDownloadsPanel> createState() => ActiveDownloadsPanelState();
}

class ActiveDownloadsPanelState extends ConsumerState<ActiveDownloadsPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Page progress moves many times a second; once a second reads smoothly.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final editions = ref.watch(mushafEditionsProvider).valueOrNull ?? const [];
    final data = ref.watch(mushafDataProvider).valueOrNull;
    final service = MushafPageService.instance;
    final audio = QuranAudioLibrary.instance.activeDownloads;
    // A whole recitation is a hundred queued surahs; listing each one buried
    // the few actually transferring. The waiting ones are one count.
    final waiting = audio.where((d) => !d.running).length;
    final ayahLib = AyahRecitationLibrary.instance;
    final voice = OpenVoice.installProgress.value;
    final tasmee = TasmeeEngine.instance.downloadProgress.value;
    final catalog =
        ref.watch(quranTranslationCatalogProvider).valueOrNull ?? const [];
    String translationName(String lang) =>
        catalog.where((i) => i.lang == lang).firstOrNull?.nativeName ?? lang;
    // (title, detail, fraction, tap). The detail line says WHAT is moving -
    // «٢٤٠٤ من ٦٢٣٦ آية» - not only a percentage (owner, 2026-09-26: «حط
    // تفاصيل ايه اللي بيتحمل حاليا في صفحة التنزيلات بالتفصيل ومدى تقدمه»).
    final items = <(String, String?, double?, VoidCallback)>[
      for (final e in ayahLib.entries)
        if (ayahLib.isActive(e.edition))
          () {
            final have = ayahLib.downloadedCount(e.edition);
            final total = have + ayahLib.remainingCount(e.edition);
            return (
              '${'downloads.cat_ayah_recitations'.tr()} — '
                  '${AyahDownloadNotice.reciters[e.edition]?.displayName(locale) ?? e.edition}',
              localizeDigits(
                  'ayah_dl.ayahs_of'.tr(args: ['$have', '$total']), locale),
              total == 0 ? null : have / total,
              () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AyahDownloadScreen(),
                  )),
            );
          }(),
      if (tasmee != null)
        (
          'onboarding.tasmee_title'.tr(),
          ratio(formatBytes((tasmee * tasmeeDownloadBytes).round()),
              formatBytes(tasmeeDownloadBytes)),
          tasmee,
          () {},
        ),
      for (final MapEntry(key: id, value: v)
          in LibraryApiService.instance.bookDownloads.value.entries)
        (
          () {
            final b = bookById(id);
            if (b == null) return id;
            return Reciter.arabicScriptLocales.contains(locale) || b.titleEn.isEmpty
                ? b.titleAr
                : b.titleEn;
          }(),
          null,
          v,
          () {},
        ),
      for (final MapEntry(key: lang, value: v)
          in QuranTranslationStore.instance.downloading.value.entries)
        (
          '${'quran.translation'.tr()} — ${translationName(lang)}',
          null,
          v <= 0 ? null : v,
          () {},
        ),
      if (voice != null)
        (
          'downloads.cat_voices'.tr(),
          ratio(formatBytes((voice * OpenVoice.totalBytes).round()),
              formatBytes(OpenVoice.totalBytes)),
          voice,
          () {},
        ),
      for (final e in editions)
        if (service.activeEditions.contains(e.id))
          (
            e.localizedName(locale),
            null,
            service.progressFor(e.id).fraction,
            () {},
          ),
      for (final d in audio)
        if (d.running)
        (
          '${d.entry.reciterName} — ${surahTitle(data, d.surah, locale)}',
          null,
          d.progress <= 0 ? null : d.progress,
          () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReciterScreen(
                  reciter: Mp3Reciter(
                    id: d.entry.reciterId,
                    name: d.entry.reciterName,
                    moshafs: [d.entry.moshaf],
                  ),
                ),
              )),
        ),
      for (final t in DownloadManager.instance.activeTasks)
        (
          t.title.isEmpty ? t.fileName : t.title,
          t.total == null
              ? null
              : ratio(formatBytes(t.received), formatBytes(t.total!)),
          t.total == null ? null : t.progress,
          () {},
        ),
    ];
    if (items.isEmpty && waiting == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading_rounded, color: goldText(context), size: 20),
                  const SizedBox(width: 8),
                  Text('downloads.active_now'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              for (final (title, detail, value, onTap) in items)
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(
                              value == null ? '…' : percentOf(value),
                              style: TextStyle(fontSize: 12, color: goldOn(scheme), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(detail,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant)),
                          ),
                        const SizedBox(height: 4),
                        GoldProgressBar(value: value, height: 4, color: AppColors.gold),
                      ],
                    ),
                  ),
                ),
              if (waiting > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${'quran_audio.queued'.tr()} · ${ltr('$waiting')}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
