import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';

/// Renders one mushaf page as real Uthmani text laid out per the real
/// Madani page boundaries (from the bundled database), as one continuous
/// justified paragraph — the way a printed mushaf actually reads — rather
/// than a separate row per ayah.
///
/// Three reading affordances, matching the image-mode page:
///  - **scrolls** vertically when a page's text is taller than the screen
///    (`SingleChildScrollView`) — text no longer gets silently shrunk to fit;
///  - **font size** is controlled from `QuranScreen`'s app bar and just
///    reflows this paragraph, so it always stays crisp (real text, never a
///    scaled bitmap);
///  - **pinch-to-zoom** (`InteractiveViewer`, same `minScale`/`maxScale` as
///    `MushafPageView`) for an optical zoom on top of that, high-quality for
///    the same reason — Flutter renders text as vector glyphs, so scaling it
///    up never blurs.
class MushafTextPage extends StatefulWidget {
  final List<Ayah> ayahs;

  /// (surahId, surahNameAr) shown as a header when a surah starts on this page.
  final (int, String)? surahHeader;
  final void Function(Ayah ayah) onAyahTap;
  final double fontScale;

  const MushafTextPage({
    super.key,
    required this.ayahs,
    required this.surahHeader,
    required this.onAyahTap,
    this.fontScale = 1.0,
  });

  @override
  State<MushafTextPage> createState() => _MushafTextPageState();
}

class _MushafTextPageState extends State<MushafTextPage> {
  final TransformationController _transform = TransformationController();
  final List<TapGestureRecognizer> _recognizers = [];

  /// Panning only makes sense once the user has actually pinched past 1×
  /// zoom — before that there's nothing to pan, so it stays off until then.
  /// (An earlier version of this comment claimed a plain swipe never reaches
  /// the reader's page-turning `PageView` past `InteractiveViewer` — that
  /// was wrong: it was this slow emulator's animation/frame lag being
  /// mistaken for a dropped gesture from screenshotting too soon after the
  /// swipe. Re-tested with a longer wait: swiping through the zoomed
  /// `InteractiveViewer` genuinely turns the page, same as the ‹ › buttons.)
  bool _panEnabled = false;

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
    _transform.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _panEnabled) setState(() => _panEnabled = zoomed);
  }

  @override
  void didUpdateWidget(covariant MushafTextPage old) {
    super.didUpdateWidget(old);
    if (old.ayahs != widget.ayahs) _buildRecognizers();
  }

  void _buildRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers
      ..clear()
      ..addAll(widget.ayahs.map(
        (a) => TapGestureRecognizer()..onTap = () => widget.onAyahTap(a),
      ));
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (widget.ayahs.isEmpty) {
      return const Center(child: Text('—'));
    }

    final paper = isDark ? AppColors.nightSurface : AppColors.paper;
    final ink = isDark ? AppColors.paperDark : AppColors.ink;
    final baseFont = 23.0 * widget.fontScale;

    return ClipRect(
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 3,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.surahHeader != null) _SurahBanner(name: widget.surahHeader!.$2),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (var i = 0; i < widget.ayahs.length; i++) ...[
                          TextSpan(
                            text: widget.ayahs[i].textUthmani,
                            recognizer: _recognizers[i],
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _AyahMarker(
                              number: widget.ayahs[i].ayahNumber,
                              fontScale: widget.fontScale,
                            ),
                          ),
                          const TextSpan(text: ' '),
                        ],
                      ],
                    ),
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: baseFont,
                      height: 2.05,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An ornamental surah-name banner, styled like a mushaf's own section
/// headers — a bordered cartouche rather than a plain pill.
class _SurahBanner extends StatelessWidget {
  final String name;
  const _SurahBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.4),
        gradient: LinearGradient(
          colors: [
            gold.withValues(alpha: 0.16),
            gold.withValues(alpha: 0.05),
            gold.withValues(alpha: 0.16),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        // The DB `name_ar` already reads "سُورَةُ ٱلْفَاتِحَةِ" — prefixing
        // another "سورة" produced the doubled header (P2‑1.1).
        name,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 22,
          color: gold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The end-of-ayah ornament: a small rosette carrying the Arabic-Indic ayah
/// number, inline with the text flow instead of on its own row.
class _AyahMarker extends StatelessWidget {
  final int number;
  final double fontScale;
  const _AyahMarker({required this.number, required this.fontScale});

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    final size = 25.0 * fontScale;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RosettePainter(color: gold.withValues(alpha: 0.85)),
            ),
            Text(
              _arabicNumber(number),
              style: TextStyle(
                fontSize: size * 0.42,
                color: gold,
                fontWeight: FontWeight.w700,
                fontFamily: 'AmiriQuran',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _arabicNumber(int n) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}

/// An 8-point rosette (two overlapped squares, the classic ayah-end motif
/// used across mushaf typography) instead of a plain circle.
class _RosettePainter extends CustomPainter {
  final Color color;
  const _RosettePainter({required this.color});

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
  bool shouldRepaint(covariant _RosettePainter old) => old.color != color;
}
