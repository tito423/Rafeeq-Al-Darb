import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

const splashFirstFrame = AssetImage('assets/branding/splash_first_frame.jpg');

/// `splash_intro.mp4` and its first frame are both 720x1280 (measured).
const splashClipSize = Size(720, 1280);

/// The intro is a portrait clip; the screen is whatever the owner holds.
///
/// `BoxFit.cover` alone was right for a phone upright and wrong for every
/// other shape: recorded on the owner's Xiaomi held sideways (2026-09-26),
/// cover scaled the clip to the screen's WIDTH and cut the emblem's top and
/// the whole wordmark away. The same happens on a portrait tablet (3:4 is
/// wider than 9:16).
///
/// So when the screen is wider than the clip, the clip is shown whole at the
/// screen's height, and the band either side is the clip's own storm - the
/// first frame, covering, blurred and dimmed so it reads as ground rather than
/// as a second copy of the picture. On an upright phone (narrower than the
/// clip) nothing changes: cover trims a sliver of sky at the sides, as before.
class WholeClip extends StatelessWidget {
  const WholeClip({super.key, required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final media = SizedBox(
        width: size.width,
        height: size.height,
        child: child,
      );
      final wider = box.maxWidth / box.maxHeight > size.width / size.height;
      if (!wider) {
        return SizedBox.expand(
          child: FittedBox(fit: BoxFit.cover, child: media),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: const Image(
              image: splashFirstFrame,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const ColoredBox(color: Color(0x59000000)),
          FittedBox(fit: BoxFit.contain, child: media),
        ],
      );
    });
  }
}
