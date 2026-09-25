/// The picture tour the reader sees (see [TourSlides]).
part of 'tutorial_overlay.dart';

/// The tour as the reader sees it: one photograph of the real screen per
/// stop, taken in his own language by `scripts/capture_tour.py`, with the
/// feature framed on it and the explanation under it. Nothing behind it can
/// be touched, so no stray tap can end the tour.
///
/// A stop with no photograph for this language (a feature that was not on
/// screen when the photographs were taken) is left out rather than shown
/// with a picture of something else. The welcome has no picture.
class TourSlides extends StatefulWidget {
  final List<TutorialChapter> chapters;
  final VoidCallback onFinish;

  const TourSlides({super.key, required this.chapters, required this.onFinish});

  @override
  State<TourSlides> createState() => _TourSlidesState();
}

class _TourSlidesState extends State<TourSlides>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _frames;
  int _i = 0;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/tour/frames.json')
        .then((s) => jsonDecode(s) as Map<String, dynamic>)
        .catchError((_) => <String, dynamic>{})
        .then((f) {
          if (mounted) setState(() => _frames = f);
        });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _frameOf(String locale, TutorialChapter c) =>
      (_frames?[locale] as Map<String, dynamic>?)?[c.key]
          as Map<String, dynamic>?;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    if (_frames == null) {
      return ColoredBox(color: scheme.surface);
    }
    final stops = [
      for (final c in widget.chapters)
        if ((c.anchor == null && !c.whole) || _frameOf(locale, c) != null) c,
    ];
    final i = _i.clamp(0, stops.length - 1);
    final chapter = stops[i];
    final frame = _frameOf(locale, chapter);
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            children: [
              Expanded(
                child: frame == null
                    ? Center(
                        child: Icon(
                          chapter.icon,
                          size: 96,
                          color: chapter.accent,
                        ),
                      )
                    : Center(child: _shot(locale, chapter, frame)),
              ),
              const SizedBox(height: 10),
              _ChapterBubble(
                chapter: chapter,
                index: i,
                total: stops.length,
                locale: locale,
                isFirst: i == 0,
                isLast: i == stops.length - 1,
                onPrev: i == 0 ? null : () => setState(() => _i = i - 1),
                onNext: i == stops.length - 1
                    ? widget.onFinish
                    : () => setState(() => _i = i + 1),
                onSkip: widget.onFinish,
                pointerX: null,
                pointerBelow: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shot(String locale, TutorialChapter c, Map<String, dynamic> f) {
    final aspect = (f['a'] as num).toDouble();
    final r = (f['r'] as List).map((v) => (v as num).toDouble()).toList();
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final spot = Rect.fromLTRB(
            r[0] * w,
            r[1] * h,
            r[2] * w,
            r[3] * h,
          ).inflate(6);
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/tour/$locale/${c.key}.webp',
                  fit: BoxFit.fill,
                ),
                // A whole screen is framed all round and nothing is dimmed.
                if (c.whole)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.accent, width: 3),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => CustomPaint(
                      painter: _SpotlightPainter(
                        spot: spot,
                        accent: c.accent,
                        pulse: _pulse.value,
                        draw: 1,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
