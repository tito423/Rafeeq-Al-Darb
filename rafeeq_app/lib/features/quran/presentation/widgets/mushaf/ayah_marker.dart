import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../../core/utils/digits.dart' show localizeDigits;
import '../../../data/mushaf_theme.dart';

/// The end-of-ayah ornament: a small rosette carrying the Arabic-Indic ayah
/// number. Used as a widget where each verse has its own row (cards), and
/// painted by [FlowingMarkersPainter] inside a flowing paragraph.
class AyahMarker extends StatelessWidget {
  final int number;
  final bool playing;
  final MushafTheme mt;

  /// Draw the marker as a filled disc instead of the open rosette — the
  /// reading layout's one piece of ornament, kept because a verse still has
  /// to end somewhere visible.
  final bool bare;

  const AyahMarker({
    super.key,
    required this.number,
    required this.mt,
    this.playing = false,
    this.bare = false,
  });

  /// The marker's square side.
  static double sizeFor({required bool bare}) => bare ? 26.0 : 32.0;

  @override
  Widget build(BuildContext context) {
    final gold = mt.gold;
    final size = sizeFor(bare: bare);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (bare)
            // A filled disc rather than the open rosette: it reads as a full
            // stop at a glance and takes less of the line, which is the
            // difference the owner pointed at in the app he reads in.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: playing ? 1.0 : 0.88),
              ),
              child: SizedBox(width: size, height: size),
            )
          else
            CustomPaint(
              size: Size(size, size),
              painter: RosettePainter(
                color: gold.withValues(alpha: playing ? 1.0 : 0.85),
              ),
            ),
          // «صغر الارقام … وخليها في النص بالظبط». Two faults: the size was
          // measured against the whole box while a rosette's points stick out
          // past its usable middle, and `height: 1.0` alone does not centre a
          // glyph - the font's ascent and descent still pad the line box and
          // Arabic-Indic digits sit low in it. See `numberScale` below.
          Text(
            arabicNumber(number),
            textHeightBehavior: numberHeightBehavior,
            style: numberStyle(mt: mt, bare: bare, number: number),
          ),
        ],
      ),
    );
  }

  static const numberHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle numberStyle({
    required MushafTheme mt,
    required bool bare,
    required int number,
  }) => TextStyle(
    fontSize: sizeFor(bare: bare) * numberScale(bare, number),
    // On the disc the number sits ON the gold, so it takes the paper's
    // colour; the rosette is an outline and the number stays gold inside.
    color: bare ? mt.paper : mt.gold,
    fontWeight: FontWeight.w700,
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// How much of the marker's box the number may take.
  ///
  /// The open rosette keeps less room than the filled disc, and every extra
  /// digit needs the glyphs to come down again so «٢٨٦» sits inside the same
  /// ornament «٧» does.
  static double numberScale(bool bare, int number) {
    final digits = number < 10 ? 1 : (number < 100 ? 2 : 3);
    final base = bare ? 0.36 : 0.32;
    return switch (digits) {
      1 => base,
      2 => base * 0.88,
      _ => base * 0.74,
    };
  }

  /// A mushaf numbers its verses in Arabic-Indic digits whatever language
  /// the interface is in.
  static String arabicNumber(int n) => localizeDigits('$n', 'ar');
}

/// An 8-point rosette (two overlapped squares).
class RosettePainter extends CustomPainter {
  final Color color;
  const RosettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..color = color;
    final c = size.center(Offset.zero);
    final r = size.width * 0.46;
    canvas.drawPath(_star(c, r, 0), paint);
    canvas.drawPath(_star(c, r, 45), paint);
  }

  Path _star(Offset c, double r, double rotationDeg) {
    final path = Path();
    final rad = rotationDeg * math.pi / 180;
    for (var i = 0; i < 4; i++) {
      final a = rad + i * math.pi / 2;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant RosettePainter old) => old.color != color;
}

/// One verse's marker in a flowing paragraph: the text offset of the
/// placeholder character reserved for it, and what to draw there.
typedef FlowingMarker = ({int offset, int number, bool playing});

/// Paints a flowing paragraph's verse markers in the slot each verse's
/// placeholder actually occupies - found from the verse's OWN WORDS.
///
/// WHY NOT `WidgetSpan` CHILDREN. Seen on the owner's Xiaomi (2026-09-26,
/// al-Fatiha, text mushaf): every line carried its markers in REVERSE -
/// ⑤ after the basmala, ① after «نستعين», ⑦ after «المستقيم». Measured in a
/// widget test on Flutter 3.38.7: in a right-to-left line the engine reports
/// the placeholders' boxes in visual (left-to-right) order, and
/// `RenderParagraph` gives them to its children in the order the spans were
/// written - so child i is drawn in the slot of the i-th from the LEFT.
/// Selecting the placeholder character is no way round it: its selection box
/// is reversed the same way (verse 0's came back at 30-50 px, its real slot
/// was 270-290). What IS right is where the text went, and the SET of slots.
///
/// So the `WidgetSpan` is an empty box that reserves the room, and each
/// marker is drawn in the slot touching the left of its verse's closing
/// space on that line - or, when the line broke right after that space, the
/// first slot of the next line (see [resolveMarkerSlots]). This holds
/// whichever order a future engine reports.
///
/// The same fault is what the owner saw earlier as «② inside verse 3's wash
/// on Maryam» (see `AyahWashPainter`).
class FlowingMarkersPainter extends CustomPainter {
  final GlobalKey textKey;
  final List<FlowingMarker> markers;
  final MushafTheme mt;
  final bool bare;

  /// The paragraph's inherited text style, so the digits are set in the same
  /// font a `Text` in the marker would have used.
  final TextStyle baseStyle;

  FlowingMarkersPainter({
    required this.textKey,
    required this.markers,
    required this.mt,
    required this.bare,
    required this.baseStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ro = textKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    final side = AyahMarker.sizeFor(bare: bare);
    final slots = resolveMarkerSlots(ro, [for (final m in markers) m.offset]);
    for (var i = 0; i < markers.length; i++) {
      final m = markers[i];
      final slot = slots[i];
      if (slot == null) continue;
      final center = slot.center;
      final rect = Rect.fromCenter(center: center, width: side, height: side);
      final gold = mt.gold;
      if (bare) {
        canvas.drawCircle(
          center,
          side / 2,
          Paint()..color = gold.withValues(alpha: m.playing ? 1.0 : 0.88),
        );
      } else {
        canvas.save();
        canvas.translate(rect.left, rect.top);
        RosettePainter(
          color: gold.withValues(alpha: m.playing ? 1.0 : 0.85),
        ).paint(canvas, rect.size);
        canvas.restore();
      }
      final tp = TextPainter(
        text: TextSpan(
          text: AyahMarker.arabicNumber(m.number),
          style: baseStyle.merge(
            AyahMarker.numberStyle(mt: mt, bare: bare, number: m.number),
          ),
        ),
        textDirection: TextDirection.rtl,
        textHeightBehavior: AyahMarker.numberHeightBehavior,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(FlowingMarkersPainter old) => true;
}

/// The slot each placeholder really occupies, for placeholders at [offsets]
/// in a right-to-left paragraph where the character before each one is the
/// space closing its verse. Null where no slot could be found.
///
/// The slots are taken as a set (their positions are right, only which is
/// which is not) and handed out by geometry: a verse's marker is the nearest
/// slot to the LEFT of its closing space on the same line; if there is none,
/// the line broke after the space and the marker opened the next line, so it
/// is the right-most slot there.
@visibleForTesting
List<Rect?> resolveMarkerSlots(RenderParagraph p, List<int> offsets) {
  Rect? boxOf(int from) {
    final b = p.getBoxesForSelection(
      TextSelection(baseOffset: from, extentOffset: from + 1),
    );
    return b.isEmpty ? null : b.first.toRect();
  }

  final pool = <Rect>[for (final o in offsets) ?boxOf(o)];
  // A slot is on the space's line when its middle is inside the space's box.
  bool sameLine(Rect slot, Rect space) =>
      slot.center.dy > space.top && slot.center.dy < space.bottom;

  final out = <Rect?>[];
  for (final o in offsets) {
    final space = o > 0 ? boxOf(o - 1) : null;
    if (space == null || pool.isEmpty) {
      out.add(null);
      continue;
    }
    Rect? pick;
    for (final s in pool) {
      if (!sameLine(s, space) || s.right > space.left + 1) continue;
      if (pick == null || s.right > pick.right) pick = s;
    }
    if (pick == null) {
      // The next line: the smallest top below the space, its right-most slot.
      final below = pool.where((s) => s.top >= space.bottom - 1).toList();
      if (below.isNotEmpty) {
        final top = below.map((s) => s.top).reduce((a, b) => a < b ? a : b);
        for (final s in below) {
          if ((s.top - top).abs() > 1) continue;
          if (pick == null || s.right > pick.right) pick = s;
        }
      }
    }
    if (pick != null) pool.remove(pick);
    out.add(pick);
  }
  return out;
}
