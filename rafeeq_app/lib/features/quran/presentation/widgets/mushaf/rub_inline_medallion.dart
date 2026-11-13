import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/rub_el_hizb.dart';
import '../../../data/text_layout_provider.dart';
import 'rub_margin_mark.dart' show rubMedallionsProvider;

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

  RubInlineMedallionPainter({
    required this.textKey,
    required this.offsets,
    required this.image,
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
      Rect? sameLine(int at) {
        if (at < 0) return null;
        final b = ro.getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: at + 1),
        );
        if (b.isEmpty) return null;
        final n = b.first.toRect();
        return (n.center.dy - r.center.dy).abs() < r.height / 2 ? n : null;
      }

      var left = r.left;
      var right = r.right;
      // The line's own band comes from the word after the sign: the
      // enlarged glyph's box sits higher than the letters' line.
      var band = r;
      for (final (i, n) in [
        sameLine(offset - 1),
        sameLine(offset + 1),
      ].indexed) {
        if (n == null) continue;
        if (i == 1) band = n;
        if (n.center.dx < r.center.dx) {
          left = n.right;
        } else {
          right = n.left;
        }
      }
      final room = math.min(right - left, r.width);
      final d = math.min(room - 4, band.height * 0.92);
      final centre = Offset((left + right) / 2, band.center.dy);
      canvas.drawImageRect(
        img,
        Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: centre, width: d, height: d),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }

  @override
  bool shouldRepaint(RubInlineMedallionPainter old) =>
      old.image != image ||
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
/// medallion.
class RubMarkedText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle style;
  final QuranTextLayout layout;
  final TextAlign textAlign;

  const RubMarkedText({
    super.key,
    required this.text,
    required this.style,
    required this.layout,
    this.textAlign = TextAlign.right,
  });

  @override
  ConsumerState<RubMarkedText> createState() => _RubMarkedTextState();
}

class _RubMarkedTextState extends ConsumerState<RubMarkedText> {
  final GlobalKey _key = GlobalKey();

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
    return CustomPaint(
      foregroundPainter: RubInlineMedallionPainter(
        textKey: _key,
        offsets: const [0],
        image: images?[rubMedallionFor(widget.layout)],
      ),
      child: text,
    );
  }
}
