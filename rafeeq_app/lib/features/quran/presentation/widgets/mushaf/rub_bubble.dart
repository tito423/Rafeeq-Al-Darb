import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/rub_el_hizb.dart';

OverlayEntry? _open;
Timer? _timer;

void _close() {
  _timer?.cancel();
  _timer = null;
  _open?.remove();
  _open = null;
}

/// A small label at the tapped «۞» saying which quarter it is.
///
/// It takes no gesture of its own: it leaves after [_shown], or the moment
/// a finger touches the screen anywhere - and that touch still reaches the
/// page under it (a swipe turns the page, a long press opens the ayah).
void showRubBubble(BuildContext context, RubInfo info, Offset globalPosition) {
  _close();
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => _RubBubble(info: info, at: globalPosition),
  );
  _open = entry;
  overlay.insert(entry);
  _timer = Timer(_shown, _close);
}

const _shown = Duration(seconds: 4);

class _RubBubble extends StatelessWidget {
  final RubInfo info;
  final Offset at;
  const _RubBubble({required this.info, required this.at});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const width = 230.0;
    final left = (at.dx - width / 2).clamp(8.0, size.width - width - 8);
    // Above the finger when there is room, else under it.
    final above = at.dy > 150;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _close(),
          ),
        ),
        Positioned(
          left: left,
          width: width,
          top: above ? null : at.dy + 28,
          bottom: above ? size.height - at.dy + 22 : null,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2135),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gold, width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$rubElHizbMark ${info.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
