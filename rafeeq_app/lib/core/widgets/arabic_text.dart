import 'package:flutter/widgets.dart';

/// Arabic content laid out right-to-left **whatever language the app is in**.
///
/// The app's `Directionality` follows the UI locale, so on a French or Spanish
/// UI every Arabic string inherits a left-to-right paragraph. A single Arabic
/// word survives that; a line that mixes runs does not — the bidirectional
/// algorithm reorders it around the paragraph direction. The owner
/// photographed the Library on a French UI showing an author line whose
/// separator and parenthesised dates had migrated to the wrong end.
///
/// This is not a translation and not a style: the text is scripture-adjacent
/// content in its own script, and it should be laid out in that script's own
/// direction regardless of the chrome around it. Use it for any Arabic
/// content — titles, author names, descriptions — rendered inside a UI that
/// may not be Arabic. For a *fragment* inside an otherwise Latin sentence,
/// use `rtl()` from `core/utils/byte_formatter.dart` instead.
class ArabicText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  const ArabicText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        data,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}

/// The same widget for text that MAY be Arabic and may be a translation of it.
///
/// A quote card shows the saying in the reader's language, and under it the
/// author's own Arabic. The first must follow the app's direction and the
/// second must be right-to-left, and they are two different widgets only
/// because that distinction is real — wrapping an English sentence in
/// `ArabicText` puts its full stop at the head of the line, which is exactly
/// the defect the Hijri day sheet shipped with.
class ScriptText extends StatelessWidget {
  final String data;

  /// True when [data] is Arabic, whatever the UI language is.
  final bool arabic;

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  const ScriptText(
    this.data, {
    super.key,
    required this.arabic,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) => arabic
      ? ArabicText(data,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign)
      : Text(data,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign);
}
