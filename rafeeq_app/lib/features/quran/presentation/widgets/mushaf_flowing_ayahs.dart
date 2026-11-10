part of 'mushaf_text_page.dart';

// Split out of mushaf_text_page.dart (2026-11-10) to bring it under its
// length ceiling; the «۞» tap was the addition that would not fit.

// ─── Flowing verses ────────────────────────────────────────────────────────

/// One contiguous run of a surah's verses, set as a single justified paragraph
/// the way a printed mushaf sets them.
///
/// Verses are spans, not widgets, so hit-testing is done against the laid-out
/// paragraph: a tap is mapped to a text offset and then to the verse whose
/// span covers it. That gives per-verse tap and long-press without breaking
/// the text flow — which putting each verse in its own `InkWell` necessarily
/// would.
class _FlowingAyahs extends StatefulWidget {
  final List<Ayah> ayahs;

  /// Inclusive range into [ayahs] that this paragraph covers.
  final int from;
  final int to;

  /// Index into [ayahs] of the verse being recited, or -1.
  final int playingIndex;

  final TextStyle textStyle;

  /// The page's colour scheme, for the recited-verse wash and the markers.
  final MushafTheme mt;

  /// Long-press a verse: select it and open its card.
  final void Function(Ayah ayah) onAyahLongPress;

  /// Any tap on the paragraph, on a verse or between them.
  final VoidCallback? onBackgroundTap;

  /// The quarter an ayah opens when the mushaf prints «۞» on it; a tap on
  /// that mark shows which quarter it is instead of being the page's tap.
  final RubInfo? Function(Ayah ayah)? rubAt;

  /// The stripped reading layout — see `QuranTextLayout.reading`.
  final bool bare;

  const _FlowingAyahs({
    super.key,
    required this.ayahs,
    required this.from,
    required this.to,
    required this.playingIndex,
    required this.textStyle,
    required this.mt,
    required this.onAyahLongPress,
    this.onBackgroundTap,
    this.rubAt,
    this.bare = false,
  });

  @override
  State<_FlowingAyahs> createState() => _FlowingAyahsState();
}

class _FlowingAyahsState extends State<_FlowingAyahs> {
  final GlobalKey _textKey = GlobalKey();

  /// (startOffset, endOffset, ayahIndex) for every verse in this paragraph,
  /// in the same character space the laid-out paragraph uses.
  List<(int, int, int)> _ranges = const [];

  RenderParagraph? get _paragraph {
    final ro = _textKey.currentContext?.findRenderObject();
    return ro is RenderParagraph ? ro : null;
  }

  /// Vertical offset of a verse's first glyph inside this paragraph, or null.
  double? offsetOfAyah(int ayahIndex) {
    final p = _paragraph;
    if (p == null) return null;
    for (final r in _ranges) {
      if (r.$3 != ayahIndex) continue;
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: r.$1, extentOffset: r.$2),
      );
      if (boxes.isEmpty) return null;
      return boxes.first.top;
    }
    return null;
  }

  /// Where the verse at [ayahIndex] ENDS inside this paragraph - its last
  /// line's bottom.
  double? bottomOfAyah(int ayahIndex) {
    final p = _paragraph;
    if (p == null) return null;
    double? bottom;
    for (final r in _ranges) {
      if (r.$3 != ayahIndex) continue;
      for (final b in p.getBoxesForSelection(
          TextSelection(baseOffset: r.$1, extentOffset: r.$2))) {
        if (bottom == null || b.bottom > bottom) bottom = b.bottom;
      }
    }
    return bottom;
  }

  /// The verse under [local], or null when the tap landed on empty space.
  Ayah? _ayahAt(Offset local) {
    final p = _paragraph;
    if (p == null) return null;
    final pos = p.getPositionForOffset(local);
    for (final r in _ranges) {
      if (pos.offset >= r.$1 && pos.offset < r.$2) return widget.ayahs[r.$3];
    }
    return null;
  }

  /// The quarter whose «۞» is under [local], or null. The mark is the
  /// first character of its ayah; its own glyph box, a little enlarged, is
  /// the target, so the words beside it stay the page's.
  RubInfo? _rubMarkAt(Offset local) {
    final rubAt = widget.rubAt;
    final p = _paragraph;
    if (rubAt == null || p == null) return null;
    for (final r in _ranges) {
      final ayah = widget.ayahs[r.$3];
      if (!bodyOf(ayah).startsWith(rubElHizbMark)) continue;
      final info = rubAt(ayah);
      if (info == null) continue;
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: r.$1, extentOffset: r.$1 + 1),
      );
      for (final b in boxes) {
        if (b.toRect().inflate(10).contains(local)) return info;
      }
    }
    return null;
  }

  /// The kashida plan and what it was made for (the words, the width, the
  /// style), so it is worked out once per page and width, not per frame.
  (int, Map<int, int>)? _plan;

  /// Where to draw letters longer so the lines fill by kashida — see
  /// `kashida.dart`. Empty when the elongation would move a line break.
  Map<int, int> _kashidaFor(
    BuildContext context,
    List<String> texts,
    double width,
    double side,
  ) {
    final style = DefaultTextStyle.of(context).style.merge(widget.textStyle);
    final scaler = MediaQuery.textScalerOf(context);
    final key = Object.hash(
        width, style, scaler, side, Object.hashAll(texts));
    if (_plan?.$1 == key) return _plan!.$2;
    final plan = planParagraphKashida(
      texts: texts,
      width: width,
      style: style,
      marker: Size(side + 4, side),
      textScaler: scaler,
    );
    _plan = (key, plan);
    return plan;
  }

  /// The width the paragraph was last laid out at, read back from the
  /// paragraph after the frame. NOT a `LayoutBuilder`: the page sits in a
  /// `SliverFillRemaining`, which asks its child for its intrinsic height,
  /// and a `LayoutBuilder` cannot answer that — it threw, and the Qur'an
  /// tab came up BLANK on emulator-5554 (2026-10-02) while every embedded
  /// test passed. So the first frame is drawn without kashida and the plan
  /// follows one frame later, then is kept for that width.
  double? _width;

  void _readWidth() {
    if (!mounted) return;
    final ro = _textKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    final w = ro.constraints.maxWidth;
    if (w.isFinite && w != _width) setState(() => _width = w);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _readWidth());
    return _build(context, _width ?? double.infinity);
  }

  Widget _build(BuildContext context, double width) {
    final spans = <InlineSpan>[];
    final ranges = <(int, int, int)>[];
    final markers = <FlowingMarker>[];
    final side = AyahMarker.sizeFor(bare: widget.bare);
    var offset = 0;

    final texts = [
      for (var i = widget.from; i <= widget.to; i++)
        '${shapeQuranForDisplay(bodyOf(widget.ayahs[i]))} ',
    ];
    final plan = width.isFinite
        ? _kashidaFor(context, texts, width, side)
        : const <int, int>{};
    var plainBase = 0;

    for (var i = widget.from; i <= widget.to; i++) {
      final ayah = widget.ayahs[i];
      final isPlaying = i == widget.playingIndex;
      final source = texts[i - widget.from];
      final text = applyKashida(source, plainBase, plan);
      plainBase += source.length + 1;

      spans.add(
        TextSpan(
          text: text,
          // The wash is `AyahWashPainter` (own glyph boxes); only ink here.
          style: isPlaying
              ? widget.textStyle.copyWith(color: widget.mt.inkOnHighlight)
              : widget.textStyle,
        ),
      );
      ranges.add((offset, offset + text.length, i));
      offset += text.length;

      // Room only - the marker is painted by `FlowingMarkersPainter` at this
      // placeholder's own text position (see there for why).
      markers.add((offset: offset, number: ayah.ayahNumber, playing: isPlaying));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: side + 4, height: side),
        ),
      );
      offset += 1; // a WidgetSpan occupies one placeholder character
    }
    _ranges = ranges;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final rub = _rubMarkAt(d.localPosition);
        if (rub != null) {
          showRubBubble(context, rub, d.globalPosition);
          return;
        }
        widget.onBackgroundTap?.call();
      },
      onLongPressStart: (d) {
        final ayah = _ayahAt(d.localPosition);
        if (ayah != null) widget.onAyahLongPress(ayah);
      },
      child: CustomPaint(
        painter: AyahWashPainter(
          textKey: _textKey,
          color: widget.mt.highlightPlaying,
          range: [
            for (final r in ranges)
              if (r.$3 == widget.playingIndex) (r.$1, r.$2 - 1),
          ].firstOrNull,
        ),
        foregroundPainter: FlowingMarkersPainter(
          textKey: _textKey,
          markers: markers,
          mt: widget.mt,
          bare: widget.bare,
          baseStyle: DefaultTextStyle.of(context).style,
        ),
        child: Text.rich(
          TextSpan(children: spans),
          key: _textKey,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
