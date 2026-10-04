import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/services/quran_translation_store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../hifz/data/tasmee_engine.dart';
import '../../../library/data/book_catalog.dart';
import '../../../library/data/library_api_service.dart';
import '../../../library/data/tts/open_voice.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../../quran/data/mushaf_page_service.dart';
import '../../../quran/data/quran_translation_catalog.dart';
import '../../../quran_audio/data/ayah_download_notice.dart';
import '../../../quran_audio/data/ayah_recitation_library.dart';
import '../../../quran_audio/data/mp3quran_api.dart';
import '../../../quran_audio/data/quran_audio_library.dart';
import '../../../quran_audio/presentation/ayah_download_screen.dart';
import '../../../quran_audio/presentation/reciter_screen.dart';
import '../../../quran_audio/presentation/widgets/audio_common.dart';
import '../../../shamela/data/shamela_import_service.dart';
import '../../data/reciters_provider.dart';

typedef _ActiveItem = (String title, String? detail, double? value, VoidCallback onTap);

({List<_ActiveItem> items, int waiting}) _getActiveDownloads(BuildContext context, WidgetRef ref) {
  final locale = context.locale.languageCode;
  final editions = ref.watch(mushafEditionsProvider).valueOrNull ?? const [];
  final data = ref.watch(mushafDataProvider).valueOrNull;
  final service = MushafPageService.instance;
  final audio = QuranAudioLibrary.instance.activeDownloads;
  final waiting = audio.where((d) => !d.running).length;
  final ayahLib = AyahRecitationLibrary.instance;
  final voice = OpenVoice.installProgress.value;
  final voiceIds = {for (final f in OpenVoice.files) OpenVoice.taskId(f)};
  final tasmee = TasmeeEngine.instance.downloadProgress.value;
  final catalog =
      ref.watch(quranTranslationCatalogProvider).valueOrNull ?? const [];
  String translationName(String lang) =>
      catalog.where((i) => i.lang == lang).firstOrNull?.nativeName ?? lang;
  
  final items = <_ActiveItem>[
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
    for (final j in ShamelaImportService.instance.jobs.value.values)
      if (j.error == null)
        (
          '${'shamela.title'.tr()} — ${j.title}',
          localizeDigits('shamela.importing'.tr(args: ['${j.pages}']), locale),
          null,
          () {},
        ),
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
        () {
          final all = ref.read(mp3RecitersProvider).valueOrNull;
          final full =
              all?.where((r) => r.id == d.entry.reciterId).firstOrNull;
          final reciter = full != null &&
                  full.moshafs.any((m) => m.id == d.entry.moshafId)
              ? full
              : Mp3Reciter(
                  id: d.entry.reciterId,
                  name: d.entry.reciterName,
                  moshafs: [d.entry.moshaf],
                );
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ReciterScreen(
              reciter: reciter,
              initialMoshafId: d.entry.moshafId,
            ),
          ));
        },
      ),
    for (final t in DownloadManager.instance.activeTasks)
      if (!voiceIds.contains(t.id))
      (
        t.title.isEmpty ? t.fileName : t.title,
        t.total == null
            ? null
            : ratio(formatBytes(t.received), formatBytes(t.total!)),
        t.total == null ? null : t.progress,
        () {},
      ),
  ];
  return (items: items, waiting: waiting);
}

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
    final state = _getActiveDownloads(context, ref);
    if (state.items.isEmpty && state.waiting == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ActiveDownloadsScreen(),
          )),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Icon(Icons.downloading_rounded, color: goldText(context), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('downloads.active_now'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(localizeDigits('${state.items.length + state.waiting}', locale),
                    style: TextStyle(color: goldOn(scheme), fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: goldOn(scheme)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActiveDownloadsScreen extends ConsumerStatefulWidget {
  const ActiveDownloadsScreen({super.key});

  @override
  ConsumerState<ActiveDownloadsScreen> createState() => _ActiveDownloadsScreenState();
}

class _ActiveDownloadsScreenState extends ConsumerState<ActiveDownloadsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
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
    final state = _getActiveDownloads(context, ref);
    if (state.items.isEmpty && state.waiting == 0) {
      return Scaffold(
        appBar: AppBar(title: Text('downloads.active_now'.tr())),
        body: Center(child: Text('downloads.nothing_downloaded'.tr())),
      );
    }
    
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('downloads.active_now'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (final (title, detail, value, onTap) in state.items)
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
          if (state.waiting > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text('${'quran_audio.queued'.tr()} · ${ltr('${state.waiting}')}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
