import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../../core/db/models.dart';
import '../../../../../core/utils/digits.dart';

/// «وضع القراءة» as one endless scroll (owner, 2026-10-02): «خلي لي وضع
/// القراءة ده يبقى انفينيت سكرولينج … مش بيقلب صفحة بصفحة … يجيب المصحف
/// كله ورا بعضه لتحت». Every page from [firstPage] to [lastPage] in a single
/// vertical scroll, each one built only when it comes near the screen, with a
/// thin rule and the page number where one printed page ends and the next
/// begins.
///
/// **Why the list grows both ways from an anchor.** Pages differ in height
/// and are not laid out until they are near the screen, so «go to page 300»
/// cannot be turned into a scroll offset. The view keeps an anchor page at
/// offset 0 instead (`CustomScrollView.center`): pages after it are a list
/// growing down, pages before it a list growing up. A jump moves the anchor
/// and resets the offset to 0, which is exact for any page whether or not it
/// was ever built; and a page above the screen that finishes loading grows
/// upwards, away from what the reader is looking at, so nothing jumps.
///
/// Auto-scroll lives here, not in the pages: it moves this one scroll at
/// [autoScrollSpeed] pixels a second, frame by frame, straight through page
/// boundaries — there is no page to turn. A drag pauses it and lifting the
/// finger resumes it, as the paged reader always did.
class ContinuousMushafView extends StatefulWidget {
  const ContinuousMushafView({
    super.key,
    required this.firstPage,
    required this.lastPage,
    required this.initialPage,
    required this.ayahsOf,
    required this.pageBuilder,
    required this.onPageChanged,
    this.ayahsIfLoaded,
    this.background,
    this.ruleColor,
    this.autoScroll = false,
    this.autoScrollSpeed = 40,
    this.onAutoScrollReachedEnd,
    this.onReadingScroll,
    this.onBackgroundTap,
  });

  final int firstPage;
  final int lastPage;
  final int initialPage;

  final Future<List<Ayah>> Function(int page) ayahsOf;
  final List<Ayah>? Function(int page)? ayahsIfLoaded;

  /// One page's verses, as an embedded `MushafTextPage`.
  final Widget Function(BuildContext context, int page, List<Ayah> ayahs)
      pageBuilder;

  /// The page under the reading line changed.
  final ValueChanged<int> onPageChanged;

  /// The page colour behind everything (the pages draw no ground of their
  /// own when embedded).
  final Color? background;

  /// The rule between two pages.
  final Color? ruleColor;

  final bool autoScroll;
  final double autoScrollSpeed;

  /// Auto-scroll reached the end of [lastPage].
  final VoidCallback? onAutoScrollReachedEnd;

  /// The reader's own drag: true when moving forward through the text.
  final void Function(bool forward)? onReadingScroll;

  /// A tap between pages (a tap on a page is the page's own).
  final VoidCallback? onBackgroundTap;

  @override
  State<ContinuousMushafView> createState() => ContinuousMushafViewState();
}

class ContinuousMushafViewState extends State<ContinuousMushafView>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  // Set in `initState`, not lazily: a lazy `_current` first read inside
  // `jumpToPage` — after the anchor had moved — took the TARGET page as its
  // starting value, so the first jump was never reported to the screen
  // (caught by `continuous_mushaf_view_test.dart`).
  late int _anchor;
  late int _current;

  /// The pages built right now, by page number. Only these can be measured.
  final Map<int, BuildContext> _built = {};

  /// Set while a jump is settling, so the half-laid-out frame in between is
  /// not reported as the page being read.
  bool _jumping = false;

  late final Ticker _ticker = createTicker(_onTick);
  Duration? _lastTick;
  bool _pausedForUser = false;
  Timer? _resume;

  int _clamp(int page) => page.clamp(widget.firstPage, widget.lastPage);

  /// The page being read — the one under the reading line.
  int get currentPage => _current;

  /// Marks inside the pages that a jump can land on exactly — a surah's
  /// banner, which on the short surahs sits halfway down its page.
  final Map<Object, BuildContext> _marks = {};

  /// The jump still waiting for its mark to be built, and how many frames
  /// it has waited.
  Object? _pendingMark;
  int _markWaits = 0;

  /// Brings [page]'s top to the top of the screen — or, with [mark], the
  /// [ContinuousMark] of that id inside it (owner, 2026-10-02: the endless
  /// scroll must stay indexed, «لما أضغط الى سورة كذا ينقلني … للسورة
  /// كذا»). A page that is built is scrolled to where it is; any other page
  /// becomes the new anchor, so the jump is exact whether or not the page
  /// was ever laid out.
  void jumpToPage(int page, {Object? mark}) {
    page = _clamp(page);
    final ctx = _built[page];
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx);
    } else {
      _jumping = true;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      setState(() => _anchor = page);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumping = false);
    }
    _setCurrent(page);
    _pendingMark = mark;
    _markWaits = 0;
    if (mark != null) _seekMark();
  }

  /// Scrolls to the pending mark once its page has loaded and built it.
  /// The page's verses come from the database a frame or more later, so
  /// this waits for them, but not forever.
  void _seekMark() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mark = _pendingMark;
      if (!mounted || mark == null) return;
      final ctx = _marks[mark];
      if (ctx != null && ctx.mounted) {
        _pendingMark = null;
        Scrollable.ensureVisible(ctx);
        return;
      }
      if (++_markWaits < 60) {
        _seekMark();
        WidgetsBinding.instance.scheduleFrame();
      } else {
        _pendingMark = null;
      }
    });
  }

  /// True when [page] is built and some of it is on screen.
  bool isOnScreen(int page) {
    final ctx = _built[page];
    final box = ctx?.findRenderObject();
    final view = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || view is! RenderBox || !box.attached) return false;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    return top < view.size.height && top + box.size.height > 0;
  }

  void _setCurrent(int page) {
    if (page == _current) return;
    _current = page;
    widget.onPageChanged(page);
  }

  /// The page under a line a quarter of the way down the screen — the line
  /// the eye reads at, so the number changes as a new page comes up to it.
  void _detectCurrent() {
    if (_jumping) return;
    final view = _viewportKey.currentContext?.findRenderObject();
    if (view is! RenderBox || !view.attached) return;
    final probe = view.size.height * 0.25;
    for (final e in _built.entries) {
      final box = e.value.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
      if (top <= probe && top + box.size.height > probe) {
        _setCurrent(e.key);
        return;
      }
    }
  }

  bool _detectScheduled = false;

  /// After the frame, not at the notification: a scroll notification comes
  /// BEFORE the pages are laid out at their new offsets, so measuring there
  /// read where they had been — the number lagged a page behind a fast
  /// drag (caught by `continuous_mushaf_view_test.dart`).
  void _scheduleDetect() {
    if (_detectScheduled) return;
    _detectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectScheduled = false;
      if (mounted) _detectCurrent();
    });
  }

  // ─── Auto-scroll ──────────────────────────────────────────────────────

  void _syncTicker() {
    final run = widget.autoScroll && !_pausedForUser;
    if (run && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
    if (!widget.autoScroll) {
      _resume?.cancel();
      _pausedForUser = false;
    }
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final dt = (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    final next = pos.pixels + widget.autoScrollSpeed * dt;
    if (next < pos.maxScrollExtent) {
      _scroll.jumpTo(next);
      return;
    }
    _scroll.jumpTo(pos.maxScrollExtent);
    // The end of the scroll is the end of the mushaf only once the last page
    // is actually built; before that, the list simply has not grown yet.
    if (_built.containsKey(widget.lastPage)) {
      _ticker.stop();
      widget.onAutoScrollReachedEnd?.call();
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      _scheduleDetect();
    }
    if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (n.dragDetails != null) {
        if (d > 2) {
          widget.onReadingScroll?.call(true);
        } else if (d < -2) {
          widget.onReadingScroll?.call(false);
        }
      }
    }
    if (!widget.autoScroll) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _resume?.cancel();
      _pausedForUser = true;
      _syncTicker();
    } else if (n is ScrollEndNotification && _pausedForUser) {
      _resume?.cancel();
      _resume = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _pausedForUser = false;
        _syncTicker();
      });
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _anchor = _clamp(widget.initialPage);
    _current = _anchor;
    _syncTicker();
  }

  @override
  void didUpdateWidget(ContinuousMushafView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _resume?.cancel();
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _page(int page) => _PageSlot(
        key: ValueKey(page),
        page: page,
        onBuilt: (ctx) => _built[page] = ctx,
        onGone: (ctx) {
          if (identical(_built[page], ctx)) _built.remove(page);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (page != widget.firstPage)
              _PageRule(page: page, color: widget.ruleColor),
            FutureBuilder<List<Ayah>>(
              future: widget.ayahsOf(page),
              initialData: widget.ayahsIfLoaded?.call(page),
              builder: (context, snap) {
                final ayahs = snap.data;
                if (ayahs == null) {
                  return const SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return widget.pageBuilder(context, page, ayahs);
              },
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final center = ValueKey('anchor-$_anchor');
    final before = _anchor - widget.firstPage;
    final after = widget.lastPage - _anchor + 1;
    return ColoredBox(
      color: widget.background ?? Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onBackgroundTap,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            key: _viewportKey,
            controller: _scroll,
            center: center,
            slivers: [
              // Grows UP from the anchor: index 0 is the page right above it.
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _page(_anchor - 1 - i),
                  childCount: before,
                ),
              ),
              SliverList(
                key: center,
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _page(_anchor + i),
                  childCount: after,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mark a surah's banner carries.
String continuousSurahMark(int surahId) => 'surah-$surahId';

/// A place inside a page that [ContinuousMushafViewState.jumpToPage] can
/// land on exactly. Outside a continuous view it does nothing.
class ContinuousMark extends StatefulWidget {
  const ContinuousMark({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  State<ContinuousMark> createState() => _ContinuousMarkState();
}

class _ContinuousMarkState extends State<ContinuousMark> {
  ContinuousMushafViewState? _view;

  @override
  void initState() {
    super.initState();
    _view = context.findAncestorStateOfType<ContinuousMushafViewState>();
    _view?._marks[widget.id] = context;
  }

  @override
  void dispose() {
    final view = _view;
    if (view != null && identical(view._marks[widget.id], context)) {
      view._marks.remove(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Registers the page it holds with the view while it is built, so the view
/// can tell which pages it can measure.
class _PageSlot extends StatefulWidget {
  const _PageSlot({
    super.key,
    required this.page,
    required this.onBuilt,
    required this.onGone,
    required this.child,
  });

  final int page;
  final void Function(BuildContext) onBuilt;
  final void Function(BuildContext) onGone;
  final Widget child;

  @override
  State<_PageSlot> createState() => _PageSlotState();
}

class _PageSlotState extends State<_PageSlot> {
  @override
  void initState() {
    super.initState();
    widget.onBuilt(context);
  }

  @override
  void dispose() {
    widget.onGone(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Where one printed page ends and the next begins: a hairline with the new
/// page's number in it — enough to keep one's place, quiet enough not to
/// interrupt the reading.
class _PageRule extends StatelessWidget {
  const _PageRule({required this.page, this.color});

  final int page;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.outline;
    final line = Expanded(
      child: Container(height: 1, color: c.withValues(alpha: 0.35)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              localizeDigits('$page', uiLanguageCode),
              style: TextStyle(
                fontSize: 12,
                color: c.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}
