/// One shelf of «مكتبتي»: its books, ready to download or open, and its
/// reading time - with the way to put that time in Google Calendar.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/proper_name.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/external_link.dart';
import '../../../shamela/data/shamela_library.dart';
import '../../data/book_catalog.dart';
import '../../data/library_api_service.dart';
import '../../data/my_shelves.dart';
import '../../data/shelf_calendar.dart';
import '../screens/book_text_reader_screen.dart';
import '../widgets/book_card.dart';
import 'shelf_sheets.dart';
import 'shelf_style.dart';

LibraryBook? _bookById(String id) {
  for (final b in [...libraryBookCatalog, ...ShamelaLibrary.instance.books]) {
    if (b.id == id) return b;
  }
  return null;
}

class ShelfScreen extends ConsumerStatefulWidget {
  final int shelfId;
  const ShelfScreen({super.key, required this.shelfId});

  @override
  ConsumerState<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends ConsumerState<ShelfScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, String> _paths = {};
  StreamSubscription<List<DownloadTask>>? _dl;
  StreamSubscription<void>? _books;
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _load();
    _dl = DownloadManager.instance.stream.listen((_) => _load());
    _books = LibraryApiService.instance.changes.listen((_) => _load());
  }

  @override
  void dispose() {
    _dl?.cancel();
    _books?.cancel();
    _sway.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final shelf = ref.read(shelvesProvider.notifier).byId(widget.shelfId);
    if (shelf == null) return;
    final next = <String, String>{};
    for (final id in shelf.bookIds) {
      if (await LibraryApiService.instance.isBookDownloaded(id)) {
        next[id] = await LibraryApiService.instance.bookFilePath(id);
      }
    }
    if (mounted) {
      setState(() {
        _paths
          ..clear()
          ..addAll(next);
      });
    }
  }

  Future<void> _download(LibraryBook b) async {
    final edition = b.textEdition;
    if (edition == null) return;
    try {
      await LibraryApiService.instance.downloadBook(b.id, edition.url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pluralN('library.download_failed', 1))),
      );
    }
    await _load();
  }

  void _open(LibraryBook b) {
    final path = _paths[b.id];
    if (path == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookTextReaderScreen(book: b, path: path),
      ),
    );
  }

  Future<void> _pickBooks(Shelf shelf) async {
    final ids = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => ShelfBookPicker(shelf: shelf)),
    );
    if (ids == null) return;
    await ref.read(shelvesProvider.notifier).setBooks(shelf.id, ids);
    await _load();
  }

  Future<void> _remove(Shelf shelf, LibraryBook b) async {
    final notifier = ref.read(shelvesProvider.notifier);
    final before = shelf.bookIds;
    await notifier.removeBook(shelf.id, b.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text(
            'shelves.removed'.tr(args: [properName(b.titleAr, b.titleEn)]),
          ),
          action: SnackBarAction(
            label: 'common.undo'.tr(),
            onPressed: () => notifier.setBooks(shelf.id, before),
          ),
        ),
      );
  }

  Future<void> _delete(Shelf shelf) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('shelves.delete_title'.tr(args: [shelf.name])),
        content: Text('shelves.delete_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('shelves.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(shelvesProvider.notifier).delete(shelf.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shelves = ref.watch(shelvesProvider);
    Shelf? shelf;
    for (final s in shelves) {
      if (s.id == widget.shelfId) shelf = s;
    }
    if (shelf == null) {
      return Scaffold(appBar: AppBar());
    }
    final s = shelf;
    final colors = paletteOf(s);
    final books = [for (final id in s.bookIds) ?_bookById(id)];
    final lang = context.locale.languageCode;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: colors.first,
            foregroundColor: Colors.white,
            // The theme's AppBar icons and status bar are dark for a light
            // page; on the shelf's colour they disappeared.
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            actions: [
              IconButton(
                tooltip: 'shelves.edit'.tr(),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showShelfEditor(context, shelf: s),
              ),
              IconButton(
                tooltip: 'shelves.delete'.tr(),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _delete(s),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 14,
                end: 96,
              ),
              title: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              background: Hero(
                tag: 'shelf-${s.id}',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: colors,
                    ),
                  ),
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        end: -20,
                        top: 30,
                        child: Icon(
                          iconOf(s),
                          size: 150,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      PositionedDirectional(
                        start: 20,
                        end: 20,
                        bottom: 52,
                        child: AnimatedBuilder(
                          animation: _sway,
                          builder: (_, _) => BookSpines(
                            bookIds: s.bookIds,
                            base: colors.first,
                            max: 14,
                            height: 54,
                            sway: _sway.value,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ReminderCard(shelf: s)),
          if (books.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyShelf(
                accent: colors.first,
                onAdd: () => _pickBooks(s),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  pluralN('shelves.count_books', books.length),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: books.length,
                itemBuilder: (context, i) {
                  final b = books[i];
                  return Dismissible(
                    key: ValueKey('shelf-${s.id}-${b.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    onDismissed: (_) => _remove(s, b),
                    child: _Appear(
                      index: i,
                      child: BookCard(
                        book: b,
                        paths: _paths,
                        onDownload: () => _download(b),
                        onOpen: () => _open(b),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ],
      ),
      // Hidden while the shelf is empty: the empty state has the same button.
      floatingActionButton: books.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'shelf-add-${s.id}',
              onPressed: () => _pickBooks(s),
              backgroundColor: colors.first,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.library_add_outlined),
              label: Text('shelves.add_books'.tr()),
            ),
      bottomNavigationBar: books.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  localizeDigits('shelves.swipe_hint'.tr(), lang),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}

/// A list item that slides and fades in, a beat after the one above it.
class _Appear extends StatelessWidget {
  final int index;
  final Widget child;
  const _Appear({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 380 + 60 * index.clamp(0, 8)),
    curve: Curves.easeOutCubic,
    builder: (_, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: c),
    ),
    child: child,
  );
}

class _ReminderCard extends StatelessWidget {
  final Shelf shelf;
  const _ReminderCard({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = paletteOf(shelf).last;
    final r = shelf.reminder;
    final lang = context.locale.languageCode;
    final days = r == null
        ? ''
        : r.weekdays.length == 7
        ? 'shelves.every_day'.tr()
        : ([
            6,
            7,
            1,
            2,
            3,
            4,
            5,
          ].where(r.weekdays.contains).map((d) => weekdayShort(d, lang))).join(
            'shelves.day_sep'.tr(),
          );
    final time = r == null
        ? ''
        : localizeDigits(
            TimeOfDay(hour: r.hour, minute: r.minute).format(context),
            lang,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showShelfReminderSheet(context, shelf),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: accent,
                      child: Icon(
                        r == null
                            ? Icons.notification_add_outlined
                            : Icons.notifications_active_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r == null
                                ? 'shelves.reminder_add'.tr()
                                : 'shelves.reminder_title'.tr(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r == null
                                ? 'shelves.reminder_add_hint'.tr()
                                : '$days · $time',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                if (r != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text('shelves.add_to_calendar'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.6)),
                    ),
                    onPressed: () {
                      final link = shelfCalendarLink(shelf);
                      if (link != null) openExternalLink(link.toString());
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  final Color accent;
  final VoidCallback onAdd;
  const _EmptyShelf({required this.accent, required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_stories_outlined, size: 72, color: accent),
        const SizedBox(height: 12),
        Text(
          'shelves.empty_shelf'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.library_add_outlined),
          label: Text('shelves.add_books'.tr()),
        ),
      ],
    ),
  );
}
