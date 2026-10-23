/// «العلامات المرجعية»: the card behind the bookmark icon on the mushaf's top
/// bar (and the full-screen chrome, which carries the same toolbar).
///
/// «حطلي فيه خيار او ايقونة العلامات المرجعية فيظهر كارت فيه كل الخيارات
/// المعروفة والمشهورة للعلامات المرجعية» (owner, 2026-10-23). The options
/// mushaf apps commonly offer: mark this page, a colour per purpose (reading /
/// hifz / review / tadabbur), the list of marks to jump to or delete, sorted
/// newest first or in mushaf order, filtered by colour, and «مسح الكل».
/// Ayah marks made from an ayah's card show here too.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/quran_bookmarks_store.dart';

/// Colour and label of each kind - the same everywhere a mark is drawn.
Color bookmarkKindColor(BookmarkKind k) => switch (k) {
      BookmarkKind.reading => AppColors.gold,
      BookmarkKind.hifz => const Color(0xFF2E9E6A),
      BookmarkKind.review => const Color(0xFF3B82C4),
      BookmarkKind.tadabbur => const Color(0xFF8E5BB8),
    };

String bookmarkKindLabel(BookmarkKind k) => 'quran.bm_kind_${k.name}'.tr();

void showBookmarksSheet(
  BuildContext context, {
  required List<Surah> surahs,
  required int current,
  required ValueChanged<int> onPage,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      child: _BookmarksSheet(surahs: surahs, current: current, onPage: onPage),
    ),
  );
}

class _BookmarksSheet extends ConsumerStatefulWidget {
  const _BookmarksSheet({
    required this.surahs,
    required this.current,
    required this.onPage,
  });

  final List<Surah> surahs;
  final int current;
  final ValueChanged<int> onPage;

  @override
  ConsumerState<_BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends ConsumerState<_BookmarksSheet> {
  bool _mushafOrder = false;
  BookmarkKind? _filter;

  String _d(String s) => localizeDigits(s, uiLanguageCode);

  String _surahName(int id) {
    for (final s in widget.surahs) {
      if (s.id == id) return s.nameAr;
    }
    return _d('$id');
  }

  String _title(QuranBookmark b) => b.isAyah
      ? _d('quran.mark_ayah_ref'.tr(args: [_surahName(b.surah!), '${b.ayah}']))
      : _d('${'quran.page'.tr()} ${b.page}');

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('quran.bm_clear_all'.tr()),
        content: Text('quran.bm_clear_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('quran.bm_clear_all'.tr())),
        ],
      ),
    );
    if (ok == true) await ref.read(quranBookmarksProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(quranBookmarksProvider.notifier);
    final all = ref.watch(quranBookmarksProvider);
    final mine = all.where((b) => !b.isAyah && b.page == widget.current);
    final here = mine.isEmpty ? null : mine.first;

    final shown = [
      for (final b in all)
        if (_filter == null || b.kind == _filter) b,
    ];
    if (_mushafOrder) {
      shown.sort((x, y) => x.page != y.page
          ? x.page.compareTo(y.page)
          : (x.surah ?? 0) != (y.surah ?? 0)
              ? (x.surah ?? 0).compareTo(y.surah ?? 0)
              : (x.ayah ?? 0).compareTo(y.ayah ?? 0));
    }

    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(text,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('quran.bookmarks_title'.tr(),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        // ── this page ──
        section(_d('quran.bm_this_page'.tr(args: ['${widget.current}']))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in BookmarkKind.values)
                ChoiceChip(
                  avatar: Icon(
                    here?.kind == k
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: bookmarkKindColor(k),
                    size: 18,
                  ),
                  label: Text(bookmarkKindLabel(k)),
                  selected: here?.kind == k,
                  selectedColor: bookmarkKindColor(k).withValues(alpha: 0.18),
                  onSelected: (_) => notifier.setPageKind(widget.current, k),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            here == null ? 'quran.bm_pick_hint'.tr() : 'quran.bm_unpick_hint'.tr(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 28),
        // ── all marks ──
        Row(
          children: [
            Expanded(child: section(_d('quran.bm_all'.tr(args: ['${all.length}'])))),
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8, left: 8),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: false, label: Text('quran.bm_sort_recent'.tr())),
                  ButtonSegment(value: true, label: Text('quran.bm_sort_mushaf'.tr())),
                ],
                selected: {_mushafOrder},
                onSelectionChanged: (v) => setState(() => _mushafOrder = v.first),
              ),
            ),
          ],
        ),
        if (all.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: FilterChip(
                    label: Text('quran.bm_filter_all'.tr()),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final k in BookmarkKind.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: FilterChip(
                      avatar: CircleAvatar(
                          radius: 5, backgroundColor: bookmarkKindColor(k)),
                      label: Text(bookmarkKindLabel(k)),
                      selected: _filter == k,
                      onSelected: (_) => setState(
                          () => _filter = _filter == k ? null : k),
                    ),
                  ),
              ],
            ),
          ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('quran.bookmarks_empty'.tr(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        for (final b in shown)
          ListTile(
            leading: Icon(
              b.isAyah ? Icons.bookmark_rounded : Icons.auto_stories_rounded,
              color: bookmarkKindColor(b.kind),
            ),
            title: Text(_title(b)),
            subtitle: Text([
              bookmarkKindLabel(b.kind),
              if (b.isAyah) _d('${'quran.page'.tr()} ${b.page}'),
            ].join(' · ')),
            selected: !b.isAyah && b.page == widget.current,
            trailing: IconButton(
              tooltip: 'quran.bookmark_remove'.tr(),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => notifier.remove(b),
            ),
            onTap: () {
              Navigator.of(context).pop();
              widget.onPage(b.page);
            },
          ),
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: Text('quran.bm_clear_all'.tr()),
              onPressed: _confirmClear,
            ),
          ),
      ],
    );
  }
}
