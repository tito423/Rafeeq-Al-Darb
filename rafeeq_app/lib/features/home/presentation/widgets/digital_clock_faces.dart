import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/clock_settings_provider.dart';

const _kTeal = Color(0xFF15C7B0);
const _kGold = Color(0xFFD4AF37);
const _kViolet = Color(0xFF9B6BFF);

const _kWesternDigits = '0123456789';
const _kArabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// Converts the ASCII digits in [s] to Arabic-Indic when [arabic] is set.
/// Anything that isn't a digit (the colon, the AM/PM marker) is left alone.
String localizeDigits(String s, bool arabic) {
  if (!arabic) return s;
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _kWesternDigits.indexOf(ch);
    b.write(i >= 0 ? _kArabicDigits[i] : ch);
  }
  return b.toString();
}

/// Ten digital clock faces, all reading the same live `DateTime`.
///
/// Like the analogue set, this owns its ticker so the faces that animate
/// between whole seconds (the flip cards, the second ring, the bars) actually
/// move, and so everything stops when the widget leaves the tree.
class DigitalClockFaceView extends StatefulWidget {
  final DigitalClockFace face;
  final bool use12Hour;
  final bool showSeconds;
  final bool arabicDigits;

  /// Localised "ص"/"م" (or AM/PM) — null in 24-hour mode.
  final String? meridiem;

  /// Height the face is laid out to. Every face scales off this one number so
  /// the Home card and the small gallery previews share exactly one drawing.
  final double height;

  /// The colour the numerals are drawn in. Defaults to white, which is what
  /// every face assumed before the Home card learned to follow the theme.
  final Color ink;

  const DigitalClockFaceView({
    super.key,
    required this.face,
    required this.use12Hour,
    required this.showSeconds,
    required this.arabicDigits,
    this.meridiem,
    this.height = 74,
    this.ink = Colors.white,
  });

  @override
  State<DigitalClockFaceView> createState() => _DigitalClockFaceViewState();
}

class _DigitalClockFaceViewState extends State<DigitalClockFaceView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final now = DateTime.now();
      if (now.difference(_now).inMilliseconds < 40) return;
      setState(() => _now = now);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// "HH:mm" or "HH:mm:ss", already in the reader's 12/24-hour choice.
  String get _text {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = widget.use12Hour
        ? (_now.hour % 12 == 0 ? 12 : _now.hour % 12)
        : _now.hour;
    return widget.showSeconds
        ? '${two(h)}:${two(_now.minute)}:${two(_now.second)}'
        : '${two(h)}:${two(_now.minute)}';
  }

  /// Shorthand, since every face reaches for it.
  Color get ink => widget.ink;

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final body = switch (widget.face) {
      DigitalClockFace.minimal => _minimal(h),
      DigitalClockFace.neon => _neon(h),
      DigitalClockFace.segment =>
        _painted(h, _SegmentPainter(_text, ink)),
      DigitalClockFace.flip => _flip(h),
      DigitalClockFace.gradient => _gradient(h),
      DigitalClockFace.arabic => _arabic(h),
      DigitalClockFace.ring => _ring(h),
      DigitalClockFace.bars => _bars(h),
      DigitalClockFace.glass => _glass(h),
      DigitalClockFace.dots =>
        _painted(h, _DotMatrixPainter(_text, ink)),
    };
    return SizedBox(height: h, child: Center(child: body));
  }

  // The AM/PM marker, laid beside a face rather than inside it.
  Widget _meridiemChip(double h, {Color? color}) {
    final m = widget.meridiem;
    if (m == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        m,
        style: TextStyle(
          color: color ?? ink.withValues(alpha: 0.7),
          fontSize: h * 0.20,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  String get _shown => localizeDigits(_text, widget.arabicDigits);

  Widget _painted(double h, CustomPainter painter) {
    // The painted faces draw their own glyphs, so they need a width budget
    // proportional to how many characters they are showing.
    final w = h * (widget.showSeconds ? 3.5 : 2.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size(w, h * 0.72), painter: painter),
        _meridiemChip(h),
      ],
    );
  }

  // ── 1. Minimal ────────────────────────────────────────────────────────
  Widget _minimal(double h) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _shown,
            style: TextStyle(
              color: ink,
              fontSize: h * 0.58,
              fontWeight: FontWeight.w300,
              letterSpacing: h * 0.05,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _meridiemChip(h),
        ],
      );

  // ── 2. Neon ───────────────────────────────────────────────────────────
  Widget _neon(double h) {
    final style = TextStyle(
      color: ink,
      fontSize: h * 0.58,
      fontWeight: FontWeight.w700,
      letterSpacing: h * 0.03,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(color: _kTeal.withValues(alpha: 0.9), blurRadius: 18),
        Shadow(color: _kViolet.withValues(alpha: 0.7), blurRadius: 34),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(_shown, style: style),
        _meridiemChip(h, color: _kTeal),
      ],
    );
  }

  // ── 4. Flip cards ─────────────────────────────────────────────────────
  Widget _flip(double h) {
    final chars = _shown.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < chars.length; i++)
          if (chars[i] == ':')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: h * 0.04),
              child: Text(
                ':',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: h * 0.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            _FlipDigit(char: chars[i], height: h * 0.78),
        _meridiemChip(h),
      ],
    );
  }

  // ── 5. Gradient fill ──────────────────────────────────────────────────
  Widget _gradient(double h) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kTeal, Color(0xFF7DEBDA), _kGold],
            ).createShader(rect),
            child: Text(
              _shown,
              style: TextStyle(
                color: ink,
                fontSize: h * 0.60,
                fontWeight: FontWeight.w800,
                letterSpacing: h * 0.02,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _meridiemChip(h, color: _kGold),
        ],
      );

  // ── 6. Arabic calligraphy ─────────────────────────────────────────────
  Widget _arabic(double h) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            // This face is the one that always shows Arabic-Indic digits —
            // that is what makes it a distinct face rather than a font swap.
            localizeDigits(_text, true),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: const Color(0xFFF6E7B4),
              fontFamily: 'AmiriQuran',
              fontSize: h * 0.52,
              height: 1.5,
              shadows: [
                Shadow(color: _kGold.withValues(alpha: 0.45), blurRadius: 16),
              ],
            ),
          ),
          _meridiemChip(h, color: _kGold),
        ],
      );

  // ── 7. Second ring ────────────────────────────────────────────────────
  Widget _ring(double h) {
    final progress = (_now.second + _now.millisecond / 1000) / 60;
    return SizedBox(
      width: h * 1.9,
      height: h,
      child: CustomPaint(
        painter: _RingPainter(progress, ink),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: h * 0.18),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    localizeDigits(
                      _text.split(':').take(2).join(':'),
                      widget.arabicDigits,
                    ),
                    style: TextStyle(
                      color: ink,
                      fontSize: h * 0.46,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  _meridiemChip(h * 0.8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 8. Bars ───────────────────────────────────────────────────────────
  Widget _bars(double h) {
    final secs = _now.second + _now.millisecond / 1000;
    final rows = <(String, double, Color)>[
      ('H', (_now.hour % 24) / 24, _kGold),
      ('M', _now.minute / 60, _kTeal),
      ('S', secs / 60, _kViolet),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: EdgeInsets.only(bottom: h * 0.06),
                child: SizedBox(
                  width: h * 1.5,
                  height: h * 0.10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(h),
                    child: LinearProgressIndicator(
                      value: r.$2,
                      backgroundColor: ink.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(r.$3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: h * 0.18),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _shown,
              style: TextStyle(
                color: ink,
                fontSize: h * 0.40,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            _meridiemChip(h * 0.8),
          ],
        ),
      ],
    );
  }

  // ── 9. Frosted glass ──────────────────────────────────────────────────
  Widget _glass(double h) => Container(
        padding: EdgeInsets.symmetric(horizontal: h * 0.3, vertical: h * 0.12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h * 0.28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ink.withValues(alpha: 0.16),
              ink.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(color: ink.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _shown,
              style: TextStyle(
                color: ink,
                fontSize: h * 0.46,
                fontWeight: FontWeight.w600,
                letterSpacing: h * 0.03,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            _meridiemChip(h * 0.9),
          ],
        ),
      );
}

/// One digit on a card that flips when its value changes.
class _FlipDigit extends StatelessWidget {
  final String char;
  final double height;

  /// The flip card keeps its own dark plate in every theme — that IS the
  /// flip-clock look, and a white numeral on it is right on any ground — so
  /// this one face does not take the card's ink.
  static const ink = Colors.white;
  const _FlipDigit({required this.char, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * 0.62,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: height * 0.03),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height * 0.14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D2A3E), Color(0xFF0C1220)],
        ),
        border: Border.all(color: ink.withValues(alpha: 0.10)),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => AnimatedBuilder(
              animation: anim,
              builder: (_, _) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX((1 - anim.value) * math.pi / 2),
                child: Opacity(opacity: anim.value, child: child),
              ),
            ),
            child: Text(
              char,
              key: ValueKey(char),
              style: TextStyle(
                color: ink,
                fontSize: height * 0.56,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // The hairline every flip clock has across the middle of the card.
          Positioned.fill(
            child: Center(
              child: Container(
                height: 1,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ring behind the "ring" face — a full turn per minute.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color ink;
  const _RingPainter(this.progress, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ink.withValues(alpha: 0.12),
    );
    // A stadium outline can't be swept by an arc, so the travelled portion is
    // drawn as a gradient stroke whose stop follows the seconds instead.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: const [_kTeal, _kGold, Colors.transparent, Colors.transparent],
          stops: [0, progress.clamp(0.001, 1), progress.clamp(0.001, 1), 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

/// A seven-segment LCD. Segment order is the usual a-b-c-d-e-f-g.
class _SegmentPainter extends CustomPainter {
  final String text;
  final Color ink;
  const _SegmentPainter(this.text, this.ink);

  static const _map = <String, List<bool>>{
    '0': [true, true, true, true, true, true, false],
    '1': [false, true, true, false, false, false, false],
    '2': [true, true, false, true, true, false, true],
    '3': [true, true, true, true, false, false, true],
    '4': [false, true, true, false, false, true, true],
    '5': [true, false, true, true, false, true, true],
    '6': [true, false, true, true, true, true, true],
    '7': [true, true, true, false, false, false, false],
    '8': [true, true, true, true, true, true, true],
    '9': [true, true, true, true, false, true, true],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.split('');
    // Colons take a third of a digit's width.
    final units = chars.fold<double>(
      0,
      (sum, ch) => sum + (ch == ':' ? 0.42 : 1.0),
    );
    final gap = size.width * 0.02;
    final digitW =
        (size.width - gap * (chars.length - 1)) / (units == 0 ? 1 : units);
    var x = 0.0;
    for (final ch in chars) {
      if (ch == ':') {
        final w = digitW * 0.42;
        for (final fy in [0.32, 0.68]) {
          canvas.drawCircle(
            Offset(x + w / 2, size.height * fy),
            size.height * 0.045,
            Paint()..color = _kTeal,
          );
        }
        x += w + gap;
        continue;
      }
      _digit(canvas, Rect.fromLTWH(x, 0, digitW, size.height), ch);
      x += digitW + gap;
    }
  }

  void _digit(Canvas canvas, Rect r, String ch) {
    final on = _map[ch] ?? const [false, false, false, false, false, false, false];
    final t = r.height * 0.11; // segment thickness
    final w = r.width;
    final h = r.height;
    final onPaint = Paint()
      ..color = _kTeal
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    final offPaint = Paint()..color = ink.withValues(alpha: 0.07);

    void seg(Rect rect, bool lit) => canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(t / 2)),
          lit ? onPaint : offPaint,
        );

    final inset = t * 0.9;
    // a (top), b (upper-right), c (lower-right), d (bottom),
    // e (lower-left), f (upper-left), g (middle)
    seg(Rect.fromLTWH(r.left + inset, r.top, w - inset * 2, t), on[0]);
    seg(Rect.fromLTWH(r.right - t, r.top + inset, t, h / 2 - inset * 1.2),
        on[1]);
    seg(Rect.fromLTWH(r.right - t, r.top + h / 2 + inset * 0.2, t,
        h / 2 - inset * 1.2), on[2]);
    seg(Rect.fromLTWH(r.left + inset, r.bottom - t, w - inset * 2, t), on[3]);
    seg(Rect.fromLTWH(r.left, r.top + h / 2 + inset * 0.2, t,
        h / 2 - inset * 1.2), on[4]);
    seg(Rect.fromLTWH(r.left, r.top + inset, t, h / 2 - inset * 1.2), on[5]);
    seg(Rect.fromLTWH(r.left + inset, r.top + h / 2 - t / 2, w - inset * 2, t),
        on[6]);
  }

  @override
  bool shouldRepaint(covariant _SegmentPainter old) => old.text != text;
}

/// A 5x7 dot-matrix font — every lit cell is a glowing dot.
class _DotMatrixPainter extends CustomPainter {
  final String text;
  final Color ink;
  const _DotMatrixPainter(this.text, this.ink);

  /// Seven rows of five bits per glyph, most significant bit on the left.
  static const _glyphs = <String, List<int>>{
    '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
    '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
    '2': [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
    '3': [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
    '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
    '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
    '6': [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
    '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
    '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
    '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
    ':': [0x00, 0x04, 0x04, 0x00, 0x04, 0x04, 0x00],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.split('');
    final cell = math.min(
      size.height / 7,
      size.width / (chars.length * 6 - 1),
    );
    final gridW = (chars.length * 6 - 1) * cell;
    final ox = (size.width - gridW) / 2;
    final oy = (size.height - cell * 7) / 2;
    final r = cell * 0.36;

    for (var ci = 0; ci < chars.length; ci++) {
      final rows = _glyphs[chars[ci]];
      if (rows == null) continue;
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 5; x++) {
          final lit = (rows[y] >> (4 - x)) & 1 == 1;
          final centre = Offset(
            ox + (ci * 6 + x) * cell + cell / 2,
            oy + y * cell + cell / 2,
          );
          if (lit) {
            canvas.drawCircle(
              centre,
              r * 1.7,
              Paint()
                ..color = _kTeal.withValues(alpha: 0.35)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
            canvas.drawCircle(centre, r, Paint()..color = ink);
          } else {
            canvas.drawCircle(
              centre,
              r * 0.55,
              Paint()..color = ink.withValues(alpha: 0.07),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter old) => old.text != text;
}
