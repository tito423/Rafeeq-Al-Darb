// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// shadows the dart:ui one (ltr/rtl) this file uses — hide it (same fix as
// ayah_sciences_sheet.dart, see HANDOVER §7).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../data/book_catalog.dart';
import '../../data/book_text.dart';

/// Reads a downloaded book's **text** edition (P2-4b) — the structured Shamela
/// text that sits beside the scanned image PDF.
///
/// One printed page at a time (mirrors the print edition and Shamela itself),
/// with a فهرس drawer, in-book search (diacritics-insensitive via
/// [normalizeArabic]), font-size control, per-book bookmarks, and the edition
/// provenance always visible. Fully offline once [path] is on disk.
class BookTextReaderScreen extends StatefulWidget {
  final LibraryBook book;

  /// Local path of the downloaded `books/text/<id>.json` file.
  final String path;

  const BookTextReaderScreen({
    super.key,
    required this.book,
    required this.path,
  });

  @override
  State<BookTextReaderScreen> createState() => _BookTextReaderScreenState();
}

class _BookTextReaderScreenState extends State<BookTextReaderScreen> {
  final _scrollCtrl = ScrollController();

  BookText? _doc;
  Object? _error;

  int _pageIndex = 0;
  double _fontScale = 1.0;
  Set<int> _bookmarks = {}; // printed page numbers

  String get _kPage => 'booktext_${widget.book.id}_page';
  String get _kFont => 'booktext_${widget.book.id}_font';
  String get _kMarks => 'booktext_${widget.book.id}_bookmarks';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await BookText.fromFile(widget.path);
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt(_kPage) ?? 0;
      setState(() {
        _doc = doc;
        _pageIndex = savedPage.clamp(0, doc.pages.length - 1);
        _fontScale = prefs.getDouble(_kFont) ?? 1.0;
        _bookmarks = (prefs.getStringList(_kMarks) ?? const [])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPage, _pageIndex);
    await prefs.setDouble(_kFont, _fontScale);
    await prefs.setStringList(
      _kMarks,
      _bookmarks.map((e) => e.toString()).toList(),
    );
  }

  void _goToPageIndex(int i) {
    final doc = _doc;
    if (doc == null) return;
    setState(() => _pageIndex = i.clamp(0, doc.pages.length - 1));
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    _persist();
  }

  void _changeFont(double delta) {
    setState(() => _fontScale = (_fontScale + delta).clamp(0.8, 1.9));
    _persist();
  }

  void _toggleBookmark() {
    final page = _doc?.pages[_pageIndex].printedPage;
    if (page == null) return;
    setState(() {
      if (!_bookmarks.remove(page)) _bookmarks.add(page);
    });
    _persist();
  }

  Future<void> _openGotoDialog() async {
    final doc = _doc;
    if (doc == null) return;
    final ctrl = TextEditingController(
      text: '${doc.pages[_pageIndex].printedPage}',
    );
    final printed = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('library.text_goto_page'.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.tag)),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text('library.text_goto'.tr()),
          ),
        ],
      ),
    );
    if (printed == null) return;
    // Nearest page whose printed number is >= the requested one.
    var target = 0;
    for (var i = 0; i < doc.pages.length; i++) {
      if (doc.pages[i].printedPage >= printed) {
        target = i;
        break;
      }
      target = i;
    }
    _goToPageIndex(target);
  }

  Future<void> _openSearch() async {
    final doc = _doc;
    if (doc == null) return;
    final hit = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchSheet(doc: doc),
    );
    if (hit != null) _goToPageIndex(hit);
  }

  void _openProvenance() {
    final te = widget.book.textEdition;
    if (te == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('library.text_source'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(te.sourceLabel, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 8),
            if (_doc?.meta.printMatches ?? false)
              Text('library.text_print_matches'.tr(),
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      fontSize: 12.5)),
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () {
                  final url = _doc?.meta.shamelaUrl ?? '';
                  if (url.isNotEmpty) {
                    launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('library.text_open_shamela'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.book.titleAr),
          actions: [
            IconButton(
              tooltip: 'library.text_font_smaller'.tr(),
              onPressed: _doc == null ? null : () => _changeFont(-0.1),
              icon: const Icon(Icons.text_decrease),
            ),
            IconButton(
              tooltip: 'library.text_font_larger'.tr(),
              onPressed: _doc == null ? null : () => _changeFont(0.1),
              icon: const Icon(Icons.text_increase),
            ),
            IconButton(
              tooltip: 'library.text_search'.tr(),
              onPressed: _doc == null ? null : _openSearch,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        endDrawer: _doc == null ? null : _IndexDrawer(
          doc: _doc!,
          currentPageIndex: _pageIndex,
          bookmarks: _bookmarks,
          onPick: (i) {
            Navigator.pop(context);
            _goToPageIndex(i);
          },
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('errors.generic'.tr(), textAlign: TextAlign.center),
        ),
      );
    }
    final doc = _doc;
    if (doc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (doc.pages.isEmpty) {
      return Center(child: Text('library.text_empty'.tr()));
    }

    final scheme = Theme.of(context).colorScheme;
    final page = doc.pages[_pageIndex];
    final section = doc.sectionTitleForPageIndex(_pageIndex);
    final bookmarked = _bookmarks.contains(page.printedPage);

    return Column(
      children: [
        // ── breadcrumb / current section + printed page ──
        Material(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.isEmpty ? widget.book.titleAr : section,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                        fontSize: 13),
                  ),
                ),
                if (doc.meta.printMatches)
                  Text(
                    '${'library.text_page'.tr()} ${page.printedPage}',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'library.text_bookmark'.tr(),
                  onPressed: _toggleBookmark,
                  icon: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: bookmarked ? AppColors.gold : scheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                Builder(
                  builder: (ctx) => IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'library.text_index'.tr(),
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    icon: const Icon(Icons.list_alt, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── the page body (selectable) ──
        Expanded(
          child: SelectionArea(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final para in page.paras) ...[
                    _Paragraph(para: para, scale: _fontScale),
                    const SizedBox(height: 12),
                  ],
                  if (page.paras.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text('library.text_blank_page'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── provenance strip (always visible) ──
        InkWell(
          onTap: _openProvenance,
          child: Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.book.textEdition?.sourceLabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 11.5),
                  ),
                ),
                if (widget.book.textEdition?.isOcr ?? false)
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('library.text_ocr_badge'.tr(),
                        style: TextStyle(
                            fontSize: 10, color: scheme.onErrorContainer)),
                  ),
              ],
            ),
          ),
        ),

        // ── page navigation ──
        Material(
          color: scheme.surface,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: _pageIndex > 0
                      ? () => _goToPageIndex(_pageIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_right), // RTL: prev = right
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _openGotoDialog,
                    child: Text(
                      '${_pageIndex + 1} / ${doc.pages.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _pageIndex < doc.pages.length - 1
                      ? () => _goToPageIndex(_pageIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_left), // RTL: next = left
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── one paragraph, styled by kind ──────────────────────────────────────────
class _Paragraph extends StatelessWidget {
  final BookPara para;
  final double scale;
  const _Paragraph({required this.para, required this.scale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (para.kind) {
      case 'head':
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            para.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16 * scale,
              color: AppColors.gold,
              height: 1.6,
            ),
          ),
        );
      case 'aya':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                para.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 18 * scale,
                  height: 1.9,
                  color: scheme.primary,
                ),
              ),
              if ((para.ref ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  para.ref!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5 * scale, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        );
      case 'ref':
        return Text(
          para.text,
          style: TextStyle(
              fontSize: 12.5 * scale, color: scheme.onSurfaceVariant),
        );
      default: // body
        return Text(
          para.text,
          textAlign: TextAlign.justify,
          style: TextStyle(fontSize: 16 * scale, height: 1.95),
        );
    }
  }
}

// ── فهرس drawer ───────────────────────────────────────────────────────────
class _IndexDrawer extends StatefulWidget {
  final BookText doc;
  final int currentPageIndex;
  final Set<int> bookmarks;
  final void Function(int pageIndex) onPick;

  const _IndexDrawer({
    required this.doc,
    required this.currentPageIndex,
    required this.bookmarks,
    required this.onPick,
  });

  @override
  State<_IndexDrawer> createState() => _IndexDrawerState();
}

class _IndexDrawerState extends State<_IndexDrawer> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = normalizeArabic(_filter.trim());
    final sections = q.isEmpty
        ? widget.doc.toc
        : widget.doc.toc
            .where((s) => normalizeArabic(s.title).contains(q))
            .toList();

    // Which section is "current" (last one starting at or before the page).
    BookSection? current;
    for (final s in widget.doc.toc) {
      if (s.pageIndex <= widget.currentPageIndex) current = s;
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('library.text_index'.tr(),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text('${widget.doc.toc.length}',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'library.text_index_filter'.tr(),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: sections.isEmpty
                  ? Center(child: Text('library.no_results'.tr()))
                  : ListView.builder(
                      itemCount: sections.length,
                      itemBuilder: (_, i) {
                        final s = sections[i];
                        final isCurrent = identical(s, current);
                        return ListTile(
                          dense: true,
                          selected: isCurrent,
                          contentPadding: EdgeInsetsDirectional.only(
                            start: 14.0 + (s.level == 0 ? 0 : 16),
                            end: 8,
                          ),
                          title: Text(
                            s.title,
                            style: TextStyle(
                              fontSize: s.level == 0 ? 14.5 : 13,
                              fontWeight: s.level == 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: Text(
                            '${'library.text_page'.tr()} ${s.page}',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                          onTap: () => widget.onPick(s.pageIndex),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── in-book search sheet ──────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final BookText doc;
  const _SearchSheet({required this.doc});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  List<_Hit> _hits = const [];
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run() {
    final q = normalizeArabic(_ctrl.text.trim());
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _searched = true;
      });
      return;
    }
    final hits = <_Hit>[];
    for (var i = 0; i < widget.doc.pages.length; i++) {
      for (final para in widget.doc.pages[i].paras) {
        final norm = normalizeArabic(para.text);
        final at = norm.indexOf(q);
        if (at >= 0) {
          final start = (at - 30).clamp(0, para.text.length);
          final end = (at + q.length + 40).clamp(0, para.text.length);
          hits.add(_Hit(
            pageIndex: i,
            printedPage: widget.doc.pages[i].printedPage,
            snippet: (start > 0 ? '…' : '') +
                para.text.substring(start, end).trim() +
                (end < para.text.length ? '…' : ''),
          ));
          break; // one hit per page is enough to navigate
        }
      }
      if (hits.length >= 300) break;
    }
    setState(() {
      _hits = hits;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'library.text_search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _run,
                  ),
                ),
                onSubmitted: (_) => _run(),
              ),
            ),
            if (_searched)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${_hits.length} ${'library.text_search_results'.tr()}',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ),
              ),
            const Divider(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _hits.length,
                itemBuilder: (_, i) {
                  final h = _hits[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Text('${h.printedPage}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                    title: Text(h.snippet,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, h.pageIndex),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hit {
  final int pageIndex;
  final int printedPage;
  final String snippet;
  const _Hit({
    required this.pageIndex,
    required this.printedPage,
    required this.snippet,
  });
}
