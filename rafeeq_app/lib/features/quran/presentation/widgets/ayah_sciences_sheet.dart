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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/buckwalter.dart';
import '../../data/ayah_notes_store.dart';
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
  late final TabController _tabs = TabController(length: 4, vsync: this);

  late final Future<Map<String, String>> _tafseer;
  late final Future<Map<String, AyahTranslation>> _translations;
  late final Future<List<WordGrammar>> _grammar;
  late final Future<List<WordMeaning>> _meanings;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(sciencesRepositoryProvider.future);
    final s = widget.ayah.surahId;
    final a = widget.ayah.ayahNumber;
    _tafseer = repo.then((r) => r.tafseerForAyah(s, a));
    _translations = repo.then((r) => r.translationsForAyah(s, a));
    _grammar = repo.then((r) => r.wordGrammar(s, a));
    _meanings = repo.then((r) => r.wordMeanings(s, a));
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
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: gold.withValues(alpha: 0.45))),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _Header(
                surahNameAr: widget.surahNameAr,
                ayah: widget.ayah,
                quranRepo: widget.quranRepo,
                translationsFuture: _translations,
              ),
              _AyahPanel(text: widget.ayah.textUthmani),
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
                    Tab(text: 'quran.meanings'.tr()),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _TafseerTab(future: _tafseer),
                      _TranslationTab(future: _translations),
                      _IrabTab(future: _grammar),
                      _MeaningsTab(future: _meanings),
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

  const _Header({
    required this.surahNameAr,
    required this.ayah,
    required this.quranRepo,
    required this.translationsFuture,
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
          IconButton(
            tooltip: 'quran.play'.tr(),
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => AyahAudioService.instance.play(
              ayah,
              quranRepo,
              title: _reference,
            ),
          ),
          IconButton(
            tooltip: 'quran.stop'.tr(),
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: AyahAudioService.instance.stopQueue,
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

  static const _timeOptions = [3, 5, 10];
  static const _gapOptions = [0, 1, 2, 3];

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return AlertDialog(
      title: Text('quran.repeat_dialog_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('quran.repeat_count'.tr()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final n in _timeOptions)
                ChoiceChip(
                  label: Text('$n'),
                  selected: _times == n,
                  selectedColor: gold.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _times = n),
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

/// The ayah itself, framed the way a printed mushaf frames its text.
class _AyahPanel extends StatelessWidget {
  final String text;
  const _AyahPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'AmiriQuran',
            height: 2.0,
          ),
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

/// P2‑8 #3 (QuranFlash-style "view several tafsirs at once") — the sources
/// are always all loaded together (no per-source fetch); this just toggles
/// how they're laid out: a scrollable list (default, reads well on a phone)
/// or side-by-side columns when there are exactly two, for a real compare.
class _TafseerTab extends StatefulWidget {
  final Future<Map<String, String>> future;
  const _TafseerTab({required this.future});

  @override
  State<_TafseerTab> createState() => _TafseerTabState();
}

class _TafseerTabState extends State<_TafseerTab> {
  bool _compare = false;

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<Map<String, String>>(
      future: widget.future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, data) {
        final entries = data.entries.toList();
        final blocks = [
          for (final e in entries)
            _SourceBlock(
              title: SciencesRepository.tafseerSources[e.key] ?? e.key,
              body: e.value,
              direction: TextDirection.rtl,
            ),
        ];

        if (entries.length < 2) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: blocks,
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => setState(() => _compare = !_compare),
                  icon: Icon(
                      _compare ? Icons.view_agenda_outlined : Icons.view_column_outlined),
                  label: Text(_compare
                      ? 'quran.tafseer_list_view'.tr()
                      : 'quran.tafseer_compare_view'.tr()),
                ),
              ),
            ),
            Expanded(
              child: _compare
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < blocks.length; i++) ...[
                          if (i > 0)
                            VerticalDivider(
                                width: 1,
                                color: AppColors.gold.withValues(alpha: 0.2)),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: blocks[i],
                            ),
                          ),
                        ],
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: blocks,
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
class _TranslationTab extends ConsumerWidget {
  final Future<Map<String, AyahTranslation>> future;
  const _TranslationTab({required this.future});

  static const _labels = {'en': 'English', 'fr': 'Français', 'ur': 'اردو'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTranslationLangProvider);
    return _AsyncTab<Map<String, AyahTranslation>>(
      future: future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, data) {
        final langs = SciencesRepository.supportedTranslationLangs
            .where(data.containsKey)
            .toList();
        final active = langs.contains(selected) ? selected : langs.first;
        final t = data[active]!;
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
                    value: active,
                    items: [
                      for (final lang in langs)
                        DropdownMenuItem(
                          value: lang,
                          child: Text(_labels[lang] ?? lang.toUpperCase()),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(selectedTranslationLangProvider.notifier).select(v);
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
                    title: _labels[t.lang] ?? t.lang.toUpperCase(),
                    subtitle: t.translator,
                    body: t.text,
                    direction:
                        t.lang == 'ur' ? TextDirection.rtl : TextDirection.ltr,
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

/// Corpus morphology, one card per word: part of speech, case, root, lemma.
class _IrabTab extends StatelessWidget {
  final Future<List<WordGrammar>> future;
  const _IrabTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<WordGrammar>>(
      future: future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, data) {
        final theme = Theme.of(context);
        final gold = AppColors.gold;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          itemCount: data.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final w = data[i];
            final facts = <String>[
              if (w.posAr.isNotEmpty) w.posAr,
              if (w.caseAr.isNotEmpty) w.caseAr,
            ].join(' · ');
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    w.token,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'AmiriQuran',
                      color: gold,
                    ),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      facts,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (w.root.isNotEmpty || w.lemma.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        if (w.root.isNotEmpty)
                          _Chip(
                            label: 'quran.root'.tr(),
                            value: buckwalterForDisplay(w.root),
                          ),
                        if (w.lemma.isNotEmpty)
                          _Chip(
                            label: 'quran.word'.tr(),
                            value: buckwalterForDisplay(w.lemma),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MeaningsTab extends StatelessWidget {
  final Future<List<WordMeaning>> future;
  const _MeaningsTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<WordMeaning>>(
      future: future,
      isEmpty: (d) => d.isEmpty,
      builder: (context, data) {
        final theme = Theme.of(context);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          itemCount: data.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  alignment: Alignment.center,
                  child: Text(
                    '${data[i].pos}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data[i].en,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
