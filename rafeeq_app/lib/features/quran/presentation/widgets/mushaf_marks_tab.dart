/// «العلامات والملاحظات»: every bookmark and every note in one place - the
/// fourth tab of the «الانتقال إلى» sheet.
///
/// «مفيش خيار علامات عشان اقدر ارجع للاية او الصفحة في اي وقت وكمان لما احط
/// اكتر من ملاحظة مفيش مكان مجمع كل الملاحظات في مكان واحد» (owner,
/// 2026-10-20). Notes could be written on any ayah but only read back by
/// opening that same ayah's card; there was no list of them anywhere.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/ayah_notes_store.dart';
import '../../data/quran_bookmarks_store.dart';

class MushafMarksTab extends ConsumerWidget {
  const MushafMarksTab({
    super.key,
    required this.surahs,
    required this.repo,
    required this.current,
    required this.onPage,
  });

  /// Names for the ayah rows; empty on a printing that paginates its own
  /// way, where the rows fall back to the surah's number.
  final List<Surah> surahs;
  final QuranRepository repo;

  /// The page the reader is on - the one «علّم هذه الصفحة» marks.
  final int current;

  /// Goes to a page (the sheet closes first).
  final ValueChanged<int> onPage;

  String _surahName(int id) {
    for (final s in surahs) {
      if (s.id == id) return s.nameAr;
    }
    return localizeDigits('$id', uiLanguageCode);
  }

  String _ayahRef(int surah, int ayah) => localizeDigits(
        'quran.mark_ayah_ref'.tr(args: [_surahName(surah), '$ayah']),
        uiLanguageCode,
      );

  String _pageRef(int page) =>
      localizeDigits('${'quran.page'.tr()} $page', uiLanguageCode);

  Future<void> _goToAyah(BuildContext context, int surah, int ayah) async {
    final row = await repo.ayah(surah, ayah);
    if (row == null || !context.mounted) return;
    Navigator.of(context).pop();
    onPage(row.pageNumber);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final marks = ref.watch(quranBookmarksProvider);
    final notes = ref.watch(ayahNotesProvider);
    final pageMarked = marks.any((b) => !b.isAyah && b.page == current);
    // Notes in mushaf order: «2:255» sorts by surah, then ayah.
    final noteKeys = notes.keys.toList()
      ..sort((x, y) {
        final a = x.split(':').map(int.parse).toList();
        final b = y.split(':').map(int.parse).toList();
        return a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]);
      });

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(text,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
        );
    Widget empty(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton.icon(
            icon: Icon(pageMarked
                ? Icons.bookmark_remove_rounded
                : Icons.bookmark_add_rounded),
            label: Text((pageMarked
                    ? 'quran.unbookmark_page'
                    : 'quran.bookmark_page')
                .tr(args: [localizeDigits('$current', uiLanguageCode)])),
            onPressed: () => ref
                .read(quranBookmarksProvider.notifier)
                .togglePage(current),
          ),
        ),
        heading('quran.bookmarks'.tr()),
        if (marks.isEmpty) empty('quran.bookmarks_empty'.tr()),
        for (final b in marks)
          ListTile(
            leading: Icon(
              b.isAyah ? Icons.bookmark_rounded : Icons.auto_stories_rounded,
              color: AppColors.gold,
            ),
            title: Text(b.isAyah ? _ayahRef(b.surah!, b.ayah!) : _pageRef(b.page)),
            subtitle: b.isAyah ? Text(_pageRef(b.page)) : null,
            trailing: IconButton(
              tooltip: 'quran.bookmark_remove'.tr(),
              icon: const Icon(Icons.close_rounded),
              onPressed: () =>
                  ref.read(quranBookmarksProvider.notifier).remove(b),
            ),
            onTap: () {
              Navigator.of(context).pop();
              onPage(b.page);
            },
          ),
        const Divider(height: 24),
        heading('quran.notes_all'.tr()),
        if (noteKeys.isEmpty) empty('quran.notes_empty'.tr()),
        for (final k in noteKeys)
          Builder(builder: (context) {
            final parts = k.split(':').map(int.parse).toList();
            return ListTile(
              leading: const Icon(Icons.edit_note_rounded,
                  color: AppColors.gold),
              title: Text(_ayahRef(parts[0], parts[1])),
              subtitle: Text(
                notes[k]!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _goToAyah(context, parts[0], parts[1]),
            );
          }),
      ],
    );
  }
}
