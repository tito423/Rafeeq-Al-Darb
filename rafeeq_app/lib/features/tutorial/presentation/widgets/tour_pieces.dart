/// The tour's drawing: the spotlight frame, the explanation card and its
/// pointer, and the language row. Shared by the slides and the capture walk.
part of 'tutorial_overlay.dart';

/// The dim with a rounded hole cut in it, plus a breathing ring on the rim.
class _SpotlightPainter extends CustomPainter {
  final Rect? spot;
  final Color accent;
  final double pulse;

  /// 0 → 1 as the frame's border draws itself around the feature.
  final double draw;

  const _SpotlightPainter({
    required this.spot,
    required this.accent,
    required this.pulse,
    required this.draw,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    // «خفي اللي وراها»: dark enough that the lit part is the only thing the
    // eye lands on.
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.84);
    if (spot == null) {
      canvas.drawRect(full, dim);
      return;
    }
    final r = spot!;
    final hole = RRect.fromRectAndRadius(r, const Radius.circular(18));
    // saveLayer + BlendMode.clear is the only way to punch a real hole: a
    // second rectangle in "the background colour" would be wrong on every
    // theme, and there are four.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dim);
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // THE FRAME. «يحاوط … بفريم شكله جميل». A soft halo of the stop's own
    // colour, then a gold-to-accent border that DRAWS ITSELF around the
    // feature as the spotlight arrives, then a diamond ornament at each
    // corner once the border has closed.
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = accent.withValues(alpha: 0.18 + 0.12 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(hole.inflate(3), halo);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [AppColors.gold, accent, AppColors.gold],
      ).createShader(r);
    final outline = Path()..addRRect(hole);
    for (final metric in outline.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw.clamp(0.0, 1.0)),
        border,
      );
    }
    // A thin inner line a few pixels in, for the double-rule look of an
    // illuminated frame.
    if (draw >= 1) {
      canvas.drawRRect(
        hole.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.gold.withValues(alpha: 0.55),
      );
    }

    final ornament = ((draw - 0.75) / 0.25).clamp(0.0, 1.0);
    if (ornament > 0) {
      final s = 7.0 * ornament * (1 + 0.12 * pulse);
      final fill = Paint()..color = AppColors.gold;
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent;
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final diamond = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s, c.dy)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - s, c.dy)
          ..close();
        canvas.drawPath(diamond, fill);
        canvas.drawPath(diamond, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spot != spot ||
      old.pulse != pulse ||
      old.accent != accent ||
      old.draw != draw;
}

/// The explanation itself: a small card with a pointer on the edge facing
/// whatever is lit.
class _ChapterBubble extends StatelessWidget {
  final TutorialChapter chapter;
  final int index;
  final int total;
  final String locale;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Horizontal position of the thing being pointed at, in global pixels.
  /// Null hides the pointer.
  final double? pointerX;

  /// True when the target is BELOW the bubble, so the pointer sits on the
  /// bottom edge.
  final bool pointerBelow;

  const _ChapterBubble({
    required this.chapter,
    required this.index,
    required this.total,
    required this.locale,
    required this.isFirst,
    required this.isLast,
    required this.onPrev,
    required this.onNext,
    required this.onSkip,
    required this.pointerX,
    required this.pointerBelow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: chapter.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(chapter.icon, color: chapter.accent, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'tutorial.${chapter.key}_title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${localizeDigits('${index + 1}', locale)}'
                  ' / ${localizeDigits('$total', locale)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress, animated from the previous stop's width to this one.
            TweenAnimationBuilder<double>(
              tween: Tween(end: (index + 1) / total),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  color: chapter.accent,
                  backgroundColor: chapter.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'tutorial.${chapter.key}_body'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (isFirst) ...[const SizedBox(height: 12), const _LanguageRow()],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  child: Text('tutorial.skip'.tr()),
                ),
                const Spacer(),
                if (onPrev != null)
                  TextButton(
                    onPressed: onPrev,
                    child: Text('tutorial.back'.tr()),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: chapter.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    isLast ? 'tutorial.done'.tr() : 'tutorial.next'.tr(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (pointerX == null) return body;
    final pointer = CustomPaint(
      painter: _PointerPainter(
        x: pointerX!,
        color: scheme.surface,
        up: !pointerBelow,
      ),
      size: const Size(double.infinity, 10),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: pointerBelow ? [body, pointer] : [pointer, body],
    );
  }
}

/// The little triangle on the bubble's edge. Drawn rather than rotated from a
/// glyph so its tip lands under the spotlight's centre whatever the bubble's
/// own left edge is.
class _PointerPainter extends CustomPainter {
  /// Global x of the thing being pointed at.
  final double x;
  final Color color;

  /// True when the triangle sits on the TOP edge (target above the bubble).
  final bool up;

  const _PointerPainter({
    required this.x,
    required this.color,
    required this.up,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The bubble is inset 12 px from the window, and 20 px of margin keeps
    // the tip off a rounded corner.
    final cx =
        x.clamp(20.0, math.max(20.0, size.width + 12 - 20.0)).toDouble() - 12;
    final path = Path();
    if (up) {
      path
        ..moveTo(cx, 0)
        ..lineTo(cx - 10, size.height)
        ..lineTo(cx + 10, size.height);
    } else {
      path
        ..moveTo(cx, size.height)
        ..lineTo(cx - 10, 0)
        ..lineTo(cx + 10, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.x != x || old.up != up || old.color != color;
}

/// The language picker, offered where a reader who cannot read the tour will
/// actually meet it. Changing it here changes the app — the same
/// `context.setLocale` every other language control calls — so the rest of the
/// tour continues in the language just chosen.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'tutorial.language'.tr(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in kLanguageNames.entries)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: e.key == current,
                onSelected: (_) {
                  if (e.key != current) context.setLocale(Locale(e.key));
                },
              ),
          ],
        ),
      ],
    );
  }
}
