/// The sciences sheet’s header row: the ayah’s identity, the play /
/// repeat / bookmark / note / share controls, and the reciter chip.
///
/// Split out of `ayah_sciences_sheet.dart`, which was 1,543 lines and twenty
/// classes — four tabs, three dialogs, a header and a set of shared shells,
/// all private to one file and therefore impossible to reuse or to open
/// without loading the rest.
library;

import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/db/quran_repository.dart';
import '../../../../../core/db/sciences_repository.dart';
import '../../../../../core/services/ayah_audio_service.dart';
import '../../../../downloads/data/reciters_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../data/ayah_notes_store.dart';
import '../../../data/translation_lang_provider.dart';
import '../ayah_share_card.dart';
import '../reciter_picker_sheet.dart';
import 'sciences_dialogs.dart';

class SciencesHeader extends ConsumerWidget {
  final String surahNameAr;
  final Ayah ayah;
  final QuranRepository quranRepo;
  final Future<Map<String, AyahTranslation>> translationsFuture;
  final bool expanded;
  final VoidCallback onToggleExpand;

  const SciencesHeader({
    super.key,
    required this.surahNameAr,
    required this.ayah,
    required this.quranRepo,
    required this.translationsFuture,
    required this.expanded,
    required this.onToggleExpand,
  });

  String get _reference => '$surahNameAr • ${ayah.surahId}:${ayah.ayahNumber}';

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String? existingNote,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: ayah.textUthmani));
        messenger.showSnackBar(
          SnackBar(
            content: Text('quran.copy'.tr()),
            duration: const Duration(seconds: 1),
          ),
        );
      case 'repeat':
        // The dialog only picks the config and returns it — it must not
        // start playback or show a SnackBar itself, since its own
        // BuildContext is torn down the instant it pops and a SnackBar
        // scheduled through it can end up stuck (never auto-dismissing).
        // This header's context outlives the sheet, so it owns both.
        final config = await showDialog<(int, int)>(
          context: context,
          builder: (_) => const RepeatDialog(),
        );
        if (config == null) return;
        final (times, gapSeconds) = config;
        unawaited(AyahAudioService.instance.playRepeated(
          ayah,
          quranRepo,
          times: times,
          gap: Duration(seconds: gapSeconds),
          title: _reference,
        ));
        messenger.showSnackBar(
          SnackBar(
            content: Text('quran.repeat_playing'.tr()),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'quran.repeat_stop'.tr(),
              onPressed: () {
                AyahAudioService.instance.stopQueue();
                messenger.hideCurrentSnackBar();
              },
            ),
          ),
        );
      case 'note':
        await showDialog<void>(
          context: context,
          builder: (_) => NoteDialog(
            ayah: ayah,
            initialText: existingNote ?? '',
          ),
        );
      case 'share':
        final translations = await translationsFuture;
        final lang = ref.read(selectedTranslationLangProvider);
        final translation = translations[lang]?.text;
        if (!context.mounted) return;
        final ok = await shareAyahAsImage(
          context,
          ayahText: ayah.textUthmani,
          reference: _reference,
          translation: translation,
        );
        if (!ok && context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('quran.share_failed'.tr())),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final notes = ref.watch(ayahNotesProvider);
    final note = notes[AyahNotesNotifier.keyFor(ayah.surahId, ayah.ayahNumber)];
    final hasNote = note != null && note.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: gold.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${ayah.surahId}:${ayah.ayahNumber}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  surahNameAr,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${'quran.page'.tr()} ${ayah.pageNumber}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                // «حط في كارت الآية صوت القارئ وإمكانية اختيار قارئ آخر لأنه
                // مش موجود فعلًا». The card was already reciting in the
                // reader's chosen reciter — `selectedReciterProvider` — but
                // never said who, and gave no way to change it without
                // leaving the card for the page's own recitation bar.
                //
                // It sat in the header Row first, and on emulator-5554 the
                // row was already carrying the ayah badge, the surah name,
                // «تلاوة الآية», expand and the overflow menu: the chip's
                // `Flexible` name collapsed to **nothing** and all that
                // showed was a gold microphone and a chevron — an icon that
                // does not say who, which is the thing the owner asked for.
                // Under the title it has the width to be read.
                const ReciterChip(),
              ],
            ),
          ),
          // P3‑35: one button that flips state instead of two separate
          // play/stop buttons — matches the tasbeeh circle / khatma "read
          // today" pattern elsewhere of a single affordance that toggles.
          // Driven by the audio service's own playback stream rather than
          // local widget state, so it also reflects playback started
          // elsewhere (e.g. the "repeat" menu action below).
          //
          // P3‑57: while a continuous recitation is running, the shared
          // player is playing, so this button used to render as STOP and
          // stopped the recitation the reader was following — the owner's
          // "I pick a verse before or after the one playing and the
          // recitation stops and won't play". Mid-recitation it now means
          // «اقرأ من هنا»: the recitation jumps to this verse and reads on,
          // and the sheet closes so the reader can see the page it moved to.
          ValueListenableBuilder<ContinuousRecitation>(
            valueListenable: AyahAudioService.instance.continuous,
            builder: (context, recite, _) {
              if (recite.active) {
                final here = recite.isAyah(ayah.surahId, ayah.ayahNumber);
                return IconButton(
                  tooltip: 'quran.recite_from_here'.tr(),
                  icon: Icon(
                    here
                        ? Icons.graphic_eq_rounded
                        : Icons.play_circle_outline,
                    color: here ? gold : null,
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await AyahAudioService.instance.jumpContinuousTo(
                      ayah: ayah,
                      repo: quranRepo,
                    );
                    if (navigator.canPop()) navigator.pop();
                  },
                );
              }
              return StreamBuilder<bool>(
                stream: AyahAudioService.instance.isPlayingStream,
                initialData: AyahAudioService.instance.isPlaying,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  // «حُط خيار تلاوة الآية في كارت الآية» — one verse, in the
                  // reader's chosen reciter, separate from the recitation.
                  return TextButton.icon(
                    icon: Icon(playing
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline),
                    label: Text((playing ? 'quran.stop' : 'quran.recite_ayah').tr()),
                    onPressed: playing
                        ? AyahAudioService.instance.stopQueue
                        : () => AyahAudioService.instance.play(
                              ayah,
                              quranRepo,
                              title: _reference,
                              edition: ref.read(selectedReciterProvider),
                            ),
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: (expanded ? 'quran.card_collapse' : 'quran.card_expand').tr(),
            icon: Icon(expanded
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded),
            onPressed: onToggleExpand,
          ),
          PopupMenuButton<String>(
            tooltip: '',
            icon: Icon(Icons.more_vert, color: hasNote ? gold : null),
            onSelected: (v) => _handleAction(context, ref, v, note),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: Text('quran.copy'.tr()),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'repeat',
                child: ListTile(
                  leading: const Icon(Icons.repeat_rounded),
                  title: Text('quran.repeat'.tr()),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'note',
                child: ListTile(
                  leading: Icon(
                    hasNote ? Icons.edit_note : Icons.note_add_outlined,
                    color: hasNote ? gold : null,
                  ),
                  title: Text(hasNote ? 'quran.note_edit'.tr() : 'quran.note'.tr()),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: Text('quran.share'.tr()),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// P2‑8 #1 (Ayat-style memorization loop) — picks how many times to repeat
/// the current ayah's recitation and the gap between repetitions, and pops
/// `(times, gapSeconds)`. Deliberately does **not** start playback or touch
/// `ScaffoldMessenger` itself — this dialog's own context is torn down the
/// instant it pops, and a SnackBar scheduled through a closing dialog's
/// context can end up stuck on screen (observed live: it never
/// auto-dismissed). The caller, whose context outlives the dialog, does
/// both once this returns.

/// The reciter the card will recite in, and a way to change them.
///
/// Deliberately the *same* provider and the *same* picker the page's
/// recitation bar uses, and it calls `AyahAudioService.switchReciter` exactly
/// as that bar does — two places that chose a reciter independently would be
/// two reciters, and the reader would have no way to tell which one a given
/// button was about to use.
class ReciterChip extends ConsumerWidget {
  const ReciterChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(selectedReciterProvider);
    final list = ref.watch(recitersProvider).valueOrNull;
    final reciter = list?.where((r) => r.identifier == id).firstOrNull;
    // While the catalogue loads there is a name to show but nothing to show
    // it from; an empty chip is worse than none.
    if (reciter == null) return const SizedBox.shrink();
    final name = reciter.displayName(context.locale.languageCode);
    if (name.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final chosen = await showReciterPickerSheet(context);
          if (chosen == null) return;
          await ref.read(selectedReciterProvider.notifier).select(chosen);
          await AyahAudioService.instance.switchReciter(chosen);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.record_voice_over_outlined,
                  size: 15, color: AppColors.gold),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(Icons.expand_more_rounded,
                  size: 16, color: AppColors.gold.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ayah itself, framed the way a printed mushaf frames its text,
/// with optional Latin transliteration for non-Arabic readers.
