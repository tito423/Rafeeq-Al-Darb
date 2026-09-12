/// «خلفيات شاشة الأذان» — pick one of the ten grounds.
///
/// Every tile is the real painter, running, at tile size. A still thumbnail
/// would be a picture of a thing rather than the thing, and half of these are
/// only themselves once they move — the lanterns rise, the muqarnas light
/// travels, the domes ripple outward. It is also the honest way to choose:
/// what you see in the grid is exactly what the adhan screen will wear.
///
/// One `AnimationController` for the whole grid, shared by all ten painters,
/// so ten previews cost one ticker.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/adhan_background.dart';
import '../widgets/adhan_background_painter.dart';

class AdhanBackgroundScreen extends ConsumerStatefulWidget {
  const AdhanBackgroundScreen({super.key});

  @override
  ConsumerState<AdhanBackgroundScreen> createState() =>
      _AdhanBackgroundScreenState();
}

class _AdhanBackgroundScreenState extends ConsumerState<AdhanBackgroundScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 30),
  )..repeat();

  double get _now =>
      (_clock.lastElapsedDuration ?? Duration.zero).inMilliseconds / 1000.0;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(adhanBackgroundProvider);
    return Scaffold(
      appBar: AppBar(title: Text('adhan.backgrounds_title'.tr())),
      body: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: AdhanBackground.values.length,
          itemBuilder: (context, i) {
            final style = AdhanBackground.values[i];
            return _BackgroundTile(
              style: style,
              seconds: _now,
              selected: style == selected,
              onTap: () =>
                  ref.read(adhanBackgroundProvider.notifier).set(style),
            );
          },
        ),
      ),
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  final AdhanBackground style;
  final double seconds;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundTile({
    required this.style,
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _PreviewPainter(style, seconds)),
            // The name sits on its own dark band rather than straight on the
            // art: ten different grounds means ten different amounts of
            // contrast, and a label has to be legible on all of them.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  style.nameKey.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (selected)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.check_circle_rounded,
                    color: AppColors.gold, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final AdhanBackground style;
  final double seconds;

  const _PreviewPainter(this.style, this.seconds);

  /// The isha sky, for every tile. Choosing a ground is a choice about the
  /// PATTERN, so showing each one over a different prayer's sky would make
  /// them look different for a reason that is not the one being chosen.
  static const _top = Color(0xFF0B1B33);
  static const _bottom = Color(0xFF13314C);

  @override
  void paint(Canvas canvas, Size size) {
    paintAdhanBackground(
      canvas,
      Offset.zero & size,
      style,
      _top,
      _bottom,
      AppColors.goldSoft,
      seconds,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.seconds != seconds || old.style != style;
}
