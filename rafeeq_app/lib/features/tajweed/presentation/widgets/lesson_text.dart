/// The type every tajweed lesson is read in.
///
/// The owner, 2026-10-02: «اتاكد ان الخط واضح». The lessons used to be set in
/// the interface face (Cairo by default), a geometric sans drawn for labels:
/// at body size its harakat sit cramped against the letters, a shadda and its
/// vowel merge, and the texts here are fully vowelled verse where every mark
/// is the point. They are now set in Noto Naskh Arabic, a naskh drawn for
/// running vowelled text, bundled under `assets/fonts/google_fonts/` (OFL,
/// see CONTENT-LICENSES) so it never needs the network, a size larger and
/// with room between the lines for the marks above and below.
///
/// A verse of the poems is written «صدر ... عجز» in the e-text. On a phone
/// that wraps wherever the width runs out, and the reader loses where one
/// half ends. [LessonVerse] sets the two halves as two centred lines, as the
/// printed mutoon do; the text itself is not changed.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/arabic_text.dart';

/// The face, size and leading for a lesson paragraph.
TextStyle lessonTextStyle({
  double fontSize = 18,
  Color? color,
  FontWeight fontWeight = FontWeight.w400,
}) => GoogleFonts.notoNaskhArabic(
  fontSize: fontSize,
  height: 2.0,
  color: color,
  fontWeight: fontWeight,
);

/// The hemistich separator the e-texts use, with or without a real ellipsis.
final _halves = RegExp(r'\s+(?:\.\.\.|…)\s+');

/// The two halves of a verse written «صدر ... عجز», or null for prose.
List<String>? verseHalves(String text) {
  final parts = text.split(_halves);
  return parts.length == 2 ? parts : null;
}

/// A paragraph of prose (a شرح, a heading, the Tamhid).
class LessonProse extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;
  final FontWeight fontWeight;

  const LessonProse(
    this.text, {
    super.key,
    this.fontSize = 17,
    this.color,
    this.fontWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) => ArabicText(
    text,
    textAlign: TextAlign.justify,
    style: lessonTextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    ),
  );
}

/// A line of verse: two centred halves when it has them, else one line.
class LessonVerse extends StatelessWidget {
  final String text;
  final Color? color;

  const LessonVerse(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final style = lessonTextStyle(
      fontSize: 19,
      color: color,
      fontWeight: FontWeight.w500,
    );
    final halves = verseHalves(text);
    if (halves == null) {
      return ArabicText(text, textAlign: TextAlign.center, style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArabicText(halves[0], textAlign: TextAlign.center, style: style),
        ArabicText(halves[1], textAlign: TextAlign.center, style: style),
      ],
    );
  }
}
