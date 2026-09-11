import 'dart:async';

// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (rtl/ltr) used throughout this file.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/services/quran_api_service.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/data/transliteration_settings_provider.dart';
import '../../data/ayah_notes_store.dart';
import '../../data/quran_grammar_parser.dart';
import '../../data/tafseer_source_provider.dart';
import '../../../../core/services/quran_translation_store.dart';
import '../../data/quran_translation_catalog.dart';
import '../../data/translation_lang_provider.dart';
import 'ayah_share_card.dart';

/// "علوم الآية" — tafsir, translation, i'rab and word meanings for one ayah,
/// served straight from the bundled quran_sciences.db so the whole card works
/// with no network.
class AyahSciencesSheet extends ConsumerStatefulWidget {
  final Ayah ayah;
  final String surahNameAr;
  final QuranRepository quranRepo;

  /// False when the mushaf being read numbers this surah differently from the
  /// sciences database, in which case Hafs-keyed tafsir, translation and i'rab
  /// would belong to a different verse and must not be shown.
  final bool sciencesAvailable;

  const AyahSciencesSheet({
    super.key,
    required this.ayah,
    required this.surahNameAr,
    required this.quranRepo,
    this.sciencesAvailable = true,
  });

  static Future<void> show(
    BuildContext context, {
    required Ayah ayah,
    required String surahNameAr,
    required QuranRepository quranRepo,
    bool sciencesAvailable = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahSciencesSheet(
        ayah: ayah,
        surahNameAr: surahNameAr,
        quranRepo: quranRepo,
        sciencesAvailable: sciencesAvailable,
      ),
    );
  }

  @override
  ConsumerState<AyahSciencesSheet> createState() => _AyahSciencesSheetState();
}

class _AyahSciencesSheetState extends ConsumerState<AyahSciencesSheet>
    with SingleTickerProviderStateMixin {
  // 4 tabs: Tafseer, Translation, I'rab, Gharib al-Quran (word meanings).
  // The 4th tab (Gharib al-Quran) uses Quran.com API v4 word-by-word data
  // to show each word's Arabic meaning alongside the Uthmani script.
  late final TabController _tabs = TabController(length: 3, vsync: this);

  late final Future<Map<String, String>> _tafseer;
  late final Future<Map<String, AyahTranslation>> _translations;
  late final Future<List<WordGrammar>> _grammar;

  /// «حط جنب زر تلاوة الآية زر تكبير لخيارات الآية بحيث يملى الشاشة كلها لأن
  /// التفسير بتبقى مساحة عرضه صغيرة».
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(sciencesRepositoryProvider.future);
    final s = widget.ayah.surahId;
    final a = widget.ayah.ayahNumber;
    _tafseer = repo.then((r) => r.tafseerForAyah(s, a));
    _translations = repo.then((r) => r.translationsForAyah(s, a));
    _grammar = repo.then((r) => r.wordGrammar(s, a));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return SafeArea(
      top: _expanded,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _expanded ? 1.0 : 0.92),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, factor, child) =>
            FractionallySizedBox(heightFactor: factor, child: child),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(_expanded ? 0 : 28)),
            border: Border(top: BorderSide(color: gold.withValues(alpha: 0.45))),
          ),
          child: Column(
            children: [
              if (!_expanded) const _DragHandle(),
              _Header(
                surahNameAr: widget.surahNameAr,
                ayah: widget.ayah,
                quranRepo: widget.quranRepo,
                translationsFuture: _translations,
                expanded: _expanded,
                onToggleExpand: () => setState(() => _expanded = !_expanded),
              ),
              _AyahPanel(ayah: widget.ayah),
              if (!widget.sciencesAvailable)
                Expanded(
                  child: _Notice(
                    icon: Icons.info_outline,
                    message: 'quran.sciences_unavailable_here'.tr(),
                  ),
                )
              else ...[
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  indicatorColor: gold,
                  labelColor: gold,
                  dividerColor: gold.withValues(alpha: 0.18),
                  tabs: [
                    Tab(text: 'quran.tafseer'.tr()),
                    Tab(text: 'quran.translation'.tr()),
                    Tab(text: 'quran.irab'.tr()),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _TafseerTab(future: _tafseer),
                      _TranslationTab(
                          ayah: widget.ayah, future: _translations),
                      _IrabTab(ayah: widget.ayah, future: _grammar),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _Header extends ConsumerWidget {
  final String surahNameAr;
  final Ayah ayah;
  final QuranRepository quranRepo;
  final Future<Map<String, AyahTranslation>> translationsFuture;
  final bool expanded;
  final VoidCallback onToggleExpand;

  const _Header({
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
          builder: (_) => const _RepeatDialog(),
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
          builder: (_) => _NoteDialog(
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
class _RepeatDialog extends StatefulWidget {
  const _RepeatDialog();

  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  int _times = 3;
  int _gapSeconds = 1;

  /// «شيل ٣ و٥ و١٠ وخليه سكرول بار بعدد المرات اللي أنا عايزها وجنبه مربع لو
  /// عايز أدخل التكرار يدوي». The slider covers the common range; the box
  /// takes anything up to [_maxTyped].
  static const _sliderMax = 50;
  static const _maxTyped = 999;
  static const _gapOptions = [0, 1, 2, 3];

  late final TextEditingController _timesField =
      TextEditingController(text: '$_times');

  @override
  void dispose() {
    _timesField.dispose();
    super.dispose();
  }

  void _fromSlider(int n) {
    setState(() => _times = n);
    _timesField.text = '$n';
  }

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return AlertDialog(
      title: Text('quran.repeat_dialog_title'.tr()),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('quran.repeat_count'.tr()),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _times.clamp(1, _sliderMax).toDouble(),
                  min: 1,
                  max: _sliderMax.toDouble(),
                  divisions: _sliderMax - 1,
                  label: '$_times',
                  onChanged: (v) => _fromSlider(v.round()),
                ),
              ),
              SizedBox(
                width: 68,
                child: TextField(
                  controller: _timesField,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (t) {
                    final n = int.tryParse(t.trim());
                    if (n != null && n >= 1 && n <= _maxTyped) {
                      setState(() => _times = n);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('quran.repeat_gap'.tr()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in _gapOptions)
                ChoiceChip(
                  label: Text('${g}s'),
                  selected: _gapSeconds == g,
                  selectedColor: gold.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _gapSeconds = g),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_times, _gapSeconds)),
          child: Text('quran.repeat_start'.tr()),
        ),
      ],
    );
  }
}

/// P2‑8 #7 — a private free-text note attached to this ayah.
class _NoteDialog extends ConsumerStatefulWidget {
  final Ayah ayah;
  final String initialText;

  const _NoteDialog({required this.ayah, required this.initialText});

  @override
  ConsumerState<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends ConsumerState<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('quran.note'.tr()),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 3,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'quran.note_hint'.tr(),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if (widget.initialText.isNotEmpty)
          TextButton(
            onPressed: () async {
              await ref
                  .read(ayahNotesProvider.notifier)
                  .clearNote(widget.ayah.surahId, widget.ayah.ayahNumber);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(
              'quran.note_delete'.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () async {
            await ref.read(ayahNotesProvider.notifier).setNote(
                  widget.ayah.surahId,
                  widget.ayah.ayahNumber,
                  _controller.text,
                );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// The ayah itself, framed the way a printed mushaf frames its text,
/// with optional Latin transliteration for non-Arabic readers.
class _AyahPanel extends ConsumerWidget {
  final Ayah ayah;
  const _AyahPanel({required this.ayah});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final showTransliteration = ref.watch(transliterationEnabledProvider);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ayah.textUthmani,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'AmiriQuran',
                height: 2.0,
              ),
            ),
            if (showTransliteration) ...[
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 1.5,
                color: gold.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              FutureBuilder<String?>(
                future: ref
                    .read(quranApiServiceProvider)
                    .getAyahTransliteration(ayah.surahId, ayah.ayahNumber),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: gold.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }
                  final text = snapshot.data;
                  if (text == null || text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: gold,
                      height: 1.5,
                      letterSpacing: 0.25,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared loading / error / empty handling for every tab.
class _AsyncTab<T> extends StatelessWidget {
  final Future<T> future;
  final bool Function(T data) isEmpty;
  final Widget Function(BuildContext context, T data) builder;

  const _AsyncTab({
    required this.future,
    required this.isEmpty,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _Notice(
            icon: Icons.error_outline,
            message: 'errors.generic'.tr(),
          );
        }
        final data = snap.data as T;
        if (isEmpty(data)) {
          return _Notice(
            icon: Icons.menu_book_outlined,
            message: 'quran.no_results'.tr(),
          );
        }
        return builder(context, data);
      },
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Notice({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A titled block used by the tafsir and translation tabs.
class _SourceBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String body;
  final TextDirection direction;

  const _SourceBlock({
    required this.title,
    required this.body,
    required this.direction,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: gold, fontWeight: FontWeight.w700),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textDirection: direction,
            textAlign:
                direction == TextDirection.rtl ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.75),
          ),
        ],
      ),
    );
  }
}

/// P3‑33: reverses P2‑8 #3's "view several tafsirs at once" (with an
/// optional side-by-side compare layout) — the owner didn't like it. Now:
/// one persisted dropdown, one source shown at a time, exactly mirroring
/// `_TranslationTab`'s already-established "single persisted choice"
/// pattern below. Every source in `SciencesRepository.tafseerSources` is
/// bundled in `quran_sciences.db` already (no per-source download exists
/// yet — that's P3‑31's job, a separate ~20-source tafsir download section
/// still needing a licence-research pass first); once that lands, a source
/// with no data for a given ayah is the natural place to show a download
/// affordance instead of just falling back silently, as this does for now.
class _TafseerTab extends ConsumerWidget {
  final Future<Map<String, String>> future;
  const _TafseerTab({required this.future});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTafseerSourceProvider);
    return _AsyncTab<Map<String, String>>(
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
                  _SourceBlock(
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
class _TranslationTab extends ConsumerStatefulWidget {
  final Ayah ayah;
  final Future<Map<String, AyahTranslation>> future;
  const _TranslationTab({required this.ayah, required this.future});

  @override
  ConsumerState<_TranslationTab> createState() => _TranslationTabState();
}

class _TranslationTabState extends ConsumerState<_TranslationTab> {
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
          _Notice(icon: Icons.cloud_off, message: 'errors.offline'.tr()),
      data: (catalog) {
        if (catalog.isEmpty) {
          return _Notice(
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
          return _Notice(icon: Icons.cloud_off, message: _error!);
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
            return _Notice(
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
          return _Notice(
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
          _SourceBlock(
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
class _IrabTab extends ConsumerStatefulWidget {
  final Ayah ayah;
  final Future<List<WordGrammar>> future;
  const _IrabTab({required this.ayah, required this.future});

  @override
  ConsumerState<_IrabTab> createState() => _IrabTabState();
}

class _IrabTabState extends ConsumerState<_IrabTab> {
  late final Future<List<QuranWordWbw>> _wbwFuture;

  @override
  void initState() {
    super.initState();
    _wbwFuture = ref.read(quranApiServiceProvider).getAyahWordsWbw(
          widget.ayah.surahId,
          widget.ayah.ayahNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<WordGrammar>>(
      future: widget.future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, localList) {
        return FutureBuilder<List<QuranWordWbw>>(
          future: _wbwFuture,
          builder: (context, wbwSnap) {
            final wbwList = wbwSnap.data ?? const <QuranWordWbw>[];
            final wbwMap = {for (final w in wbwList) w.position: w};

            final parsedItems = localList.map((g) {
              final wbw = wbwMap[g.pos];
              return QuranGrammarParser.parse(local: g, wbw: wbw);
            }).toList();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: parsedItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                return _GrammarCard(item: parsedItems[i]);
              },
            );
          },
        );
      },
    );
  }
}

/// A structured, elegant grammar card for a single Quranic word.
class _GrammarCard extends StatelessWidget {
  final WordSyntaxData item;
  const _GrammarCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Word + Position + POS Badge
          Row(
            children: [
              // Position pill
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${item.position}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // POS badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.posLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),

              // Word Token (Uthmani)
              Text(
                item.token,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'AmiriQuran',
                  color: gold,
                  fontSize: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Grammatical Case & Role Detail
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 16,
                  color: gold.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.caseDetail,
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Morphemes Tree / Decomposition (if available)
          if (item.segments.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: item.segments.map((seg) {
                final isStem = seg.type == MorphemeType.stem;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isStem
                        ? gold.withValues(alpha: 0.12)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isStem
                          ? gold.withValues(alpha: 0.35)
                          : scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${seg.text} (${seg.label})',
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isStem ? gold : scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Root & Lemma Chips
          if (item.rootFormatted != null || item.lemmaFormatted != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.rootFormatted != null)
                  _Chip(
                    icon: Icons.grass_outlined,
                    label: 'quran.root'.tr(),
                    value: item.rootFormatted!,
                  ),
                if (item.lemmaFormatted != null)
                  _Chip(
                    icon: Icons.menu_book_outlined,
                    label: 'quran.word'.tr(),
                    value: item.lemmaFormatted!,
                  ),
              ],
            ),
          ],

          // Word-by-Word Translation & Transliteration (from Quran.com API v4)
          if (item.englishMeaning != null || item.transliteration != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  if (item.transliteration != null)
                    Text(
                      item.transliteration!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (item.transliteration != null &&
                      item.englishMeaning != null)
                    Text(
                      ' • ',
                      style: TextStyle(color: scheme.outline),
                    ),
                  if (item.englishMeaning != null)
                    Expanded(
                      child: Text(
                        item.englishMeaning!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _Chip({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: gold),
            const SizedBox(width: 4),
          ],
          Text(
            '$label: $value',
            style: theme.textTheme.labelSmall?.copyWith(
              color: gold,
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

/// غريب القرآن — word-by-word meanings for the ayah, fetched from the
/// Quran.com API v4 `words` endpoint. Each word is displayed as a card with
/// the Uthmani-script word above and its meaning (translation) below.