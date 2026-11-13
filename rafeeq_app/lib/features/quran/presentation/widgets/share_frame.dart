/// The share card's frame: its colours ([ShareStyle] / [SharePalette]),
/// its ornament ([ShareFrame]) and the painter that draws both. Split from
/// `ayah_share_card.dart` when the frames grew to five (2026-11-13).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The colours of the frame.
enum ShareStyle {
  night,
  emerald,
  parchment,
  maroon,
  turquoise,
  ivory,
  sand,
  charcoal,
}

/// The ornament of the frame's band (owner, 2026-11-13: «إطارات زخرفة
/// أكتر»). All stay inside the same 46 px band, so the text plan holds.
enum ShareFrame { stars, interlace, scallop, rope, plain }

class SharePalette {
  final Color top;
  final Color bottom;
  final Color band;
  final Color gold;
  final Color ink;
  final Color soft;
  const SharePalette({
    required this.top,
    required this.bottom,
    required this.band,
    required this.gold,
    required this.ink,
    required this.soft,
  });

  static SharePalette of(ShareStyle s) => switch (s) {
    ShareStyle.night => const SharePalette(
      top: Color(0xFF0F2A44),
      bottom: Color(0xFF06131F),
      band: Color(0xFF14365A),
      gold: Color(0xFFD9B44A),
      ink: Color(0xFFF6F1E3),
      soft: Color(0xFFC5CFD8),
    ),
    ShareStyle.emerald => const SharePalette(
      top: Color(0xFF0E4636),
      bottom: Color(0xFF052018),
      band: Color(0xFF14594A),
      gold: Color(0xFFE0BE5A),
      ink: Color(0xFFF6F1E3),
      soft: Color(0xFFC4D6CE),
    ),
    ShareStyle.parchment => const SharePalette(
      top: Color(0xFFF8EFD6),
      bottom: Color(0xFFEAD9AE),
      band: Color(0xFFE2CB93),
      gold: Color(0xFF8E6B1E),
      ink: Color(0xFF2E2110),
      soft: Color(0xFF5B4A2C),
    ),
    ShareStyle.maroon => const SharePalette(
      top: Color(0xFF5A1620),
      bottom: Color(0xFF2A080D),
      band: Color(0xFF6E1E2A),
      gold: Color(0xFFE2C06A),
      ink: Color(0xFFF6F1E3),
      soft: Color(0xFFDCC8C2),
    ),
    ShareStyle.turquoise => const SharePalette(
      top: Color(0xFF0E5A63),
      bottom: Color(0xFF06292E),
      band: Color(0xFF13707A),
      gold: Color(0xFFF0D27A),
      ink: Color(0xFFF4F7F2),
      soft: Color(0xFFC2DCDC),
    ),
    // Light grounds: the ornament is lapis on ivory, green on sand.
    ShareStyle.ivory => const SharePalette(
      top: Color(0xFFFFFCF4),
      bottom: Color(0xFFF1EBDD),
      band: Color(0xFFE4DDCB),
      gold: Color(0xFF1F4E8C),
      ink: Color(0xFF1B2433),
      soft: Color(0xFF4A5566),
    ),
    ShareStyle.sand => const SharePalette(
      top: Color(0xFFF3E6CC),
      bottom: Color(0xFFE2CDA4),
      band: Color(0xFFD5BC8C),
      gold: Color(0xFF1E5E46),
      ink: Color(0xFF2A2214),
      soft: Color(0xFF574A33),
    ),
    ShareStyle.charcoal => const SharePalette(
      top: Color(0xFF26282C),
      bottom: Color(0xFF0E0F11),
      band: Color(0xFF303338),
      gold: Color(0xFFD4AF37),
      ink: Color(0xFFF3EFE6),
      soft: Color(0xFFC3C0B8),
    ),
  };
}

/// The eight-pointed star (two squares, one turned an eighth) that Islamic
/// geometric work is built on - the same figure as «۞».
Path eightPointStar(Offset centre, double radius, {double turn = 0}) {
  final inner = radius * 0.7654; // where the two squares cross
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final r = i.isEven ? radius : inner;
    final a = turn + i * math.pi / 8;
    final pt = centre + Offset(math.cos(a) * r, math.sin(a) * r);
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  return path..close();
}

/// The frame: a gradient ground, a band 16..46 px in from the edge held by
/// gold rules, and the chosen [frame]'s ornament in it.
class ShareFramePainter extends CustomPainter {
  final SharePalette c;
  final ShareFrame frame;
  const ShareFramePainter(this.c, [this.frame = ShareFrame.stars]);

  static const double _mid = 31; // the band's centre line, from the edge
  static const double _corner = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.top, c.bottom],
        ).createShader(full),
    );
    if (frame == ShareFrame.stars || frame == ShareFrame.interlace) {
      _lattice(canvas, size);
    }
    if (frame == ShareFrame.plain) {
      _plain(canvas, size);
      return;
    }
    _band(canvas, size);
    switch (frame) {
      case ShareFrame.stars:
        _starChain(canvas, size);
        _starMedallions(canvas, size);
      case ShareFrame.interlace:
        _interlace(canvas, size);
        _squareKnots(canvas, size);
      case ShareFrame.scallop:
        _scallops(canvas, size);
        _rosettes(canvas, size);
      case ShareFrame.rope:
        _rope(canvas, size);
        _palmettes(canvas, size);
      case ShareFrame.plain:
        break;
    }
  }

  /// A faint lattice: eight-pointed stars (or hexagons for the interlace
  /// frame) with a small star between four.
  void _lattice(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = c.gold.withValues(alpha: 0.075);
    const step = 60.0;
    canvas.save();
    canvas.clipRect(full.deflate(44));
    for (var y = 44.0 + step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width + step; x += step) {
        canvas.drawPath(
          frame == ShareFrame.stars
              ? eightPointStar(Offset(x, y), 19)
              : _polygon(Offset(x, y), 20, 6, 0),
          lattice,
        );
        canvas.drawPath(
          eightPointStar(
            Offset(x + step / 2, y + step / 2),
            7,
            turn: math.pi / 8,
          ),
          lattice,
        );
      }
    }
    canvas.restore();
  }

  void _band(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = c.gold;
    final outer = full.deflate(16);
    final inner = full.deflate(46);
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(outer, const Radius.circular(10)))
      ..addRRect(RRect.fromRectAndRadius(inner, const Radius.circular(4)));
    canvas.drawPath(band, Paint()..color = c.band);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(10)),
      line..strokeWidth = 2.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.deflate(5), const Radius.circular(7)),
      line..strokeWidth = 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(4)),
      line..strokeWidth = 1.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner.deflate(6), const Radius.circular(2)),
      line
        ..strokeWidth = 0.7
        ..color = c.gold.withValues(alpha: 0.55),
    );
  }

  /// The four runs along the band's centre line, between the corners.
  List<(Offset, Offset)> _runs(Size size) {
    final w = size.width, h = size.height;
    return [
      (const Offset(_corner, _mid), Offset(w - _corner, _mid)),
      (Offset(_corner, h - _mid), Offset(w - _corner, h - _mid)),
      (const Offset(_mid, _corner), Offset(_mid, h - _corner)),
      (Offset(w - _mid, _corner), Offset(w - _mid, h - _corner)),
    ];
  }

  List<Offset> _corners(Size size) => [
    const Offset(_corner, _corner),
    Offset(size.width - _corner, _corner),
    Offset(_corner, size.height - _corner),
    Offset(size.width - _corner, size.height - _corner),
  ];

  static Path _polygon(Offset at, double r, int n, double turn) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final a = turn + i * 2 * math.pi / n;
      final pt = at + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  static Path _diamond(Offset at, double r) => Path()
    ..moveTo(at.dx, at.dy - r)
    ..lineTo(at.dx + r, at.dy)
    ..lineTo(at.dx, at.dy + r)
    ..lineTo(at.dx - r, at.dy)
    ..close();

  // Stars: a chain of stars and diamonds, star medallions at the corners.
  void _starChain(Canvas canvas, Size size) {
    final fill = Paint()..color = c.gold;
    final dim = Paint()..color = c.gold.withValues(alpha: 0.6);
    for (final (from, to) in _runs(size)) {
      final n = ((to - from).distance / 30).floor();
      for (var i = 1; i < n; i++) {
        final at = Offset.lerp(from, to, i / n)!;
        canvas.drawPath(
          i.isEven ? eightPointStar(at, 5.2) : _diamond(at, 3.4),
          i.isEven ? fill : dim,
        );
      }
    }
  }

  void _starMedallions(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = c.gold;
    for (final at in _corners(size)) {
      canvas.drawCircle(at, 30, Paint()..color = c.bottom);
      canvas.drawCircle(at, 30, stroke..strokeWidth = 1.6);
      canvas.drawPath(eightPointStar(at, 24), Paint()..color = c.band);
      canvas.drawPath(eightPointStar(at, 24), stroke..strokeWidth = 1.5);
      canvas.drawPath(
        eightPointStar(at, 11, turn: math.pi / 8),
        Paint()..color = c.gold,
      );
      canvas.drawCircle(at, 3.2, Paint()..color = c.bottom);
    }
  }

  // Interlace: two zigzag strands crossing along the band, square knots
  // (two squares 45 degrees apart) at the corners.
  void _interlace(Canvas canvas, Size size) {
    Paint strand(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = c.gold.withValues(alpha: a);
    final dot = Paint()..color = c.gold;
    const amp = 8.0;
    for (final (from, to) in _runs(size)) {
      final len = (to - from).distance;
      final dir = (to - from) / len;
      final nrm = Offset(-dir.dy, dir.dx);
      final n = (len / 18).floor();
      final up = Path(), down = Path();
      for (var i = 0; i <= n; i++) {
        final at = Offset.lerp(from, to, i / n)!;
        final s = i.isEven ? 1.0 : -1.0;
        final p1 = at + nrm * amp * s, p2 = at - nrm * amp * s;
        if (i == 0) {
          up.moveTo(p1.dx, p1.dy);
          down.moveTo(p2.dx, p2.dy);
        } else {
          up.lineTo(p1.dx, p1.dy);
          down.lineTo(p2.dx, p2.dy);
        }
        if (i > 0 && i < n) {
          canvas.drawCircle(at, 1.5, dot);
        }
      }
      canvas.drawPath(down, strand(0.55));
      canvas.drawPath(up, strand(1));
    }
  }

  void _squareKnots(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = c.gold;
    for (final at in _corners(size)) {
      final box = Rect.fromCenter(center: at, width: 50, height: 50);
      canvas.drawRect(box, Paint()..color = c.bottom);
      canvas.drawRect(box, stroke);
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 30, height: 30),
        stroke,
      );
      canvas.drawPath(_polygon(at, 21.2, 4, 0), stroke);
      canvas.drawPath(eightPointStar(at, 8), Paint()..color = c.gold);
    }
  }

  // Arches: a row of small pointed arches standing on the inner rule,
  // twelve-petal rosettes at the corners.
  void _scallops(Canvas canvas, Size size) {
    final inner = (Offset.zero & size).deflate(42);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = c.gold;
    final dot = Paint()..color = c.gold;
    void edge(Offset from, Offset to, Offset inward) {
      final len = (to - from).distance;
      final dir = (to - from) / len;
      final n = (len / 22).floor();
      final step = len / n;
      for (var i = 0; i < n; i++) {
        final a = from + dir * (i * step);
        final b = from + dir * ((i + 1) * step);
        final mid = Offset.lerp(a, b, 0.5)!;
        final tip = mid - inward * 16;
        final ca = a - inward * 13, cb = b - inward * 13;
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(ca.dx, ca.dy, tip.dx, tip.dy)
            ..quadraticBezierTo(cb.dx, cb.dy, b.dx, b.dy),
          line,
        );
        final d = mid - inward * 6;
        canvas.drawCircle(d, 1.8, dot);
      }
    }

    final l = inner.left, r = inner.right, t = inner.top, bt = inner.bottom;
    const k = 12.0;
    edge(Offset(l + k, t), Offset(r - k, t), const Offset(0, 1));
    edge(Offset(l + k, bt), Offset(r - k, bt), const Offset(0, -1));
    edge(Offset(l, t + k), Offset(l, bt - k), const Offset(1, 0));
    edge(Offset(r, t + k), Offset(r, bt - k), const Offset(-1, 0));
  }

  void _rosettes(Canvas canvas, Size size) {
    for (final at in _corners(size)) {
      canvas.drawCircle(at, 27, Paint()..color = c.bottom);
      canvas.drawCircle(
        at,
        27,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.gold,
      );
      for (var i = 0; i < 12; i++) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(i * math.pi / 6);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -14), width: 7, height: 16),
          Paint()..color = c.gold.withValues(alpha: i.isEven ? 1 : 0.6),
        );
        canvas.restore();
      }
      canvas.drawCircle(at, 6, Paint()..color = c.band);
      canvas.drawCircle(at, 3, Paint()..color = c.gold);
    }
  }

  // Braid: a twisted cord along the band, palmettes at the corners.
  void _rope(Canvas canvas, Size size) {
    Paint strand(double a) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = c.gold.withValues(alpha: a);
    final full = strand(1), half = strand(0.5);
    for (final (from, to) in _runs(size)) {
      final len = (to - from).distance;
      final dir = (to - from) / len;
      final nrm = Offset(-dir.dy, dir.dx);
      final n = (len / 9).floor();
      for (var i = 0; i < n; i++) {
        final at = Offset.lerp(from, to, (i + 0.5) / n)!;
        final p0 = at - nrm * 7 - dir * 4;
        final p1 = at + nrm * 7 + dir * 4;
        final cp = at - dir * 1.5;
        canvas.drawPath(
          Path()
            ..moveTo(p0.dx, p0.dy)
            ..quadraticBezierTo(cp.dx, cp.dy, p1.dx, p1.dy),
          i.isEven ? full : half,
        );
      }
    }
  }

  void _palmettes(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (final (at, turn) in [
      (const Offset(_corner, _corner), -math.pi / 4),
      (Offset(w - _corner, _corner), math.pi / 4),
      (Offset(_corner, h - _corner), -math.pi * 3 / 4),
      (Offset(w - _corner, h - _corner), math.pi * 3 / 4),
    ]) {
      canvas.drawCircle(at, 26, Paint()..color = c.bottom);
      canvas.drawCircle(
        at,
        26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.gold,
      );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(turn);
      // A palmette pointing to the card's corner: a pointed middle leaf and
      // two curling side leaves.
      canvas.drawPath(
        Path()
          ..moveTo(0, 16)
          ..quadraticBezierTo(13, 6, 0, -20)
          ..quadraticBezierTo(-13, 6, 0, 16)
          ..close(),
        Paint()..color = c.gold,
      );
      for (final s in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(0, 14)
            ..quadraticBezierTo(s * 20, 12, s * 15, -8)
            ..quadraticBezierTo(s * 9, 4, 0, 8)
            ..close(),
          Paint()..color = c.gold.withValues(alpha: 0.65),
        );
      }
      canvas.drawCircle(const Offset(0, 3), 3, Paint()..color = c.band);
      canvas.restore();
    }
  }

  // Plain: two hairline rules and gold corner brackets, no band.
  void _plain(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = c.gold;
    canvas.drawRect(full.deflate(24), line..strokeWidth = 1.4);
    canvas.drawRect(full.deflate(30), line..strokeWidth = 0.6);
    final w = size.width, h = size.height;
    const k = 38.0, arm = 34.0;
    final thick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square
      ..color = c.gold;
    for (final (x, y, sx, sy) in [
      (k, k, 1.0, 1.0),
      (w - k, k, -1.0, 1.0),
      (k, h - k, 1.0, -1.0),
      (w - k, h - k, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + sx * arm, y)
          ..lineTo(x, y)
          ..lineTo(x, y + sy * arm),
        thick,
      );
      canvas.drawPath(_diamond(Offset(x, y), 4.5), Paint()..color = c.gold);
    }
  }

  @override
  bool shouldRepaint(ShareFramePainter old) => old.c != c || old.frame != frame;
}
