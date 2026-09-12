import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/adhan_background.dart';
import 'adhan_background_painter.dart';

/// The animated Islamic scene behind the adhan — painted, not filmed.
///
/// «الدمج الحالي سيئ جدًا والفيديوهات نفسها جودتها ضعيفة جدًا ورديئة
/// والفيديوهات بتعيد نفسها بشكل سيء … حتى لو هتاخد أنت الصوت وتكتب النص ويبقى
/// أنيميتد وفيجوالي روعة، ويبقى أذان بخلفية إسلامية متحركة وجميلة، حاجة كده
/// كرييتيف من عندك».
///
/// WHY PAINTED.
/// Every complaint in that sentence is a property of *using a video*. A clip
/// is whatever resolution it was encoded at — the ten in the catalogue are
/// 640×360 and land on a 1080×2400 phone, i.e. scaled 6.7× (trap #37). A clip
/// is a fixed length, so a four-minute adhan over a twenty-second clip loops
/// twelve times and every loop point is visible. A clip is somebody else's
/// footage, so it carries somebody else's licence. And a clip is bytes the
/// reader has to download before the adhan can look like anything.
///
/// A painted scene has none of those. It is resolution-independent, it never
/// repeats because nothing is on a loop the eye can latch onto, it is the
/// app's own work, and it weighs nothing.
///
/// WHAT IS ON SCREEN.
///   * A sky whose colours are **this prayer's** — the pre-dawn blue of fajr,
///     the high pale gold of dhuhr, the amber of asr, the rose of maghrib,
///     the deep indigo of isha. The five look like five different times of
///     day, because they are.
///   * Stars that only come out for the night prayers, and a moon that is a
///     crescent for those and a sun disc for the two daytime ones.
///   * A mosque on the horizon — dome, two minarets, finials — in silhouette
///     with a thin rim of light down the edge facing the sun.
///   * **Rings of sound leaving the minaret on every phrase.** This is the
///     part that ties the picture to the audio: [phraseIndex] comes from the
///     same measured onsets the subtitles use (`adhan_phrase_timings.json`,
///     built by silence detection on the real recording), so the ring leaves
///     the minaret at the instant the muezzin begins the line. Nothing here
///     guesses where the audio is.
class AdhanScene extends StatefulWidget {
  /// `fajr` / `dhuhr` / `asr` / `maghrib` / `isha`. Anything else is treated
  /// as isha, which is the safest look for text laid over it.
  final String prayerKey;

  /// Which phrase of the adhan is sounding, counting from 0. Every change
  /// sends a ring out from the minaret; -1 means nothing is sounding yet.
  final int phraseIndex;

  /// False stops every animation — for the reduce-motion setting, and so the
  /// scene costs nothing while the screen is not really showing.
  final bool animate;

  /// Which of the ten painted grounds to stand the mosque on. The mosque and
  /// the phrase-synced rings are the same on all ten: the background is what
  /// the reader chose, the synchronisation is what the screen is FOR.
  final AdhanBackground background;

  const AdhanScene({
    super.key,
    required this.prayerKey,
    required this.phraseIndex,
    this.animate = true,
    this.background = AdhanBackground.horizon,
  });

  @override
  State<AdhanScene> createState() => _AdhanSceneState();
}

class _AdhanSceneState extends State<AdhanScene>
    with SingleTickerProviderStateMixin {
  /// One controller for everything. It counts minutes rather than looping a
  /// short animation, so nothing in the scene has a period short enough to
  /// read as a repeat — which is the specific thing that was wrong with the
  /// clips.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 30),
  );

  /// Seconds (on `_clock`'s own timeline) at which each live ring left the
  /// minaret. A ring lives [_ringLife] seconds and is then dropped, so this
  /// never grows.
  final List<double> _rings = [];
  static const _ringLife = 4.0;

  int _lastPhrase = -1;

  double get _now => (_clock.lastElapsedDuration ?? Duration.zero)
      .inMilliseconds /
      1000.0;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _clock.repeat();
  }

  @override
  void didUpdateWidget(covariant AdhanScene old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!widget.animate && _clock.isAnimating) {
      _clock.stop();
    }
    if (widget.phraseIndex != _lastPhrase) {
      _lastPhrase = widget.phraseIndex;
      if (widget.phraseIndex >= 0) {
        _rings
          ..removeWhere((t) => _now - t > _ringLife)
          ..add(_now);
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AdhanPalette.forPrayer(widget.prayerKey);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _AdhanScenePainter(
            palette: palette,
            background: widget.background,
            seconds: widget.animate ? _now : 12.0,
            rings: List<double>.unmodifiable(_rings),
            ringLife: _ringLife,
          ),
        ),
      ),
    );
  }
}

/// The five skies. Kept as data rather than branches in the painter so the
/// difference between two prayers is one line to read and one line to change.
class _AdhanPalette {
  /// Top of the sky, horizon, and the light the scene is lit by.
  final Color zenith;
  final Color horizon;
  final Color light;

  /// How high the sun/moon sits, 0 (on the horizon) .. 1 (overhead), and how
  /// far across, 0 (left) .. 1 (right).
  final double bodyHeight;
  final double bodyAcross;

  /// A crescent for the night prayers, a disc for the two daytime ones.
  final bool crescent;

  /// Stars are only out when it is dark enough for them.
  final double starAlpha;

  const _AdhanPalette({
    required this.zenith,
    required this.horizon,
    required this.light,
    required this.bodyHeight,
    required this.bodyAcross,
    required this.crescent,
    required this.starAlpha,
  });

  static _AdhanPalette forPrayer(String key) => switch (key) {
        // Before sunrise: still night overhead, a cold blue at the horizon
        // with the first warmth under it. The crescent is low and setting.
        'fajr' => const _AdhanPalette(
            zenith: Color(0xFF07142B),
            horizon: Color(0xFF2A4A6E),
            light: Color(0xFFE8B25F),
            bodyHeight: 0.30,
            bodyAcross: 0.80,
            crescent: true,
            starAlpha: 0.55,
          ),
        // Midday, but this is a dark screen with white text on it, so "high
        // sun" is a pale gold high in a deep teal sky rather than a blue-sky
        // photograph that the text could not sit on.
        'dhuhr' => const _AdhanPalette(
            zenith: Color(0xFF06243A),
            horizon: Color(0xFF2F6E7E),
            light: Color(0xFFFFD98A),
            bodyHeight: 0.60,
            bodyAcross: 0.74,
            crescent: false,
            starAlpha: 0.0,
          ),
        // Afternoon: the light has gone amber and the sun has come down.
        'asr' => const _AdhanPalette(
            zenith: Color(0xFF0A2438),
            horizon: Color(0xFF8A5A34),
            light: Color(0xFFF0A95C),
            bodyHeight: 0.44,
            bodyAcross: 0.24,
            crescent: false,
            starAlpha: 0.0,
          ),
        // Sunset: rose on the horizon, the first stars overhead.
        'maghrib' => const _AdhanPalette(
            zenith: Color(0xFF10142F),
            horizon: Color(0xFF9B4A46),
            light: Color(0xFFFF9D63),
            bodyHeight: 0.18,
            bodyAcross: 0.18,
            crescent: true,
            starAlpha: 0.35,
          ),
        // Night.
        _ => const _AdhanPalette(
            zenith: Color(0xFF040A1E),
            horizon: Color(0xFF16305A),
            light: Color(0xFFCBD8F5),
            bodyHeight: 0.58,
            bodyAcross: 0.78,
            crescent: true,
            starAlpha: 0.85,
          ),
      };
}

class _AdhanScenePainter extends CustomPainter {
  final _AdhanPalette palette;
  final AdhanBackground background;

  /// Seconds since the scene started. Everything that moves is a slow
  /// function of this, not of a 0..1 loop.
  final double seconds;

  /// Birth times of the live sound rings, and how long one lives.
  final List<double> rings;
  final double ringLife;

  const _AdhanScenePainter({
    required this.palette,
    required this.background,
    required this.seconds,
    required this.rings,
    required this.ringLife,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final rect = Offset.zero & size;
    // The ground line. Everything above it is sky, the mosque stands on it.
    // Pushed down from 0.74 after seeing it on emulator-5554: the phrase
    // «أشهد أن محمدًا رسول الله» is set across the middle of the screen and
    // the minarets reached straight through it. The mosque now stands
    // below the text band, which is also where a mosque on a horizon
    // belongs.
    final horizonY = h * 0.80;

    // The chosen ground, which always paints its own sky first so the text
    // laid over it sits on a known gradient. `horizon` is the original look:
    // the same graded sky with the same stars.
    paintAdhanBackground(
      canvas,
      rect,
      background,
      palette.zenith,
      palette.horizon,
      palette.light,
      seconds,
    );
    if (background == AdhanBackground.horizon && palette.starAlpha > 0) {
      _stars(canvas, size, horizonY);
    }
    final body = _celestialBody(canvas, size, horizonY);
    _hills(canvas, size, horizonY);
    final minaretTop = _mosque(canvas, size, horizonY, body);
    _soundRings(canvas, size, minaretTop);
    _ground(canvas, size, horizonY);
  }

  void _stars(Canvas canvas, Size size, double horizonY) {
    // A fixed sky: the same stars every time, because a sky that reshuffles
    // itself is a sky nobody believes.
    final rnd = math.Random(11);
    for (var i = 0; i < 90; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * horizonY * 0.9;
      final base = 0.25 + rnd.nextDouble() * 0.75;
      // Each star breathes on its own period, so no two blink together.
      final period = 3.0 + rnd.nextDouble() * 9.0;
      final twinkle = 0.55 + 0.45 * math.sin(seconds / period * math.pi * 2 + i);
      canvas.drawCircle(
        Offset(x, y),
        0.7 + rnd.nextDouble() * 1.3,
        Paint()
          ..color = Colors.white
              .withValues(alpha: palette.starAlpha * base * twinkle),
      );
    }
  }

  /// Draws the moon or sun and returns its centre, so the mosque can be lit
  /// from the same side the light is actually on.
  Offset _celestialBody(Canvas canvas, Size size, double horizonY) {
    final c = Offset(
      size.width * palette.bodyAcross,
      horizonY - horizonY * palette.bodyHeight,
    );
    final r = size.shortestSide * 0.085;

    // The halo.
    canvas.drawCircle(
      c,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.light.withValues(alpha: 0.22),
            palette.light.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
    );

    final disc = Paint()..color = palette.light.withValues(alpha: 0.95);
    if (!palette.crescent) {
      canvas.drawCircle(c, r, disc);
      return c;
    }
    // A crescent is the disc with a second disc cut out of it — saveLayer +
    // clear, which is the only way to subtract on a canvas.
    canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 1.2), Paint());
    canvas.drawCircle(c, r, disc);
    canvas.drawCircle(
      c.translate(r * 0.46, -r * 0.22),
      r * 0.92,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    return c;
  }

  /// Two soft ridges behind the mosque, so the horizon has depth.
  void _hills(Canvas canvas, Size size, double horizonY) {
    for (var layer = 0; layer < 2; layer++) {
      final lift = size.height * (0.045 - layer * 0.018);
      final path = Path()..moveTo(0, horizonY);
      final steps = 12;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y = horizonY -
            lift *
                (0.5 +
                    0.5 *
                        math.sin(i * 0.9 + layer * 2.1 + seconds * 0.02));
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, horizonY)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(palette.horizon, Colors.black,
                  0.35 + layer * 0.22)!
              .withValues(alpha: 0.85),
      );
    }
  }

  /// The mosque, in silhouette. Returns the finial of the minaret the sound
  /// leaves from.
  Offset _mosque(Canvas canvas, Size size, double horizonY, Offset light) {
    final w = size.width;
    final unit = w * 0.078;
    final cx = w * 0.5;
    final baseTop = horizonY - unit * 1.5;

    final body = Path()
      // The prayer hall.
      ..addRect(Rect.fromLTRB(cx - unit * 2.6, baseTop, cx + unit * 2.6, horizonY))
      // The dome: a half-ellipse with the little neck under it.
      ..addRect(Rect.fromLTRB(cx - unit * 1.25, baseTop - unit * 0.22,
          cx + unit * 1.25, baseTop))
      ..addArc(
        Rect.fromLTRB(cx - unit * 1.25, baseTop - unit * 2.1, cx + unit * 1.25,
            baseTop + unit * 0.25),
        math.pi,
        math.pi,
      );

    // The two minarets.
    final minaretTops = <Offset>[];
    for (final side in [-1.0, 1.0]) {
      final mx = cx + side * unit * 3.4;
      final top = horizonY - unit * 4.0;
      body
        ..addRect(Rect.fromLTRB(mx - unit * 0.33, top, mx + unit * 0.33, horizonY))
        // The gallery the muezzin stands on.
        ..addRect(Rect.fromLTRB(
            mx - unit * 0.52, top + unit * 0.25, mx + unit * 0.52, top + unit * 0.5))
        ..addArc(
          Rect.fromLTRB(mx - unit * 0.4, top - unit * 0.75, mx + unit * 0.4,
              top + unit * 0.15),
          math.pi,
          math.pi,
        );
      minaretTops.add(Offset(mx, top - unit * 0.55));
    }

    canvas.drawPath(body, Paint()..color = const Color(0xFF03070F));

    // A rim of light down the edge the sun or moon is actually on — one
    // stroke, clipped to the silhouette's lit half.
    final litFromLeft = light.dx < cx;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      litFromLeft ? 0 : cx,
      0,
      litFromLeft ? cx : w,
      horizonY + 1,
    ));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = palette.light.withValues(alpha: 0.55),
    );
    canvas.restore();

    // The finial on each minaret, and the crescent on the dome.
    for (final t in minaretTops) {
      canvas.drawCircle(t, unit * 0.1, Paint()..color = palette.light);
    }
    return litFromLeft ? minaretTops.last : minaretTops.first;
  }

  /// The adhan, made visible: one ring leaves the minaret as each phrase
  /// begins and opens out across the sky.
  void _soundRings(Canvas canvas, Size size, Offset from) {
    for (final birth in rings) {
      final age = seconds - birth;
      if (age < 0 || age > ringLife) continue;
      final k = age / ringLife;
      // Fast at first and slowing — the shape a real wavefront has, and the
      // shape that reads as "sound" rather than "a circle growing".
      final eased = 1 - math.pow(1 - k, 2.4).toDouble();
      final r = size.shortestSide * (0.06 + 1.05 * eased);
      canvas.drawCircle(
        from,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - k) + 0.6
          ..color = palette.light.withValues(alpha: 0.45 * (1 - k)),
      );
    }
  }

  void _ground(Canvas canvas, Size size, double horizonY) {
    canvas.drawRect(
      Rect.fromLTRB(0, horizonY, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF03070F), const Color(0xFF01040A)],
        ).createShader(
          Rect.fromLTRB(0, horizonY, size.width, size.height),
        ),
    );
    // The light's reflection on the ground, directly under it.
    canvas.drawRect(
      Rect.fromLTRB(0, horizonY, size.width, horizonY + size.height * 0.08),
      Paint()
        ..shader = RadialGradient(
          center: Alignment(palette.bodyAcross * 2 - 1, -1.0),
          radius: 1.0,
          colors: [
            palette.light.withValues(alpha: 0.12),
            palette.light.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromLTRB(0, horizonY, size.width, horizonY + size.height * 0.08),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _AdhanScenePainter old) =>
      old.seconds != seconds ||
      old.palette != palette ||
      old.rings.length != rings.length;
}
