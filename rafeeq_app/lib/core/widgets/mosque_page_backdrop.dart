import 'package:flutter/material.dart';

/// A whole page standing on one calm mosque photograph, washed in the
/// theme's own background so every card and word on it stays readable.
///
/// Owner, 2026-11-14, for the Quran and Prayer pages: «خلفية مسجد إسلامي
/// هادية جميلة». The wash is heavy on purpose (0.72 to 0.86): the photo is
/// atmosphere behind the cards, not a picture to look at, and the text on
/// the cards keeps its contrast in light and dark alike.
class MosquePageBackdrop extends StatelessWidget {
  final String photo;
  final Widget child;

  const MosquePageBackdrop({
    super.key,
    required this.photo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(photo, fit: BoxFit.cover, gaplessPlayback: true),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: 0.72),
                base.withValues(alpha: 0.86),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
