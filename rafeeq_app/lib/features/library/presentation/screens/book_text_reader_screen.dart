// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// shadows the dart:ui one (ltr/rtl) this file uses — hide it (same fix as
// ayah_sciences_sheet.dart, see HANDOVER §7).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../data/book_catalog.dart';
import '../../data/book_text.dart';

/// P3‑29 visual redesign: a small closed set of reading-ink choices offered
/// by the "لون الخط" toolbar action. Each entry carries both a light- and a
/// dark-theme color rather than one fixed color, because the reading
/// background itself flips between [AppColors.paper] (light) and
/// [AppColors.nightSurface] (dark) — a single fixed ink color picked in one
/// theme could land unreadable in the other (e.g. near-black text on the
/// dark navy paper). [defaultChoice] deliberately mirrors the exact
/// light/dark pair `MushafTextPage` already uses for Quran reading mode
/// (`AppColors.ink`/`AppColors.paperDark`), so a book read with the default
/// ink looks consistent with the rest of the app's reading surfaces.
class _InkChoice {
  final String labelKey;
  final Color light;
  final Color dark;
  const _InkChoice(this.labelKey, this.light, this.dark);
}

const _inkChoices = [
  _InkChoice('library.text_ink_default', AppColors.ink, AppColors.paperDark),
  _InkChoice('library.text_ink_sepia', Color(0xFF6B4423), Color(0xFFD9B98A)),
  _InkChoice('library.text_ink_contrast', Color(0xFF000000), Color(0xFFFFFFFF)),
];

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

  /// Page to open at, overriding the reader's own saved position. Set when
  /// arriving from a cross-book search hit, so the reader lands on the page
  /// that actually matched instead of wherever the book was last left.
  final int? initialPageIndex;

  const BookTextReaderScreen({
    super.key,
    required this.book,
    required this.path,
    this.initialPageIndex,
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
  Set<int> _bookmarks = {}; // page *indices* (stable even when print nums aren't)

  // P3‑29: "التشكيل" toggle — hides tashkeel in the book's own prose via
  // [stripTashkeelForDisplay]. Defaults on (true) since that's the source
  // data as-is. Quoted Quran ayahs (`para.kind == 'aya'`) are deliberately
  // exempt in `_Paragraph` below — Quranic text stays fully vocalized
  // regardless of this toggle, same as everywhere else in the app.
  bool _showTashkeel = true;

  // P3‑29: "لون الخط" toolbar action — index into [_inkChoices].
  int _inkIndex = 0;

  // Swipe-to-turn-page tracking (see `_handlePointerDown`/`_handlePointerUp`).
  Offset? _dragStart;
  DateTime? _dragStartTime;

  String get _kPage => 'booktext_${widget.book.id}_page';
  String get _kFont => 'booktext_${widget.book.id}_font';
  String get _kMarks => 'booktext_${widget.book.id}_bookmarks';
  String get _kTashkeel => 'booktext_${widget.book.id}_tashkeel';
  String get _kInk => 'booktext_${widget.book.id}_ink';

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
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _pageIndex = (widget.initialPageIndex ?? savedPage)
            .clamp(0, doc.pages.length - 1);
        _fontScale = prefs.getDouble(_kFont) ?? 1.0;
        _showTashkeel = prefs.getBool(_kTashkeel) ?? true;
        _inkIndex = (prefs.getInt(_kInk) ?? 0).clamp(0, _inkChoices.length - 1);
        _bookmarks = (prefs.getStringList(_kMarks) ?? const [])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPage, _pageIndex);
    await prefs.setDouble(_kFont, _fontScale);
    await prefs.setBool(_kTashkeel, _showTashkeel);
    await prefs.setInt(_kInk, _inkIndex);
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

  /// P3‑29/P3‑34: the two chevron page-turn buttons are gone, replaced by a
  /// swipe (same direction-aware logic as `azkar_section_screen.dart`/P3‑11:
  /// a rightward swipe is "forward" under RTL, the mirror image under LTR)
  /// plus the fast-jump slider in the bottom bar for long-range scrubbing.
  ///
  /// Tracked via raw `Listener` pointer events rather than a
  /// `GestureDetector`'s `onHorizontalDragEnd`: the page body sits inside a
  /// `SelectionArea` (for selectable text, an existing feature), whose own
  /// drag recognizer competes for the same gesture-arena slot and was found
  /// to win it — a `GestureDetector` wrapping `SelectionArea` never actually
  /// saw the swipe. `Listener` doesn't enter the gesture arena at all, so it
  /// always sees the raw pointer stream regardless of what `SelectionArea`
  /// does with it.
  void _handlePointerDown(PointerDownEvent e) {
    _dragStart = e.position;
    _dragStartTime = DateTime.now();
  }

  void _handlePointerUp(PointerUpEvent e) {
    final start = _dragStart;
    final startTime = _dragStartTime;
    _dragStart = null;
    _dragStartTime = null;
    final doc = _doc;
    if (start == null || startTime == null || doc == null) return;

    final dx = e.position.dx - start.dx;
    final elapsedMs =
        DateTime.now().difference(startTime).inMilliseconds.clamp(1, 1 << 30);
    final velocity = dx / elapsedMs * 1000; // px/s, matches DragEndDetails'

    if (dx.abs() < 40 || velocity.abs() < 200) return; // slow drag/near-tap

    final direction = Directionality.of(context);
    final isNext = direction == TextDirection.rtl ? dx > 0 : dx < 0;
    if (isNext) {
      if (_pageIndex < doc.pages.length - 1) _goToPageIndex(_pageIndex + 1);
    } else if (_pageIndex > 0) {
      _goToPageIndex(_pageIndex - 1);
    }
  }

  void _changeFont(double delta) {
    setState(() => _fontScale = (_fontScale + delta).clamp(0.8, 1.9));
    _persist();
  }

  void _toggleBookmark() {
    if (_doc == null) return;
    setState(() {
      if (!_bookmarks.remove(_pageIndex)) _bookmarks.add(_pageIndex);
    });
    _persist();
  }

  void _toggleTashkeel() {
    setState(() => _showTashkeel = !_showTashkeel);
    _persist();
  }

  /// P3‑29 "حجم الخط" toolbar action — a small sheet with A‑/A+ instead of
  /// two separate always-visible AppBar buttons, so it fits the same
  /// one-icon-per-feature toolbar row as the other 5 actions.
  Future<void> _openFontSizeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('library.text_font_size'.tr(),
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'library.text_font_smaller'.tr(),
                    onPressed: () {
                      _changeFont(-0.1);
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.text_decrease),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${(_fontScale * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'library.text_font_larger'.tr(),
                    onPressed: () {
                      _changeFont(0.1);
                      setSheetState(() {});
                    },
                    icon: const Icon(Icons.text_increase),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// P3‑29 "لون الخط" toolbar action — picks among [_inkChoices].
  Future<void> _openInkColorSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('library.text_font_color'.tr(),
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
              ),
              for (var i = 0; i < _inkChoices.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        isDark ? _inkChoices[i].dark : _inkChoices[i].light,
                  ),
                  title: Text(_inkChoices[i].labelKey.tr()),
                  trailing: i == _inkIndex
                      ? Icon(Icons.check, color: AppColors.gold)
                      : null,
                  onTap: () {
                    setState(() => _inkIndex = i);
                    _persist();
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openGotoDialog() async {
    final doc = _doc;
    if (doc == null) return;
    final byPrinted = doc.meta.printReliable;
    final ctrl = TextEditingController(
      text: byPrinted
          ? '${doc.pages[_pageIndex].printedPage}'
          : '${_pageIndex + 1}',
    );
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(byPrinted
            ? 'library.text_goto_page'.tr()
            : 'library.text_goto_seq'.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.tag),
            helperText: byPrinted
                ? null
                : '1 – ${doc.pages.length}',
          ),
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
    if (n == null) return;

    if (!byPrinted) {
      _goToPageIndex(n - 1);
      return;
    }
    // Reading order is Shamela's page order; when printed numbers ARE reliable
    // find an exact match, else the closest.
    var target = 0;
    var bestDiff = 1 << 30;
    for (var i = 0; i < doc.pages.length; i++) {
      final diff = (doc.pages[i].printedPage - n).abs();
      if (diff == 0) {
        target = i;
        break;
      }
      if (diff < bestDiff) {
        bestDiff = diff;
        target = i;
      }
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
            if (_doc?.meta.printReliable ?? false)
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
    final doc = _doc;
    final bookmarked = doc != null && _bookmarks.contains(_pageIndex);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.book.titleAr),
          // No actions, and `automaticallyImplyActions: false` — by
          // default, when `actions` is null OR empty and this Scaffold
          // has an `endDrawer` (it does, below, for the فهرس), Flutter's
          // AppBar auto-inserts its own hamburger button to open it (see
          // `AppBar.build()`: the auto-button fires whenever
          // `actions == null || actions.isEmpty`, so passing `const []`
          // alone doesn't suppress it — confirmed by first trying just
          // that and still seeing the icon live on the emulator). We
          // don't want that button: opening the index is already one of
          // the toolbar row's own actions below, and a second, unlabelled
          // way to trigger it would be exactly the clutter the Shamela
          // reference's own clean back-arrow-only header doesn't have.
          // The old "Text source" icon that used to live here moved out
          // entirely too — the provenance strip at the bottom of the
          // reading column already opens that same sheet.
          automaticallyImplyActions: false,
          // P3‑29: redesigned as a Shamela-style captioned toolbar row
          // (icon + label under it) instead of three bare `actions:`
          // icons — same `ToolbarAction` widget the Quran tab's toolbar
          // uses (P3‑34), shared via `core/widgets/toolbar_action.dart`
          // so both screens look and behave identically. Six actions to
          // match the reference's six, each backed by a real feature:
          // font size / font color (new) / tashkeel toggle (new) / the
          // existing in-book search (standing in for the reference's
          // "التعليقات" slot — this app has no comments feature to back
          // that icon honestly) / the existing فهرس drawer / the
          // existing bookmark toggle.
          bottom: doc == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
                    child: Row(
                      children: [
                        ToolbarAction(
                          icon: Icons.format_size,
                          label: 'library.text_font_size'.tr(),
                          onPressed: _openFontSizeSheet,
                        ),
                        ToolbarAction(
                          icon: Icons.palette_outlined,
                          label: 'library.text_font_color'.tr(),
                          onPressed: _openInkColorSheet,
                        ),
                        ToolbarAction(
                          icon: Icons.text_format,
                          label: 'library.text_tashkeel'.tr(),
                          active: _showTashkeel,
                          onPressed: _toggleTashkeel,
                        ),
                        ToolbarAction(
                          icon: Icons.search,
                          label: 'library.text_search'.tr(),
                          onPressed: _openSearch,
                        ),
                        // `Scaffold.of(context)` needs a context *below*
                        // the Scaffold in the tree — this `build()`
                        // method's own `context` sits above it, same
                        // reason the old breadcrumb row's index button
                        // needed a `Builder` too.
                        Builder(
                          builder: (ctx) => ToolbarAction(
                            icon: Icons.list_alt,
                            label: 'library.text_index'.tr(),
                            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                          ),
                        ),
                        ToolbarAction(
                          icon: bookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          label: 'library.text_bookmark'.tr(),
                          active: bookmarked,
                          onPressed: _toggleBookmark,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        endDrawer: doc == null ? null : _IndexDrawer(
          doc: doc,
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

    // P3‑29 visual redesign: the whole reading column — breadcrumb, page
    // body, provenance strip and bottom nav bar — sits on the same
    // paper/ink pair `MushafTextPage` already uses for Quran text-reading
    // mode, so a book read here looks like it belongs to the same app
    // rather than the neutral `surfaceContainerHighest` grey it used
    // before. This is "Shamela-style, our theme coloring" (per the
    // owner's reference): a distinct warm reading surface, gold hairline,
    // but none of Shamela's own blue.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? AppColors.nightSurface : AppColors.paper;
    final ink = isDark
        ? _inkChoices[_inkIndex].dark
        : _inkChoices[_inkIndex].light;
    final hairline = AppColors.gold.withValues(alpha: 0.28);

    return Column(
      children: [
        // ── breadcrumb: current section + printed page (the bookmark
        // and فهرس icons that used to live here moved up into the new
        // toolbar row so they aren't duplicated in two places) ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: paper,
            border: Border(bottom: BorderSide(color: hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  section.isEmpty ? widget.book.titleAr : section,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ink.withValues(alpha: 0.75),
                      fontSize: 13),
                ),
              ),
              if (doc.meta.printReliable)
                Text(
                  '${'library.text_page'.tr()} ${page.printedPage}',
                  style: TextStyle(color: ink.withValues(alpha: 0.75), fontSize: 12),
                ),
            ],
          ),
        ),

        // ── the page body (selectable, swipe to turn pages) ──
        Expanded(
          child: Container(
            color: paper,
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerUp: _handlePointerUp,
              child: SelectionArea(
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final para in page.paras) ...[
                        _Paragraph(
                          para: para,
                          scale: _fontScale,
                          ink: ink,
                          showTashkeel: _showTashkeel,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (page.paras.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text('library.text_blank_page'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ink.withValues(alpha: 0.6))),
                        ),
                      // P3‑44: real-device feedback — this repeated on
                      // *every* page, which reads as a stuck label rather
                      // than a one-time gesture hint. Shown only on the
                      // book's actual first page now; a reader who needs
                      // reminding after that already has the visible page
                      // slider/arrows at the bottom.
                      if (_pageIndex == 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'library.text_swipe_hint'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: ink.withValues(alpha: 0.5)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── provenance strip (always visible) ──
        InkWell(
          onTap: _openProvenance,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: paper,
              border: Border(top: BorderSide(color: hairline)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: ink.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.book.textEdition?.sourceLabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ink.withValues(alpha: 0.6), fontSize: 11.5),
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

        // ── page navigation: fast-jump slider (P3‑29/P3‑34) ──
        // The two chevron buttons the owner flagged as still there are gone
        // — turning pages now happens by swipe (`_onSwipe` above) or by
        // dragging this slider for long-range scrubbing across the whole
        // book, same "شريط تمرير سريع" (fast scroll bar) the feedback asked
        // for. Dragging updates the visible page live; the position is only
        // persisted once the drag ends, so a long scrub doesn't spam prefs.
        Material(
          color: paper,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${_pageIndex + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: ink.withValues(alpha: 0.65)),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16),
                          ),
                          child: Slider(
                            min: 0,
                            max: (doc.pages.length - 1).toDouble(),
                            value: _pageIndex.toDouble(),
                            divisions: doc.pages.length > 1
                                ? doc.pages.length - 1
                                : null,
                            onChanged: (v) =>
                                setState(() => _pageIndex = v.round()),
                            onChangeEnd: (v) {
                              if (_scrollCtrl.hasClients) {
                                _scrollCtrl.jumpTo(0);
                              }
                              _persist();
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${doc.pages.length}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: ink.withValues(alpha: 0.65)),
                        ),
                      ),
                    ],
                  ),
                ),
                // typed goto, kept as a precise alternative to the slider
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextButton(
                    onPressed: _openGotoDialog,
                    style: TextButton.styleFrom(foregroundColor: ink),
                    child: Text(
                      doc.meta.printReliable
                          ? '${'library.text_page'.tr()} ${page.printedPage}'
                          : '${_pageIndex + 1} / ${doc.pages.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
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
  final Color ink;
  final bool showTashkeel;
  const _Paragraph({
    required this.para,
    required this.scale,
    required this.ink,
    required this.showTashkeel,
  });

  /// P3‑29 "التشكيل" toggle. Quoted Quran ayahs (`kind == 'aya'`) are
  /// exempt — handled separately below, always shown fully vocalized,
  /// same as everywhere else in the app Quranic text appears.
  String get _displayText =>
      showTashkeel ? para.text : stripTashkeelForDisplay(para.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (para.kind) {
      case 'head':
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            _displayText,
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
          _displayText,
          style: TextStyle(fontSize: 12.5 * scale, color: ink.withValues(alpha: 0.7)),
        );
      default: // body
        return Text(
          _displayText,
          textAlign: TextAlign.justify,
          style: TextStyle(fontSize: 16 * scale, height: 1.95, color: ink),
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
            if (widget.bookmarks.isNotEmpty && _filter.trim().isEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    Icon(Icons.bookmark, size: 15, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text('quran.bookmarks'.tr(),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 96),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      for (final idx in (widget.bookmarks.toList()..sort()))
                        if (idx >= 0 && idx < widget.doc.pages.length)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              widget.doc.meta.printReliable
                                  ? '${'library.text_page'.tr()} '
                                      '${widget.doc.pages[idx].printedPage}'
                                  : '${idx + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => widget.onPick(idx),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
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
                            widget.doc.meta.printReliable
                                ? '${'library.text_page'.tr()} ${s.page}'
                                : '${s.pageIndex + 1}',
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
