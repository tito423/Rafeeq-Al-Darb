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
