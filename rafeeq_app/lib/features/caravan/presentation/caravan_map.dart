/// The journey map of «قافلة الدرب»: eight stations on a winding golden
/// road, in the order of Islamic history. A station shows its stars; the
/// next one to play glows; one not reached yet is locked.
///
/// The mode (children / adults) is chosen here once, not per leg.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../core/utils/digits.dart';
import '../data/caravan_progress.dart';
import '../data/caravan_world.dart';

class CaravanMap extends StatefulWidget {
  final CaravanProgress? progress;
  final CaravanMode mode;
  final ValueChanged<CaravanMode> onMode;
  final ValueChanged<CaravanLeg> onPlay;
  const CaravanMap({
    super.key,
    required this.progress,
    required this.mode,
    required this.onMode,
    required this.onPlay,
  });

  @override
  State<CaravanMap> createState() => _CaravanMapState();
}

class _CaravanMapState extends State<CaravanMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  static const _rowH = 132.0;

  /// Twenty stations do not fit one screen: the map opens scrolled to the
  /// leg the reader has reached.
  final _scroll = ScrollController();
  int? _scrolledTo;

  void _reveal(int index) {
    if (_scrolledTo == index) return;
    _scrolledTo = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = (index * _rowH - 120).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Station centre as fractions: x zigzags, y steps down the road.
  Offset _at(int i, double width) =>
      Offset(width * (i.isEven ? 0.3 : 0.7), 90 + i * _rowH);

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    const legs = CaravanLeg.all;
    final next = p == null
        ? CaravanLeg.first
        : legs.firstWhere(
            (l) => p.isOpen(l) && p.starsOf(l) == 0,
            orElse: () => legs.last,
          );
    final lang = context.locale.languageCode;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15183F), Color(0xFF3B2C5E), Color(0xFFB0703F)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(context, lang),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) {
                  // Never wider than a phone column: on a TV or a tablet
                  // held flat the road stays a road, centred.
                  final w = math.min(box.maxWidth, 520.0);
                  final h = 40 + legs.length * _rowH;
                  if (p != null) _reveal(next.number - 1);
                  return SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: SizedBox(
                        width: w,
                        height: h,
                        // The road runs top to bottom in every language.
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _RoadPainter([
                                    for (var i = 0; i < legs.length; i++)
                                      _at(i, w),
                                  ], done: p?.totalStars ?? 0),
                                ),
                              ),
                              for (var i = 0; i < legs.length; i++)
                                _station(
                                  legs[i],
                                  _at(i, w),
                                  p,
                                  legs[i] == next,
                                  lang,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String lang) {
    final stars = widget.progress?.totalStars ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const BackButtonIcon(),
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'caravan.title'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFE9B0),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFD34D),
                      size: 20,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      localizeDigits(
                        '$stars/${CaravanLeg.all.length * 3}',
                        lang,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            'caravan.map_hint'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<CaravanMode>(
            style: SegmentedButton.styleFrom(
              foregroundColor: Colors.white,
              selectedForegroundColor: const Color(0xFF3B2A12),
              selectedBackgroundColor: const Color(0xFFE8C766),
              side: const BorderSide(color: Color(0x88E8C766)),
            ),
            segments: [
              ButtonSegment(
                value: CaravanMode.kids,
                icon: const Icon(Icons.child_care_outlined),
                label: Text('caravan.kids'.tr()),
              ),
              ButtonSegment(
                value: CaravanMode.adults,
                icon: const Icon(Icons.local_fire_department_outlined),
                label: Text('caravan.adults'.tr()),
              ),
            ],
            selected: {widget.mode},
            onSelectionChanged: (s) => widget.onMode(s.first),
          ),
          const SizedBox(height: 4),
          Text(
            (widget.mode == CaravanMode.kids
                    ? 'caravan.kids_hint'
                    : 'caravan.adults_hint')
                .tr(),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _station(
    CaravanLeg leg,
    Offset c,
    CaravanProgress? p,
    bool isNext,
    String lang,
  ) {
    final open = p?.isOpen(leg) ?? leg.number == 1;
    final stars = p?.starsOf(leg) ?? 0;
    const size = 66.0;
    return Positioned(
      left: c.dx - 70,
      top: c.dy - size / 2,
      width: 140,
      child: GestureDetector(
        onTap: open ? () => widget.onPlay(leg) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: open
                        ? const [Color(0xFFFFF2B8), Color(0xFFB8892A)]
                        : const [Color(0xFF7D7A8C), Color(0xFF45425A)],
                  ),
                  border: Border.all(color: const Color(0xFFFFE9B0), width: 2),
                  boxShadow: [
                    if (isNext)
                      BoxShadow(
                        color: const Color(
                          0xFFFFD34D,
                        ).withValues(alpha: 0.35 + 0.4 * _pulse.value),
                        blurRadius: 14 + 14 * _pulse.value,
                        spreadRadius: 2 + 4 * _pulse.value,
                      ),
                  ],
                ),
                child: child,
              ),
              child: Center(
                child: open
                    ? Text(
                        localizeDigits('${leg.number}', lang),
                        style: const TextStyle(
                          color: Color(0xFF3B2A12),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : const Icon(Icons.lock_rounded, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              leg.toKey.tr(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: open ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var s = 1; s <= 3; s++)
                  Icon(
                    s <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: s <= stars
                        ? const Color(0xFFFFD34D)
                        : Colors.white38,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The road between stations: a soft wide band, a dashed centre line, and
/// the stretch already travelled in gold.
class _RoadPainter extends CustomPainter {
  final List<Offset> points;
  final int done;
  _RoadPainter(this.points, {required this.done});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55E8C9A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    final dash = Paint()
      ..color = const Color(0xFFE8C766)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 16) {
        canvas.drawPath(m.extractPath(d, d + 8), dash);
      }
    }
    // A few palms and dunes along the way, for the eye.
    final rnd = math.Random(4);
    final palm = Paint()..color = const Color(0x553F7A3A);
    for (var i = 0; i < 10; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = 60 + rnd.nextDouble() * (size.height - 80);
      canvas.drawCircle(Offset(x, y), 3 + rnd.nextDouble() * 3, palm);
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.done != done;
}
