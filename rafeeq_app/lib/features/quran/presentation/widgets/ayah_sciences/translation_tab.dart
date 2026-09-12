/// «الترجمة» — the ayah in the reader’s chosen language, downloading the
/// pack on demand.
library;

import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/db/sciences_repository.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/quran_translation_store.dart';
import '../../../data/quran_translation_catalog.dart';
import '../../../data/translation_lang_provider.dart';
import 'sciences_common.dart';

/// WORK_QUEUE Stage 4: a persisted language selector, one translation shown
/// at a time, instead of stacking en/fr/ur every time the card opens.
///
/// The list is no longer just the six bundled languages. The owner asked for
/// 30+ languages **for the Quran translation** specifically (the app's own UI
/// chrome stays on its six locales), so the picker is driven by
/// `quran_translations.json` — 47 languages, one established translation each.
/// The six bundled ones read straight out of `quran_sciences.db` and work with
/// no connection; picking any other downloads it once (~250-450 KB) into
/// [QuranTranslationStore], after which it is offline too.
class TranslationTab extends ConsumerStatefulWidget {
  final Ayah ayah;
  final Future<Map<String, AyahTranslation>> future;
  const TranslationTab({super.key, required this.ayah, required this.future});

  @override
  ConsumerState<TranslationTab> createState() => TranslationTabState();
}

class TranslationTabState extends ConsumerState<TranslationTab> {
  /// Set when a download fails, so the pane says so rather than looking empty.
  String? _error;

  Future<void> _ensureDownloaded(QuranTranslationInfo info) async {
    if (info.bundled || QuranTranslationStore.instance.isInstalled(info.lang)) {
      return;
    }
    setState(() => _error = null);
    try {
      await QuranTranslationStore.instance.download(info.lang);
    } catch (_) {
      if (mounted) setState(() => _error = 'errors.offline'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTranslationLangProvider);
    final catalogAsync = ref.watch(quranTranslationCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          SciencesNotice(icon: Icons.cloud_off, message: 'errors.offline'.tr()),
      data: (catalog) {
        if (catalog.isEmpty) {
          return SciencesNotice(
              icon: Icons.info_outline, message: 'errors.generic'.tr());
        }
        final info = catalog.firstWhere(
          (e) => e.lang == selected,
          orElse: () => catalog.first,
        );
        // Rebuild the whole tab — dropdown included — when a language finishes
        // downloading, so its "needs downloading" size label disappears
        // instead of lingering on an item that is now installed.
        return ValueListenableBuilder<Set<String>>(
          valueListenable: QuranTranslationStore.instance.installed,
          builder: (context, _, _) => _tab(context, catalog, info),
        );
      },
    );
  }

  Widget _tab(BuildContext context, List<QuranTranslationInfo> catalog,
      QuranTranslationInfo info) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'quran.translation'.tr(),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: info.lang,
                    items: [
                      for (final e in catalog)
                        DropdownMenuItem(
                          value: e.lang,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e.nativeName,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              // A reader on mobile data should see what an
                              // un-downloaded language costs before tapping it.
                              if (!e.bundled &&
                                  !QuranTranslationStore.instance
                                      .isInstalled(e.lang))
                                Text(
                                  '  ${e.sizeLabel}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.gold),
                                ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await ref
                          .read(selectedTranslationLangProvider.notifier)
                          .select(v);
                      await _ensureDownloaded(
                          catalog.firstWhere((e) => e.lang == v));
                    },
                  ),
                ),
              ),
            ),
            Expanded(child: _body(info)),
          ],
        );
  }

  Widget _body(QuranTranslationInfo info) {
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: QuranTranslationStore.instance.downloading,
      builder: (context, jobs, _) {
        final progress = jobs[info.lang];
        if (progress != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                    value: progress > 0 ? progress : null),
                const SizedBox(height: 12),
                Text('quran.downloading_translation'
                    .tr(args: [info.nativeName])),
              ],
            ),
          );
        }
        if (_error != null) {
          return SciencesNotice(icon: Icons.cloud_off, message: _error!);
        }
        return _text(info);
      },
    );
  }

  Widget _text(QuranTranslationInfo info) {
    if (info.bundled) {
      // Straight from the bundled sciences DB — no network, ever.
      return FutureBuilder<Map<String, AyahTranslation>>(
        future: widget.future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = snap.data?[info.lang];
          if (t == null) {
            return SciencesNotice(
                icon: Icons.info_outline, message: 'errors.generic'.tr());
          }
          return _block(info, t.text, t.translator);
        },
      );
    }

    if (!QuranTranslationStore.instance.isInstalled(info.lang)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'quran.translation_not_downloaded'
                    .tr(args: [info.nativeName]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _ensureDownloaded(info),
                icon: const Icon(Icons.download),
                label: Text('${'common.download'.tr()} - ${info.sizeLabel}'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: QuranTranslationStore.instance
          .verse(info.lang, widget.ayah.surahId, widget.ayah.ayahNumber),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snap.data;
        if (text == null || text.isEmpty) {
          return SciencesNotice(
              icon: Icons.info_outline, message: 'errors.generic'.tr());
        }
        return _block(info, text, info.translator);
      },
    );
  }

  Widget _block(QuranTranslationInfo info, String body, String translator) =>
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SourceBlock(
            title: info.nativeName,
            subtitle: translator,
            body: body,
            direction: info.isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      );
}

/// Corpus morphology & syntax, one structured card per word:
/// Part of speech, grammatical case, root, morphemes tree, and wbw translation.
