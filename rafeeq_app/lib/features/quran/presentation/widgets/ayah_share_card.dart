import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

// `hide TextDirection`: easy_localization re-exports package:intl, whose
// TextDirection collides with dart:ui's - and this file uses dart:ui's.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/utils/digits.dart';

/// The ayah as a shared picture, always inside an Islamic ornamental frame
/// (owner, 2026-11-10: «دايما حطها في شكل زخرفة اسلامية»), alone or with its
/// translation, a tafsir, or its i'rab under it.
///
/// A long text does not shrink and is not cut: it runs on over as many
/// cards as it needs ([planShare]), each a whole picture with the same
/// frame, and they are shared together.

/// The colours of the frame.
enum ShareStyle { night, emerald, parchment }

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
  };
}

/// What goes under the ayah.
class ShareBody {
  /// «التفسير الميسّر», «English», «الإعراب».
  final String title;
  final String text;
  final TextDirection direction;

  /// Draw the Qur'an words an i'rab quotes («…») in the frame's gold.
  final bool markQuotes;
  const ShareBody({
    required this.title,
    required this.text,
    this.direction = TextDirection.rtl,
    this.markQuotes = false,
  });
}

class ShareContent {
  final String ayahText;
  final String surahName;

  /// «2:255», already in the reader's numerals.
  final String reference;

  /// «31_22»: Latin digits for the picture's file name (the reference may be
  /// in Arabic-Indic digits, which a file name filter would drop).
  final String fileTag;
  final ShareBody? body;
  const ShareContent({
    required this.ayahText,
    required this.surahName,
    required this.reference,
    this.fileTag = 'ayah',
    this.body,
  });
}

// One card's measures, in logical pixels. The picture is 3x this.
const double shareCardWidth = 720;
const double _padH = 78;
const double _padTop = 84;
const double _padBottom = 70;
const double _headerHeight = 96;
const double _footerHeight = 58;
const double _bodyTitleHeight = 74;
const double _maxCardHeight = 1240;
const double _textWidth = shareCardWidth - _padH * 2;

/// The most pictures one share may carry; a longer text is offered as text.
const int shareMaxCards = 10;

TextStyle _ayahStyle(SharePalette c) => TextStyle(
  fontFamily: 'KFGQPCHafs',
  letterSpacing: 0, // any spacing turns the font's ligatures off
  fontSize: 31,
  height: 1.95,
  color: c.ink,
);

TextStyle _bodyStyle(SharePalette c) => TextStyle(
  fontSize: 18.5,
  height: 1.75,
  color: c.ink.withValues(alpha: 0.94),
);

/// One card: the ayah (first card only) and the stretch of the body on it.
class ShareCardPlan {
  final bool showAyah;
  final String? bodyText;
  const ShareCardPlan({required this.showAyah, this.bodyText});
}

double _heightOf(
  String text,
  TextStyle style,
  TextDirection direction, {
  TextAlign align = TextAlign.start,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textAlign: align,
  )..layout(maxWidth: _textWidth);
  final h = tp.height;
  tp.dispose();
  return h;
}

/// Where [text] must be cut so that what comes before fits in [height]:
/// the end of the last whole line. Returns the text's length when all fits.
int _fitOffset(
  String text,
  TextStyle style,
  TextDirection direction,
  double height,
) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textAlign: TextAlign.justify,
  )..layout(maxWidth: _textWidth);
  try {
    if (tp.height <= height) return text.length;
    var used = 0.0;
    var lines = 0;
    for (final m in tp.computeLineMetrics()) {
      if (used + m.height > height) break;
      used += m.height;
      lines++;
    }
    if (lines == 0) return 0;
    final at = tp.getPositionForOffset(Offset(_textWidth / 2, used - 2));
    return tp.getLineBoundary(at).end;
  } finally {
    tp.dispose();
  }
}

/// Splits [content] over cards, none taller than the card's limit. The ayah
/// is never split: a very long one makes its own card as tall as it needs.
List<ShareCardPlan> planShare(ShareContent content, SharePalette palette) {
  final body = content.body;
  if (body == null || body.text.trim().isEmpty) {
    return const [ShareCardPlan(showAyah: true)];
  }
  final style = _bodyStyle(palette);
  const frame = _padTop + _headerHeight + _footerHeight + _padBottom;
  final ayahHeight = _heightOf(
    content.ayahText,
    _ayahStyle(palette),
    TextDirection.rtl,
    align: TextAlign.center,
  );
  const rest = _maxCardHeight - frame - _bodyTitleHeight;
  var first = rest - ayahHeight - 8;

  final plans = <ShareCardPlan>[];
  var text = body.text.trim();
  // Too little room under the ayah for a useful start: the body begins on
  // the next card.
  if (first < 150) {
    plans.add(const ShareCardPlan(showAyah: true));
    first = rest;
  }
  while (text.isNotEmpty) {
    // Gold, heavier quoted words run a little wider than the plain text
    // measured here, so an i'rab keeps a line in hand.
    final room = (plans.isEmpty ? first : rest) - (body.markQuotes ? 40 : 4);
    var cut = _fitOffset(text, style, body.direction, room);
    if (cut <= 0) cut = math.min(text.length, 200);
    plans.add(
      ShareCardPlan(
        showAyah: plans.isEmpty,
        bodyText: text.substring(0, cut).trimRight(),
      ),
    );
    text = text.substring(cut).trimLeft();
    if (plans.length > 60) break; // a guard, far past [shareMaxCards]
  }
  return plans;
}

/// One card of a share. Public so the options sheet can show it as it will
/// be sent.
class AyahShareCard extends StatelessWidget {
  final ShareContent content;
  final ShareCardPlan plan;
  final ShareStyle style;
  final int index;
  final int count;

  const AyahShareCard({
    super.key,
    required this.content,
    required this.plan,
    required this.style,
    this.index = 0,
    this.count = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = SharePalette.of(style);
    final body = content.body;
    final bodyText = plan.bodyText;
    return MediaQuery(
      // The plan was measured unscaled; the picture must not follow the
      // phone's font size.
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: shareCardWidth,
        child: CustomPaint(
          painter: ShareFramePainter(c),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _padH,
              _padTop,
              _padH,
              _padBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: _Header(content: content, c: c),
                ),
                if (plan.showAyah)
                  Text(
                    content.ayahText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: _ayahStyle(c),
                  ),
                if (body != null && bodyText != null) ...[
                  SizedBox(
                    height: _bodyTitleHeight,
                    child: _BodyTitle(title: body.title, c: c),
                  ),
                  Text.rich(
                    _bodySpan(bodyText, body, c),
                    textAlign: TextAlign.justify,
                    textDirection: body.direction,
                  ),
                ],
                SizedBox(
                  height: _footerHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      count > 1
                          ? '${'app.name'.tr()}  •  '
                                '${localizeDigits(ratio(index + 1, count), uiLanguageCode)}'
                          : 'app.name'.tr(),
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: c.soft, fontSize: 13.5),
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

  TextSpan _bodySpan(String text, ShareBody body, SharePalette c) {
    final base = _bodyStyle(c);
    if (!body.markQuotes) return TextSpan(text: text, style: base);
    final spans = <TextSpan>[];
    var at = 0;
    for (final m in RegExp('«[^»]*»').allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(color: c.gold, fontWeight: FontWeight.w700),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: base, children: spans);
  }
}

class _Header extends StatelessWidget {
  final ShareContent content;
  final SharePalette c;
  const _Header({required this.content, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          painter: _CartouchePainter(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 9),
            child: Text(
              content.surahName,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'KFGQPCHafs',
                letterSpacing: 0,
                fontSize: 23,
                height: 1.4,
                color: c.gold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content.reference,
          style: TextStyle(
            color: c.soft,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _BodyTitle extends StatelessWidget {
  final String title;
  final SharePalette c;
  const _BodyTitle({required this.title, required this.c});

  @override
  Widget build(BuildContext context) {
    Widget rule() => Expanded(
      child: Container(height: 1, color: c.gold.withValues(alpha: 0.45)),
    );
    return Row(
      children: [
        rule(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: CustomPaint(
            size: const Size(14, 14),
            painter: _StarPainter(c.gold),
          ),
        ),
        Flexible(
          flex: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.gold,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: CustomPaint(
            size: const Size(14, 14),
            painter: _StarPainter(c.gold),
          ),
        ),
        rule(),
      ],
    );
  }
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

class _StarPainter extends CustomPainter {
  final Color color;
  const _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    canvas.drawPath(
      eightPointStar(centre, size.shortestSide / 2),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// The surah name's plate: a long hexagon with a star at each point.
class _CartouchePainter extends CustomPainter {
  final SharePalette c;
  const _CartouchePainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const nose = 22.0;
    final plate = Path()
      ..moveTo(nose, 0)
      ..lineTo(w - nose, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - nose, h)
      ..lineTo(nose, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(plate, Paint()..color = c.band.withValues(alpha: 0.85));
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = c.gold,
    );
    final star = Paint()..color = c.gold;
    canvas.drawPath(eightPointStar(Offset(nose + 4, h / 2), 6), star);
    canvas.drawPath(eightPointStar(Offset(w - nose - 4, h / 2), 6), star);
  }

  @override
  bool shouldRepaint(_CartouchePainter old) => old.c != c;
}

/// The frame: a ground with a faint lattice of eight-pointed stars, a gold
/// double border holding a chain of stars and diamonds, and a medallion at
/// each corner.
class ShareFramePainter extends CustomPainter {
  final SharePalette c;
  const ShareFramePainter(this.c);

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

    // The lattice: stars on a square grid, a small diamond between four.
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = c.gold.withValues(alpha: 0.075);
    const step = 60.0;
    canvas.save();
    canvas.clipRect(full.deflate(44));
    for (var y = 44.0 + step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width + step; x += step) {
        canvas.drawPath(eightPointStar(Offset(x, y), 19), lattice);
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

    // The chain in the band: a star, a diamond, a star...
    final fill = Paint()..color = c.gold;
    final dim = Paint()..color = c.gold.withValues(alpha: 0.6);
    const mid = 31.0; // the band's centre line, from the card's edge
    void run(Offset from, Offset to) {
      final length = (to - from).distance;
      final n = (length / 30).floor();
      for (var i = 1; i < n; i++) {
        final at = Offset.lerp(from, to, i / n)!;
        if (i.isEven) {
          canvas.drawPath(eightPointStar(at, 5.2), fill);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(at.dx, at.dy - 3.4)
              ..lineTo(at.dx + 3.4, at.dy)
              ..lineTo(at.dx, at.dy + 3.4)
              ..lineTo(at.dx - 3.4, at.dy)
              ..close(),
            dim,
          );
        }
      }
    }

    const corner = 46.0;
    final w = size.width;
    final h = size.height;
    run(const Offset(corner, mid), Offset(w - corner, mid));
    run(Offset(corner, h - mid), Offset(w - corner, h - mid));
    run(const Offset(mid, corner), Offset(mid, h - corner));
    run(Offset(w - mid, corner), Offset(w - mid, h - corner));

    // Corner medallions.
    for (final at in [
      const Offset(corner, corner),
      Offset(w - corner, corner),
      Offset(corner, h - corner),
      Offset(w - corner, h - corner),
    ]) {
      canvas.drawCircle(at, 30, Paint()..color = c.bottom);
      canvas.drawCircle(
        at,
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = c.gold,
      );
      canvas.drawPath(eightPointStar(at, 24), Paint()..color = c.band);
      canvas.drawPath(
        eightPointStar(at, 24),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c.gold,
      );
      canvas.drawPath(eightPointStar(at, 11, turn: math.pi / 8), fill);
      canvas.drawCircle(at, 3.2, Paint()..color = c.bottom);
    }
  }

  @override
  bool shouldRepaint(ShareFramePainter old) => old.c != c;
}

/// Draws every card of [content] off screen and returns the PNGs, in order.
Future<List<Uint8List>> renderShareCards(
  BuildContext context, {
  required ShareContent content,
  required ShareStyle style,
}) async {
  final plans = planShare(content, SharePalette.of(style));
  final overlay = Overlay.of(context, rootOverlay: true);
  final out = <Uint8List>[];
  for (var i = 0; i < plans.length; i++) {
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Off screen but laid out and painted, so it can be captured
        // without flashing on the real screen.
        left: -4000,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: key,
            child: AyahShareCard(
              content: content,
              plan: plans[i],
              style: style,
              index: i,
              count: plans.length,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('share card was not laid out');
      // 3x unless the card is so tall the picture would pass what a phone's
      // GPU takes as one texture.
      final ratio = math.min(3.0, 8000 / boundary.size.height);
      final image = await boundary.toImage(pixelRatio: ratio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('share card was not encoded');
      out.add(bytes.buffer.asUint8List());
    } finally {
      entry.remove();
    }
  }
  return out;
}

/// Renders [content] and hands the pictures to the system share sheet.
/// Nothing is uploaded; the files are temporary PNGs. Returns false on
/// failure and never throws into the UI.
Future<bool> shareAyahAsImages(
  BuildContext context, {
  required ShareContent content,
  required ShareStyle style,
}) async {
  try {
    final pngs = await renderShareCards(
      context,
      content: content,
      style: style,
    );
    final dir = await getTemporaryDirectory();
    final safeRef = content.fileTag.replaceAll(RegExp('[^0-9A-Za-z]+'), '_');
    final files = <XFile>[];
    for (var i = 0; i < pngs.length; i++) {
      final file = File(p.join(dir.path, 'ayah_${safeRef}_${i + 1}.png'));
      await file.writeAsBytes(pngs[i], flush: true);
      files.add(XFile(file.path));
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        text: '${'app.name'.tr()} — ${content.surahName} ${content.reference}',
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// The same content as plain text, for a message or a long tafsir.
String shareAyahText(ShareContent content) {
  final b = StringBuffer()
    ..writeln('﴿${content.ayahText}﴾')
    ..writeln('[${content.surahName} ${content.reference}]');
  final body = content.body;
  if (body != null && body.text.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln('${body.title}:')
      ..writeln(body.text.trim());
  }
  b
    ..writeln()
    ..write('— ${'app.name'.tr()}');
  return b.toString();
}
