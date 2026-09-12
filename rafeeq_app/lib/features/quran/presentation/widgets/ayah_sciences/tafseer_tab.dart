/// «التفسير» — one tafsir edition for one ayah.
library;

import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/sciences_repository.dart';
import '../../../data/tafseer_source_provider.dart';
import 'sciences_common.dart';

/// P3‑33: reverses P2‑8 #3's "view several tafsirs at once" (with an
/// optional side-by-side compare layout) — the owner didn't like it. Now:
/// one persisted dropdown, one source shown at a time, exactly mirroring
/// `TranslationTab`'s already-established "single persisted choice"
/// pattern below. Every source in `SciencesRepository.tafseerSources` is
/// bundled in `quran_sciences.db` already (no per-source download exists
/// yet — that's P3‑31's job, a separate ~20-source tafsir download section
/// still needing a licence-research pass first); once that lands, a source
/// with no data for a given ayah is the natural place to show a download
/// affordance instead of just falling back silently, as this does for now.
class TafseerTab extends ConsumerWidget {
  final Future<Map<String, String>> future;
  const TafseerTab({super.key, required this.future});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTafseerSourceProvider);
    return AsyncTab<Map<String, String>>(
      future: future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, data) {
        // Not every bundled source necessarily covers every ayah — only
        // offer sources that actually have text here, and fall back to the
        // first one available if the persisted choice doesn't.
        final available = SciencesRepository.tafseerSources.keys
            .where(data.containsKey)
            .toList();
        final active = available.contains(selected) ? selected : available.first;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'quran.tafseer'.tr(),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: active,
                    items: [
                      for (final source in available)
                        DropdownMenuItem(
                          value: source,
                          child: Text(
                            SciencesRepository.tafseerSources[source] ?? source,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(selectedTafseerSourceProvider.notifier).select(v);
                      }
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  SourceBlock(
                    title: SciencesRepository.tafseerSources[active] ?? active,
                    body: data[active]!,
                    direction: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

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
