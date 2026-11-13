import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../../../data/mushaf_theme.dart';
import '../../../data/rub_el_hizb.dart';

/// The quarter plate of the printed mushaf, shown for [rubPlateHold] as the
/// printed plate itself (pointed head and foot, words stacked), centred on
/// the page level with the line that carries «۞». The strip laid between the
/// lines or in the margin is gone (owner, 2026-11-13: it looked bad there).
///
/// It fades in when the «۞» line first scrolls into view, fades out after
/// [rubPlateHold], and a tap on the «۞» ([RubPlateOverlayState.show]) shows it
/// again. The shape and the wording are read off the Madinah printing of 1428
/// AH (pages 5, 7, 9 and 22): a plate with a pointed head and foot, a pale
/// ground and a dark outline, the words stacked - «ربع / الحزب / ١».
const Duration rubPlateHold = Duration(seconds: 3);

class RubPlateOverlay extends StatefulWidget {
  /// The paragraph the marks are in.
  final GlobalKey textKey;

  /// Text offset of each «۞» in that paragraph, and the quarter it opens.
  final List<(int, RubInfo)> marks;

  /// The page's side padding: how much paper there is left of the text.
  final double edge;
  final MushafTheme mt;
  final TextStyle baseStyle;

  const RubPlateOverlay({
    super.key,
    required this.textKey,
    required this.marks,
    required this.edge,
    required this.mt,
    required this.baseStyle,
  });

  @override
  State<RubPlateOverlay> createState() => RubPlateOverlayState();
}

class RubPlateOverlayState extends State<RubPlateOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  final Set<int> _seen = {};
  Timer? _hide;
  ScrollPosition? _pos;
  bool _onScreen = true;
  int? _current;
  bool _checkQueued = false;
  Timer? _retry;

  RenderParagraph? get _paragraph {
    final ro = widget.textKey.currentContext?.findRenderObject();
    return ro is RenderParagraph && ro.hasSize ? ro : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_queueCheck);
      _pos = pos?..addListener(_queueCheck);
    }
    // A hidden tab (IndexedStack) reports Visibility.of == false: the plate
    // waits for the page to be really on screen, and shows again on every
    // return.
    _onScreen = Visibility.of(context);
    _visibilityChanged();
  }

  void _visibilityChanged() {
    if (_onScreen) {
      _queueCheck();
    } else {
      _seen.clear();
      _hide?.cancel();
      _fade.value = 0;
    }
  }

  @override
  void didUpdateWidget(RubPlateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _queueCheck();
  }

  @override
  void dispose() {
    _pos?.removeListener(_queueCheck);
    _retry?.cancel();
    _hide?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _queueCheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _check();
    });
  }

  /// Shows the plate of the first not-yet-shown mark whose line is inside
  /// the scrollable's viewport.
  void _check() {
    if (!_onScreen) return;
    if (!_onScreenSideways(context)) {
      _retry?.cancel();
      _retry = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _queueCheck();
      });
      return;
    }
    final p = _paragraph;
    if (p == null) {
      _queueCheck();
      return;
    }
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    Rect? view;
    if (viewport is RenderBox && viewport.hasSize) {
      view = viewport.localToGlobal(Offset.zero) & viewport.size;
    }
    for (final (offset, _) in widget.marks) {
      if (_seen.contains(offset)) continue;
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      );
      if (boxes.isEmpty) continue;
      final line = boxes.first.toRect();
      final y = p.localToGlobal(line.center).dy;
      if (view == null || (y > view.top + 8 && y < view.bottom - 8)) {
        _seen.add(offset);
        show(offset);
        return;
      }
    }
  }

  /// Fades the plate of the mark at text [offset] in, and out again after
  /// [rubPlateHold].
  void show(int offset) {
    _hide?.cancel();
    setState(() => _current = offset);
    _fade.forward();
    _hide = Timer(rubPlateHold, () {
      if (mounted) _fade.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final info = current == null
        ? null
        : widget.marks.where((m) => m.$1 == current).firstOrNull?.$2;
    if (info == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        foregroundPainter: _RubPlatePainter(
          textKey: widget.textKey,
          offset: current!,
          info: info,
          edge: widget.edge,
          mt: widget.mt,
          baseStyle: widget.baseStyle,
          fade: _fade,
          visible: _visibleRect,
        ),
      ),
    );
  }

  /// The part of this overlay the scrollable's viewport shows, in the
  /// overlay's own coordinates: the plate is kept inside it.
  Rect? _visibleRect() {
    final vp = Scrollable.maybeOf(context)?.context.findRenderObject();
    final me = context.findRenderObject();
    if (vp is! RenderBox || me is! RenderBox || !vp.hasSize || !me.hasSize) {
      return null;
    }
    return me.globalToLocal(vp.localToGlobal(Offset.zero)) & vp.size;
  }
}

class _RubPlatePainter extends CustomPainter {
  final GlobalKey textKey;
  final int offset;
  final RubInfo info;
  final double edge;
  final MushafTheme mt;
  final TextStyle baseStyle;
  final Animation<double> fade;
  final Rect? Function() visible;

  _RubPlatePainter({
    required this.textKey,
    required this.offset,
    required this.info,
    required this.edge,
    required this.mt,
    required this.baseStyle,
    required this.fade,
    required this.visible,
  }) : super(repaint: fade);

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = Curves.easeOut.transform(fade.value);
    if (alpha <= 0) return;
    final ro = textKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    final boxes = ro.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    if (boxes.isEmpty) return;
    final line = boxes.first.toRect();
    paintFloatingRubPlate(
      canvas,
      size: size,
      lineY: line.center.dy,
      within: visible(),
      alpha: alpha,
      lines: info.marginLines,
      mt: mt,
      baseStyle: baseStyle,
    );
  }

  @override
  bool shouldRepaint(_RubPlatePainter old) =>
      old.offset != offset ||
      old.info != info ||
      old.edge != edge ||
      old.mt != mt ||
      old.textKey != textKey;
}

/// The plate itself, [width] wide and as tall as its lines need.
void paintRubPlate(
  Canvas canvas, {
  required Offset centre,
  required double width,
  required List<String> lines,
  required MushafTheme mt,
  required TextStyle baseStyle,
  bool shadow = false,
}) {
  final inner = width - 8;
  final painters = <TextPainter>[];
  for (var i = 0; i < lines.length; i++) {
    final last = i == lines.length - 1;
    // The hizb's name is the large line, as printed; the fraction above it
    // and the number under it are smaller.
    final big = lines.length == 2 || i == lines.length - 2;
    final tp = TextPainter(
      text: TextSpan(
        text: lines[i],
        style: baseStyle.copyWith(
          fontFamily: 'AmiriQuran',
          letterSpacing: 0,
          fontSize: big ? 13.5 : (last ? 12 : 10.5),
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: mt.ink,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    painters.add(tp);
  }
  double scaleOf(TextPainter tp) => tp.width > inner ? inner / tp.width : 1;
  final textHeight = painters.fold<double>(
    0,
    (sum, tp) => sum + tp.height * scaleOf(tp),
  );
  final tip = width * 0.34;
  final half = Size(width / 2, textHeight / 2 + tip + 6);

  final w = half.width;
  final h = half.height;
  final r = width * 0.2;
  final plate = Path()
    ..moveTo(0, -h)
    ..quadraticBezierTo(w * 0.25, -h + tip * 0.9, w * 0.7, -h + tip)
    ..quadraticBezierTo(w, -h + tip, w, -h + tip + r)
    ..lineTo(w, h - tip - r)
    ..quadraticBezierTo(w, h - tip, w * 0.7, h - tip)
    ..quadraticBezierTo(w * 0.25, h - tip * 0.9, 0, h)
    ..quadraticBezierTo(-w * 0.25, h - tip * 0.9, -w * 0.7, h - tip)
    ..quadraticBezierTo(-w, h - tip, -w, h - tip - r)
    ..lineTo(-w, -h + tip + r)
    ..quadraticBezierTo(-w, -h + tip, -w * 0.7, -h + tip)
    ..quadraticBezierTo(-w * 0.25, -h + tip * 0.9, 0, -h)
    ..close();

  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  if (shadow) {
    canvas.drawShadow(plate, const Color(0xFF000000), 3, false);
  }
  canvas.drawPath(
    plate,
    Paint()
      ..color = Color.alphaBlend(mt.gold.withValues(alpha: 0.22), mt.paper),
  );
  canvas.drawPath(
    plate,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = mt.gold,
  );
  var y = -textHeight / 2;
  for (final tp in painters) {
    final s = scaleOf(tp);
    canvas.save();
    canvas.translate(-tp.width * s / 2, y);
    canvas.scale(s);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    y += tp.height * s;
    tp.dispose();
  }
  canvas.restore();
}

/// The same plate on a PRINTED page (raster or vector edition). The printed
/// page itself carries only the in-line «۞» ornament (checked on madinah_qc
/// page 22, 2026-11-13: no margin plate in the image), so nothing is
/// duplicated. It fades in when the page appears, out after [rubPlateHold],
/// and [PrintedRubPlateState.show] brings it back on a tap on the «۞».
class PrintedRubPlate extends StatefulWidget {
  /// Vertical centre of each «۞» line in pixels of the page, with its quarter.
  final List<(double, RubInfo)> marks;
  final double pageWidth;
  final MushafTheme mt;
  final TextStyle baseStyle;

  const PrintedRubPlate({
    super.key,
    required this.marks,
    required this.pageWidth,
    required this.mt,
    required this.baseStyle,
  });

  @override
  State<PrintedRubPlate> createState() => PrintedRubPlateState();
}

class PrintedRubPlateState extends State<PrintedRubPlate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  Timer? _hide;
  bool _onScreen = true;
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A hidden tab (IndexedStack) reports Visibility.of == false: the plate
    // waits for the page to be really on screen, and shows again on every
    // return.
    _onScreen = Visibility.of(context);
    _visibilityChanged();
  }

  @override
  void didUpdateWidget(PrintedRubPlate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visibilityChanged();
  }

  void _visibilityChanged() {
    final on = _onScreen;
    if (!on) {
      _shown = false;
      _retry?.cancel();
      _hide?.cancel();
      _fade.value = 0;
      return;
    }
    if (_shown || widget.marks.isEmpty) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWhenTurnedTo());
  }

  Timer? _retry;

  void _showWhenTurnedTo() {
    if (!mounted || !_onScreen) return;
    if (_onScreenSideways(context)) {
      show();
    } else {
      _retry?.cancel();
      _retry = Timer(const Duration(milliseconds: 300), _showWhenTurnedTo);
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _hide?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void show() {
    _hide?.cancel();
    _fade.forward();
    _hide = Timer(rubPlateHold, () {
      if (mounted) _fade.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.marks.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _PrintedPlatePainter(
          marks: widget.marks,
          width: (widget.pageWidth * 0.065).clamp(22.0, 28.0),
          mt: widget.mt,
          baseStyle: widget.baseStyle,
          fade: _fade,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PrintedPlatePainter extends CustomPainter {
  final List<(double, RubInfo)> marks;
  final double width;
  final MushafTheme mt;
  final TextStyle baseStyle;
  final Animation<double> fade;

  _PrintedPlatePainter({
    required this.marks,
    required this.width,
    required this.mt,
    required this.baseStyle,
    required this.fade,
  }) : super(repaint: fade);

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = Curves.easeOut.transform(fade.value);
    if (alpha <= 0) return;
    for (final (y, info) in marks) {
      paintFloatingRubPlate(
        canvas,
        size: size,
        lineY: y,
        alpha: alpha,
        lines: info.marginLines,
        mt: mt,
        baseStyle: baseStyle,
      );
    }
  }

  @override
  bool shouldRepaint(_PrintedPlatePainter old) =>
      old.marks != marks || old.width != width || old.mt != mt;
}

/// The printed plate, about twice its printed size, centred across [size]
/// and level with the «۞» line at [lineY] (kept inside [size]), on a soft
/// shadow so it reads as lying over the page for its few seconds.
void paintFloatingRubPlate(
  Canvas canvas, {
  required Size size,
  required double lineY,
  Rect? within,
  required double alpha,
  required List<String> lines,
  required MushafTheme mt,
  required TextStyle baseStyle,
}) {
  const plateWidth = 48.0;
  final scale = (size.width * 0.2 / plateWidth).clamp(1.3, 2.0);
  // Half the plate's height at scale 1, generous: 3 lines + head and foot.
  final half = (lines.length * 16.0 / 2 + plateWidth * 0.34 + 6) * scale;
  var area = Offset.zero & size;
  if (within != null && within.overlaps(area)) area = area.intersect(within);
  final y = area.height <= half * 2
      ? area.center.dy
      : lineY.clamp(area.top + half, area.bottom - half);
  canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
  canvas.save();
  canvas.translate(size.width / 2, y);
  canvas.scale(scale);
  paintRubPlate(
    canvas,
    centre: Offset.zero,
    width: plateWidth,
    lines: lines,
    mt: mt,
    baseStyle: baseStyle,
    shadow: true,
  );
  canvas.restore();
  canvas.restore();
}

/// Whether [context]'s box stands in the middle of the screen sideways. The
/// mushaf's PageView builds the next page before it is turned to; a plate
/// shown there would spend its seconds off screen.
bool _onScreenSideways(BuildContext context) {
  final ro = context.findRenderObject();
  if (ro is! RenderBox || !ro.hasSize || !ro.attached) return false;
  final x = ro.localToGlobal(ro.size.center(Offset.zero)).dx;
  final w = MediaQuery.sizeOf(context).width;
  return x > w * 0.25 && x < w * 0.75;
}
