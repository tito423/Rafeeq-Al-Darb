import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mushaf_theme.dart';
import '../../../data/rub_el_hizb.dart';
import '../../../data/rub_plate_provider.dart';

/// The quarter / hizb plate of the printed mushaf, sliding in at the side of
/// the page for [rubPlateSecondsProvider] seconds (owner, 2026-11-13: «تدخل
/// من اليمين أو الشمال في جنب الشاشة وتخرج بانيميشن جميل»; 0 s = off).
///
/// Shape and wording are copied from the King Fahd Complex Madinah print
/// (archive.org `madina_hafs`, pages 5, 7, 9, 11, 22, read 2026-11-13):
/// a quarter mark is a dome with lobes and a pointed finial over a flat
/// base, the words stacked small «ربع» / large «الحزب» / small «1»; a hizb
/// opening is lobed at both ends with «الحزب / 2»; a juz opening reads
/// «الجزء 2 / الحزب 3». The plate stands in the page's OUTER margin: right
/// on an odd (right-hand) page, left on an even one.
///
/// It comes every time the page is put in front of the reader (opened,
/// turned to, tab shown again), and again on a tap on the «۞».

/// Knows when its page is really in front of the reader and runs the
/// plate's slide. A hidden tab reports `Visibility.of == false`
/// (IndexedStack); the PageView builds the next page before it is turned
/// to, so "in front" also means centred sideways on the screen.
mixin _RubPlateMotion<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final Animation<double> slide = CurvedAnimation(
    parent: motion,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _hide;
  ScrollPosition? _pager;
  bool _tabShown = true;
  bool _here = false;
  bool _queued = false;

  bool get pageInFront => _here;

  /// The page has just come in front of the reader.
  void arrived();

  /// The page has gone (turned away, tab hidden).
  void left() {
    _hide?.cancel();
    motion.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabShown = Visibility.of(context);
    final pager = Scrollable.maybeOf(context, axis: Axis.horizontal)?.position;
    if (pager != _pager) {
      _pager?.removeListener(queueArrival);
      _pager = pager?..addListener(queueArrival);
    }
    queueArrival();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    queueArrival();
  }

  void queueArrival() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted) return;
      final now = _tabShown && _centredSideways(context);
      if (now == _here) return;
      _here = now;
      now ? arrived() : left();
    });
  }

  /// Slides the plate in, and out again after the chosen seconds.
  void play() {
    final seconds = ref.read(rubPlateSecondsProvider);
    if (seconds <= 0) return;
    _hide?.cancel();
    motion.forward();
    _hide = Timer(Duration(seconds: seconds), () {
      if (mounted) motion.reverse();
    });
  }

  @override
  void dispose() {
    _pager?.removeListener(queueArrival);
    _hide?.cancel();
    motion.dispose();
    super.dispose();
  }
}

bool _centredSideways(BuildContext context) {
  final ro = context.findRenderObject();
  if (ro is! RenderBox || !ro.hasSize || !ro.attached) return false;
  final x = ro.localToGlobal(ro.size.center(Offset.zero)).dx;
  final w = MediaQuery.sizeOf(context).width;
  return x > w * 0.25 && x < w * 0.75;
}

/// The plate over a TEXT page: [marks] are the «۞» offsets in the paragraph
/// of [textKey]. The first mark whose line is in view gets the plate.
class RubPlateOverlay extends ConsumerStatefulWidget {
  final GlobalKey textKey;
  final List<(int, RubInfo)> marks;

  /// Paper beside the paragraph on each side: the plate stands in it.
  final double edge;

  /// The mushaf page, for the side (outer margin) the plate comes from.
  final int page;
  final MushafTheme mt;
  final TextStyle baseStyle;

  const RubPlateOverlay({
    super.key,
    required this.textKey,
    required this.marks,
    required this.edge,
    required this.page,
    required this.mt,
    required this.baseStyle,
  });

  @override
  ConsumerState<RubPlateOverlay> createState() => RubPlateOverlayState();
}

class RubPlateOverlayState extends ConsumerState<RubPlateOverlay>
    with SingleTickerProviderStateMixin, _RubPlateMotion {
  final Set<int> _seen = {};
  ScrollPosition? _scroll;
  int? _current;
  bool _checkQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_queueCheck);
      _scroll = scroll?..addListener(_queueCheck);
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_queueCheck);
    super.dispose();
  }

  @override
  void arrived() {
    _seen.clear();
    _queueCheck();
  }

  @override
  void left() {
    super.left();
    _seen.clear();
  }

  void _queueCheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _check();
    });
  }

  RenderParagraph? get _paragraph {
    final ro = widget.textKey.currentContext?.findRenderObject();
    return ro is RenderParagraph && ro.hasSize ? ro : null;
  }

  /// Plays the plate of the first not-yet-shown mark whose line is in view.
  void _check() {
    if (!pageInFront) return;
    final p = _paragraph;
    if (p == null) {
      _queueCheck();
      return;
    }
    final view = _visibleRect();
    for (final (offset, _) in widget.marks) {
      if (_seen.contains(offset)) continue;
      final line = _lineOf(p, offset);
      if (line == null) continue;
      if (view == null ||
          (line.center.dy > view.top + 8 && line.center.dy < view.bottom - 8)) {
        _seen.add(offset);
        show(offset);
        return;
      }
    }
  }

  Rect? _lineOf(RenderParagraph p, int offset) {
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    return boxes.isEmpty ? null : boxes.first.toRect();
  }

  /// Plays the plate of the mark at text [offset] (also on a tap on it).
  void show(int offset) {
    setState(() => _current = offset);
    play();
  }

  /// The part of this overlay the scrollable's viewport shows, in the
  /// overlay's own coordinates: the plate is kept inside it.
  Rect? _visibleRect() {
    final vp = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.context.findRenderObject();
    final me = context.findRenderObject();
    if (vp is! RenderBox || me is! RenderBox || !vp.hasSize || !me.hasSize) {
      return null;
    }
    return me.globalToLocal(vp.localToGlobal(Offset.zero)) & vp.size;
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(rubPlateSecondsProvider) <= 0) return const SizedBox.shrink();
    final current = _current;
    final info = current == null
        ? null
        : widget.marks.where((m) => m.$1 == current).firstOrNull?.$2;
    if (info == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        foregroundPainter: _PlatePainter(
          slide: slide,
          info: info,
          lineY: () {
            final p = _paragraph;
            return p == null ? null : _lineOf(p, current!)?.center.dy;
          },
          visible: _visibleRect,
          edge: widget.edge,
          right: widget.page.isOdd,
          mt: widget.mt,
          baseStyle: widget.baseStyle,
        ),
      ),
    );
  }
}

/// The plate over a PRINTED page (the page image carries only the in-line
/// «۞», checked on madinah_qc page 22: nothing is doubled).
class PrintedRubPlate extends ConsumerStatefulWidget {
  /// Vertical centre of each «۞» line in pixels of the page, with its quarter.
  final List<(double, RubInfo)> marks;
  final int page;
  final MushafTheme mt;
  final TextStyle baseStyle;

  const PrintedRubPlate({
    super.key,
    required this.marks,
    required this.page,
    required this.mt,
    required this.baseStyle,
  });

  @override
  ConsumerState<PrintedRubPlate> createState() => PrintedRubPlateState();
}

class PrintedRubPlateState extends ConsumerState<PrintedRubPlate>
    with SingleTickerProviderStateMixin, _RubPlateMotion {
  @override
  void arrived() {
    if (widget.marks.isNotEmpty) play();
  }

  /// Plays the plate again (a tap on the «۞»).
  void show() => play();

  @override
  Widget build(BuildContext context) {
    if (widget.marks.isEmpty || ref.watch(rubPlateSecondsProvider) <= 0) {
      return const SizedBox.shrink();
    }
    // One «۞» per printed page in practice; the first is the one shown.
    final (y, info) = widget.marks.first;
    return IgnorePointer(
      child: CustomPaint(
        painter: _PlatePainter(
          slide: slide,
          info: info,
          lineY: () => y,
          visible: () => null,
          edge: 0,
          right: widget.page.isOdd,
          mt: widget.mt,
          baseStyle: widget.baseStyle,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  final Animation<double> slide;
  final RubInfo info;
  final double? Function() lineY;
  final Rect? Function() visible;
  final double edge;
  final bool right;
  final MushafTheme mt;
  final TextStyle baseStyle;

  _PlatePainter({
    required this.slide,
    required this.info,
    required this.lineY,
    required this.visible,
    required this.edge,
    required this.right,
    required this.mt,
    required this.baseStyle,
  }) : super(repaint: slide);

  @override
  void paint(Canvas canvas, Size size) {
    final t = slide.value;
    if (t <= 0) return;
    final y0 = lineY();
    if (y0 == null) return;
    final screenW = size.width + edge * 2;
    final w = (screenW * 0.15).clamp(48.0, 72.0);
    final plate = _PrintedPlate(info, w, mt, baseStyle);
    var area = Offset.zero & size;
    final within = visible();
    if (within != null && within.overlaps(area)) area = area.intersect(within);
    final half = plate.height / 2;
    final y = area.height <= plate.height
        ? area.center.dy
        : y0.clamp(area.top + half, area.bottom - half);
    // In from the page's outer edge, a little past its rest, then settles.
    const inset = 4.0;
    final rest = right ? size.width + edge - inset - w / 2 : -edge + inset + w / 2;
    final away = (1 - t) * (w + inset + 12);
    final x = right ? rest + away : rest - away;
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, t.clamp(0.0, 1.0)),
    );
    plate.paint(canvas, Offset(x, y));
    canvas.restore();
    plate.dispose();
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.info != info ||
      old.edge != edge ||
      old.right != right ||
      old.mt != mt;
}

/// The plate as printed, [width] wide, laid out once per paint.
class _PrintedPlate {
  final RubInfo info;
  final double width;
  final MushafTheme mt;
  final List<TextPainter> _lines = [];
  late final double _textHeight;
  late final double _dome = width * 0.62;
  late final bool _bothEnds = info.part == 0;

  _PrintedPlate(this.info, this.width, this.mt, TextStyle baseStyle) {
    final big = width * 0.3;
    final lines = info.marginLines;
    final digits = RegExp(r'^[\d٠-٩۰-۹]+$');
    for (var i = 0; i < lines.length; i++) {
      final small = digits.hasMatch(lines[i]) || (lines.length == 3 && i == 0);
      final size = info.opensJuz ? big * 0.72 : (small ? big * 0.56 : big);
      _lines.add(
        TextPainter(
          text: TextSpan(
            text: lines[i],
            style: baseStyle.copyWith(
              fontFamily: 'AmiriQuran',
              letterSpacing: 0,
              fontSize: size,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: mt.ink,
            ),
          ),
          textDirection: TextDirection.rtl,
          maxLines: 1,
        )..layout(),
      );
    }
    _textHeight = _lines.fold(0.0, (s, tp) => s + tp.height * _fit(tp));
  }

  double _fit(TextPainter tp) {
    final inner = width * 0.8;
    return tp.width > inner ? inner / tp.width : 1;
  }

  double get _body => _textHeight + width * 0.12;
  double get height => _body + _dome + (_bothEnds ? _dome : 0);

  /// The lobed dome over [top], from x = -w to w, its finial at top - [d].
  /// [dir] -1 draws it upward, 1 downward (the foot of a hizb plate).
  static void _dome1(Path p, double w, double top, double d, double dir) {
    // Left shoulder up to the finial in two lobes and a pointed tip, then
    // the mirror back down: the lobes bulge outward like the printed arch.
    final pts = <Offset>[
      Offset(-w, top),
      Offset(-w * 0.72, top + dir * d * 0.36),
      Offset(-w * 0.36, top + dir * d * 0.66),
    ];
    final tip = Offset(0, top + dir * d);
    final lobe = Radius.circular(w * 0.27);
    final cw = dir < 0;
    p.lineTo(pts[0].dx, pts[0].dy);
    p.arcToPoint(pts[1], radius: lobe, clockwise: cw);
    p.arcToPoint(pts[2], radius: lobe, clockwise: cw);
    p.quadraticBezierTo(-w * 0.06, top + dir * d * 0.72, tip.dx, tip.dy);
    p.quadraticBezierTo(w * 0.06, top + dir * d * 0.72, w * 0.36, pts[2].dy);
    p.arcToPoint(Offset(w * 0.72, pts[1].dy), radius: lobe, clockwise: cw);
    p.arcToPoint(Offset(w, top), radius: lobe, clockwise: cw);
  }

  Path _outline() {
    final w = width / 2;
    final top = -height / 2 + _dome;
    final bottom = top + _body;
    final p = Path()..moveTo(-w, bottom);
    p.lineTo(-w, top);
    _dome1(p, w, top, _dome, -1);
    p.lineTo(w, bottom);
    if (_bothEnds) {
      // Back along the foot: the same dome, pointing down, right to left.
      final foot = Path()..moveTo(-w, bottom);
      _dome1(foot, w, bottom, _dome, 1);
      p.extendWithPath(_reversed(foot, w, bottom), Offset.zero);
    } else {
      p.lineTo(-w, bottom);
    }
    return p..close();
  }

  /// The foot dome drawn right-to-left: mirror the left-to-right one.
  static Path _reversed(Path foot, double w, double bottom) =>
      foot.transform(Matrix4.diagonal3Values(-1, 1, 1).storage);

  void paint(Canvas canvas, Offset centre) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    final outline = _outline();
    canvas.drawShadow(outline, const Color(0xFF000000), 3, false);
    canvas.drawPath(
      outline,
      Paint()
        ..color = Color.alphaBlend(mt.gold.withValues(alpha: 0.18), mt.paper),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = mt.gold,
    );
    var y = -height / 2 + _dome + (_body - _textHeight) / 2;
    for (final tp in _lines) {
      final s = _fit(tp);
      canvas.save();
      canvas.translate(-tp.width * s / 2, y);
      canvas.scale(s);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      y += tp.height * s;
    }
    canvas.restore();
  }

  void dispose() {
    for (final tp in _lines) {
      tp.dispose();
    }
  }
}
