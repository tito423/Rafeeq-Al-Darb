import 'package:flutter/material.dart';

import '../../data/mushaf_edition.dart';

/// P3‑53 — a luxury "book cover" thumbnail for a mushaf edition.
///
/// The owner asked explicitly NOT to use the Fatiha page as an edition's
/// thumbnail, but a real bound-book cover: a leather board in an edition-
/// specific colour, an ornate gold Islamic frame, a central gold medallion
/// carrying the riwayah name, a cloth reading-ribbon hanging from the foot, and
/// a soft 3‑D shadow that lifts the spine off the page.
///
/// Everything is drawn (CustomPaint + gradients), so it ships zero image assets
/// and stays crisp at any [width]; the true 3:4 board proportion is preserved
/// and the ribbon overhangs below it.
class QuranBookCoverThumbnail extends StatelessWidget {
  final MushafEdition edition;

  /// Board width in logical px. Height follows the 3:4 book ratio; the ribbon
  /// hangs a little below that.
  final double width;

  const QuranBookCoverThumbnail({
    super.key,
    required this.edition,
    this.width = 74,
  });

  /// Per-edition leather palette (deep → base → sheen). Distinct luxury colours
  /// so the shelf reads at a glance. Keyed by the ids actually shipped in
  /// `editions.json`; unknown ids fall back to royal emerald.
  static const Map<String, _Leather> _palette = {
    // Madinah Hafs — royal emerald green.
    'hafs_kfqc': _Leather(Color(0xFF063D27), Color(0xFF0B5D3B), Color(0xFF14814F)),
    // Coloured Tajweed — deep maroon (نبيتي).
    'tajweed_color':
        _Leather(Color(0xFF460B18), Color(0xFF6E1327), Color(0xFF922038)),
    // Shu'bah — deep plum.
    'shubah_kfqc': _Leather(Color(0xFF241238), Color(0xFF3A2350), Color(0xFF553472)),
    // Duri — dark bronze/olive.
    'douri_kfqc': _Leather(Color(0xFF2A2408), Color(0xFF44380F), Color(0xFF6A571A)),
    // Qalun — wine maroon.
    'qaloon': _Leather(Color(0xFF3E1019), Color(0xFF5A1E2B), Color(0xFF833141)),
    // Warsh — royal navy (كحلي).
    'warsh': _Leather(Color(0xFF0B1D3A), Color(0xFF12294F), Color(0xFF1E427E)),
  };

  /// Medallion text override where the first riwayah word would be ambiguous
  /// (e.g. the Tajweed mushaf is also Hafs — show "تجويد", not a second "حفص").
  static const Map<String, String> _medallionOverride = {
    'tajweed_color': 'تجويد',
  };

  static const _Leather _fallback =
      _Leather(Color(0xFF063D27), Color(0xFF0B5D3B), Color(0xFF14814F));

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldSoft = Color(0xFFE8C96A);
  static const Color _goldDeep = Color(0xFF9E7B1E);

  /// A short label for the medallion — the first word of the riwayah
  /// ("حفص عن عاصم" → "حفص"), which is what a reader scans covers by.
  String get _medallion {
    final override = _medallionOverride[edition.id];
    if (override != null) return override;
    final r = edition.riwayahAr.trim();
    if (r.isEmpty) return edition.nameAr.characters.take(4).toString();
    return r.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final leather = _palette[edition.id] ?? _fallback;
    final height = width * 4 / 3;
    final ribbonOverhang = width * 0.16;
    final medallionSize = width * 0.5;

    return SizedBox(
      width: width,
      height: height + ribbonOverhang,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reading ribbon, drawn BEHIND the board so its top tucks under the
          // foot of the cover and only the hanging tail shows.
          Positioned(
            top: height * 0.62,
            left: width * 0.24,
            child: _Ribbon(
              width: width * 0.13,
              height: ribbonOverhang + height * 0.38,
              color: const Color(0xFF9B1B2E),
            ),
          ),
          // The leather board.
          SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.06),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [leather.sheen, leather.base, leather.deep],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: width * 0.18,
                    offset: Offset(0, width * 0.08),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Soft leather sheen highlight, top-centre.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width * 0.06),
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.55),
                          radius: 1.0,
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Gold ornamental frame + corner flourishes.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FramePainter(
                        gold: _gold,
                        goldSoft: _goldSoft,
                      ),
                    ),
                  ),
                  // Central gold medallion with the riwayah name.
                  Center(
                    child: Container(
                      width: medallionSize,
                      height: medallionSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [_goldSoft, _gold, _goldDeep],
                          stops: [0.0, 0.6, 1.0],
                        ),
                        border: Border.all(
                          color: const Color(0xFF7A5E12),
                          width: width * 0.015,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: width * 0.05,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.03),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _medallion,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                color: const Color(0xFF3A2A08),
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                                fontSize: medallionSize * 0.34,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A leather colour triple: deep shadow, base tone, top sheen.
class _Leather {
  final Color deep;
  final Color base;
  final Color sheen;
  const _Leather(this.deep, this.base, this.sheen);
}

/// The hanging cloth reading-ribbon, with a notched (swallow-tail) foot.
class _Ribbon extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  const _Ribbon({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color,
              Color.lerp(color, Colors.white, 0.22)!,
              color,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final notch = size.width * 0.55;
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - notch)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Draws the double gold rule inset from the board edge plus a small diamond
/// flourish at each inner corner — the classic printed-mushaf border.
class _FramePainter extends CustomPainter {
  final Color gold;
  final Color goldSoft;
  const _FramePainter({required this.gold, required this.goldSoft});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..color = gold;
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..color = goldSoft.withValues(alpha: 0.85);

    final r1 = w * 0.08;
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.09, w * 0.09, w - w * 0.18, size.height - w * 0.18),
      Radius.circular(r1),
    );
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, w * 0.15, w - w * 0.30, size.height - w * 0.30),
      Radius.circular(r1 * 0.7),
    );
    canvas.drawRRect(outerRect, outer);
    canvas.drawRRect(innerRect, inner);

    // Corner diamonds on the inner frame.
    final diamond = Paint()..color = gold;
    final d = w * 0.05;
    for (final c in [
      Offset(innerRect.left, innerRect.top),
      Offset(innerRect.right, innerRect.top),
      Offset(innerRect.left, innerRect.bottom),
      Offset(innerRect.right, innerRect.bottom),
    ]) {
      final path = Path()
        ..moveTo(c.dx, c.dy - d)
        ..lineTo(c.dx + d, c.dy)
        ..lineTo(c.dx, c.dy + d)
        ..lineTo(c.dx - d, c.dy)
        ..close();
      canvas.drawPath(path, diamond);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) => false;
}
