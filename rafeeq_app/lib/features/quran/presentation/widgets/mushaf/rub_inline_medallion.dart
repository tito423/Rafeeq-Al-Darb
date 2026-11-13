import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mushaf_theme.dart';
import '../../../data/rub_el_hizb.dart';
import '../../../data/text_layout_provider.dart';
import 'rub_margin_mark.dart'
    show RubPlateOverlay, RubPlateOverlayState, rubMedallionsProvider;

/// The owner's medallion drawn IN PLACE OF the «۞» in the text mushaf.
///
/// Owner, 2026-11-13 (phone screenshots): the medallion plate that slid in
/// over the page covered ayah words and ayah numbers - «تداخل العلامات سيئ
/// جدا» - and: «انقي تلاتة من الأربعة … وحطهم مكان علامات الأرباع اللي في
/// النصي … عندك ٣ طرق عرض للنصي فحط كل علامة لكل طريقة عرض». So each text
/// layout has ONE medallion of its own, standing where the quarter sign
/// stands in the line; nothing floats over the words.
///
/// The «۞» glyph stays in the text (transparent and enlarged, see
/// [rubMarkStyle]) so every text offset is what it was and the kashida plan
/// measures the same line the page draws; the medallion is painted inside
/// the enlarged glyph's own box, between the ayah number and the word.
///
/// The fourth medallion (the eight-point star, `hizb.png`) is the one left
/// out. Index into [rubMedallionsProvider]: 0 hizb, 1 quarter, 2 half,
/// 3 three_quarters.
/// Radius of each medallion's empty navy heart over the image side, in
/// [rubMedallionsProvider] order, as `build_rub_medallions.py` printed it.
const medallionHearts = [0.2065, 0.2329, 0.2170, 0.2031];

int rubMedallionFor(QuranTextLayout layout) => switch (layout) {
  // The page layout is the printed page's twin: the richest star.
  QuranTextLayout.page => 3,
  // Cards: the flower, softer beside a card's own frame.
  QuranTextLayout.cards => 2,
  // The stripped reading layout: the plain ring, the quietest of the four.
  QuranTextLayout.reading => 1,
};

/// The span for an ayah body that may open with «۞»: the sign itself is
/// transparent ink, everything after it keeps [style].
TextSpan rubMarkedSpan(String text, TextStyle style) {
  if (!text.startsWith(rubElHizbMark)) {
    return TextSpan(text: text, style: style);
  }
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: rubElHizbMark, style: rubMarkStyle(style)),
      TextSpan(text: text.substring(rubElHizbMark.length)),
    ],
  );
}

/// The «۞» itself: transparent, and set 2.3 times larger with its line
/// height divided to match, so it takes about an ayah number's width on the
/// line without making the line taller - room of its own for the medallion,
/// clear of the words beside it. (Letter spacing was tried first: the
/// engine gave a lone sign none of it, measured on API 24.) The kashida
/// plan lays the sign out with this same style
/// (`planParagraphKashida.rubMarkStyle`).
TextStyle rubMarkStyle(TextStyle style) => style.copyWith(
  color: const Color(0x00000000),
  fontSize: (style.fontSize ?? 24) * 2.3,
  // Well under the line's own height, so the big glyph's ascent never
  // lifts the line (at exactly 1/2.3 the line grew, seen on API 24).
  height: (style.height ?? 1.2) / 2.3 * 0.6,
);

/// Paints [image] over the «۞» at each of [offsets] in the paragraph of
/// [textKey]. The painter's canvas must share the paragraph's origin.
class RubInlineMedallionPainter extends CustomPainter {
  final GlobalKey textKey;
  final List<int> offsets;
  final ui.Image? image;

  /// The page's paper: the medallion's navy heart is filled with it
  /// (owner, 2026-11-13: «بلاش القلب الغامق ده»), so it reads as an
  /// ornamented ring on the page rather than a dark hole in the line.
  final Color paper;

  /// The heart's radius over the image side ([medallionHearts]).
  final double heart;

  RubInlineMedallionPainter({
    required this.textKey,
    required this.offsets,
    required this.image,
    required this.paper,
    required this.heart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    final ro = textKey.currentContext?.findRenderObject();
    if (img == null || offsets.isEmpty) return;
    if (ro is! RenderParagraph || !ro.hasSize) return;
    for (final offset in offsets) {
      final boxes = ro.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      );
      if (boxes.isEmpty) continue;
      final r = boxes.first.toRect();
      // The medallion fills the gap between its neighbours on the line -
      // the ayah number before it and the word after it - as measured, not
      // as assumed: which side each one lands on was guessed wrong three
      // times on API 24, so the sides are read from the boxes themselves.
      Rect? boxAt(int at) {
        if (at < 0) return null;
        final b = ro.getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: at + 1),
        );
        return b.isEmpty ? null : b.first.toRect();
      }

      // The line's own band is the word after the sign's: the enlarged
      // glyph's box is taller than its line and, at a line's start, reached
      // up into the line above (API 24: the previous line's ayah number was
      // taken for a neighbour and the medallion got no room at all).
      final band = boxAt(offset + 1) ?? r;
      var left = r.left;
      var right = r.right;
      for (final n in [boxAt(offset - 1), boxAt(offset + 1)]) {
        if (n == null) continue;
        if ((n.center.dy - band.center.dy).abs() >= band.height / 2) continue;
        if (n.center.dx < r.center.dx) {
          left = math.max(left, n.right);
        } else {
          right = math.min(right, n.left);
        }
      }
      final d = math.min(right - left - 4, band.height * 0.92);
      if (d <= 0) continue;
      final centre = Offset((left + right) / 2, band.center.dy);
      canvas.drawImageRect(
        img,
        Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: centre, width: d, height: d),
        Paint()..filterQuality = FilterQuality.medium,
      );
      // A hair over the heart's edge so no navy rim shows round the paper.
      canvas.drawCircle(centre, d * heart + 0.6, Paint()..color = paper);
    }
  }

  @override
  bool shouldRepaint(RubInlineMedallionPainter old) =>
      old.image != image ||
      old.paper != paper ||
      old.textKey != textKey ||
      !_sameList(old.offsets, offsets);

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A plain ayah text (the cards layout) whose «۞» is the layout's
/// medallion. With [rub] it also carries the quarter plate, exactly as the
/// flowing layouts do: by itself when the card comes into view, and again
/// on a tap on the medallion (v4.6.0 shipped without either here - the
/// owner found it). Any other tap is [onOtherTap], the page's own.
class RubMarkedText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle style;
  final QuranTextLayout layout;
  final TextAlign textAlign;
  final Color paper;
  final MushafTheme? mt;
  final RubInfo? rub;
  final int page;
  final VoidCallback? onOtherTap;

  const RubMarkedText({
    super.key,
    required this.text,
    required this.style,
    required this.layout,
    required this.paper,
    this.mt,
    this.rub,
    this.page = 1,
    this.onOtherTap,
    this.textAlign = TextAlign.right,
  });

  @override
  ConsumerState<RubMarkedText> createState() => _RubMarkedTextState();
}

class _RubMarkedTextState extends ConsumerState<RubMarkedText> {
  final GlobalKey _key = GlobalKey();
  final GlobalKey<RubPlateOverlayState> _plateKey = GlobalKey();

  /// Is [local] on the medallion (the sign's box, a little enlarged)?
  bool _onMedallion(Offset local) {
    final ro = _key.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return false;
    final b = ro.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    return b.isNotEmpty && b.first.toRect().inflate(10).contains(local);
  }

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      rubMarkedSpan(widget.text, widget.style),
      key: _key,
      textAlign: widget.textAlign,
      textDirection: TextDirection.rtl,
    );
    if (!widget.text.startsWith(rubElHizbMark)) return text;
    final images = ref.watch(rubMedallionsProvider).valueOrNull;
    final marked = CustomPaint(
      foregroundPainter: RubInlineMedallionPainter(
        textKey: _key,
        offsets: const [0],
        image: images?[rubMedallionFor(widget.layout)],
        paper: widget.paper,
        heart: medallionHearts[rubMedallionFor(widget.layout)],
      ),
      child: text,
    );
    final rub = widget.rub;
    final mt = widget.mt;
    if (rub == null || mt == null) return marked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onMedallion(d.localPosition)
          ? _plateKey.currentState?.show(0)
          : widget.onOtherTap?.call(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          marked,
          Positioned.fill(
            child: RubPlateOverlay(
              key: _plateKey,
              textKey: _key,
              marks: [(0, rub)],
              edge: 0,
              page: widget.page,
              mt: mt,
              baseStyle: DefaultTextStyle.of(context).style,
            ),
          ),
        ],
      ),
    );
  }
}
