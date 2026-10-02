import 'package:flutter/material.dart';

/// One verse of the poem, set the way a printed نظم sets it: the first
/// half-line (الصدر) at the start, the second (العجز) under it at the end.
///
/// The text arrives as one paragraph with the two halves joined by «...»
/// (or «…»), and a plain centred `Text` broke it wherever the width ran
/// out — «أَنْ / يَعْلَمَهْ» split off the end of a line on the owner's phone
/// (2026-10-02). Each half now keeps to one line, scaled down only if a
/// narrow screen cannot hold it; the separator itself is not drawn, since
/// the layout already shows where one half ends.
class JazariyyahVerseLines extends StatelessWidget {
  const JazariyyahVerseLines({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  static final _separator = RegExp(r'\s*(?:\.\.\.|…)\s*');
  static final _haraka = RegExp('[\u064B-\u0652]');

  /// Two halves, each short enough to be a half-line and vowelled the way
  /// the poem is. Measured over both bundled books (2026-10-02): every
  /// verse half is under 70 characters with harakat on at least a fifth of
  /// its characters; the prose lines that contain «...» have almost none.
  static bool isTwoHalfLines(Iterable<String> halves) {
    if (halves.length != 2) return false;
    for (final h in halves) {
      final t = h.trim();
      if (t.length > 70) return false;
      if (_haraka.allMatches(t).length < t.length * 0.2) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final halves = text.split(_separator).where((h) => h.trim().isNotEmpty);
    // Not a verse after all — prose that happens to hold «...», like «مثل
    // " كنتم" ... الخ» in the شرح: draw it as it came.
    if (!isTwoHalfLines(halves)) {
      return Text(text, textAlign: TextAlign.center, style: style);
    }
    Widget half(String h, AlignmentDirectional at) => Align(
          alignment: at,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: at,
            child: Text(h.trim(), maxLines: 1, style: style),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        half(halves.first, AlignmentDirectional.centerStart),
        half(halves.last, AlignmentDirectional.centerEnd),
      ],
    );
  }
}
