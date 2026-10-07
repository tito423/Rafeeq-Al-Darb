/// The look of a shelf in «مكتبتي»: its colours, its icon, and the row of
/// book spines that stands for its books.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/my_shelves.dart';
import '../../data/shelf_look.dart';

export '../../data/shelf_look.dart';

List<Color> paletteOf(Shelf s) =>
    shelfPalettes[s.colorIndex % shelfPalettes.length];

IconData iconOf(Shelf s) => shelfIcons[s.iconIndex % shelfIcons.length];

/// A row of book spines, one per book (up to [max]), each a different
/// height and tint so the row reads as books on a shelf. [sway] (0..1, from
/// an animation) tips each spine a little, out of step with its neighbours.
class BookSpines extends StatelessWidget {
  final List<String> bookIds;
  final Color base;
  final int max;
  final double height;
  final double sway;

  const BookSpines({
    super.key,
    required this.bookIds,
    required this.base,
    this.max = 7,
    this.height = 34,
    this.sway = 0,
  });

  @override
  Widget build(BuildContext context) {
    final shown = bookIds.take(max).toList();
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SpinesPainter(
          shown,
          base,
          sway,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpinesPainter extends CustomPainter {
  final List<String> ids;
  final Color base;
  final double sway;

  /// Books stand from the reading side: the right in Arabic and Urdu.
  final bool rtl;
  _SpinesPainter(this.ids, this.base, this.sway, {required this.rtl});

  @override
  void paint(Canvas canvas, Size size) {
    // The shelf board.
    final board = Paint()..color = Colors.black.withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - 3, size.width, 3),
        const Radius.circular(2),
      ),
      board,
    );
    if (ids.isEmpty) return;
    const w = 11.0, gap = 3.0;
    var x = 4.0;
    for (var i = 0; i < ids.length; i++) {
      final h = ids[i].hashCode;
      final hRatio = 0.62 + (h % 30) / 100; // 0.62 .. 0.91
      final bh = (size.height - 4) * hRatio;
      // Deep enough to read as bound leather, varied so the row is books.
      final light = 0.12 + (h % 7) * 0.07;
      final color = Color.lerp(base, Colors.white, light.clamp(0.0, 0.9))!;
      final tilt = math.sin((sway * 2 * math.pi) + i * 0.9) * 0.035; // radians
      canvas.save();
      canvas.translate(
        rtl ? size.width - x - w / 2 : x + w / 2,
        size.height - 3,
      );
      canvas.rotate(tilt);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2, -bh, w, bh),
        const Radius.circular(2),
      );
      canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.92));
      // Two gilt bands, as on a bound spine.
      final band = Paint()
        ..color = const Color(0xFFE8C766).withValues(alpha: 0.85);
      canvas.drawRect(Rect.fromLTWH(-w / 2 + 1.5, -bh + 4, w - 3, 1.4), band);
      canvas.drawRect(const Rect.fromLTWH(-w / 2 + 1.5, -9, w - 3, 1.4), band);
      canvas.restore();
      x += w + gap;
      if (x + w > size.width) break;
    }
  }

  @override
  bool shouldRepaint(_SpinesPainter old) =>
      old.sway != sway || old.base != base || old.ids != ids || old.rtl != rtl;
}
