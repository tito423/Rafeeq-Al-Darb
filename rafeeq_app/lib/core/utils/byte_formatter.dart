/// One place that turns a byte count into something readable.
///
/// There were five copies of this scattered across the Downloads, Library and
/// Adhan screens, and every one of them had the same bug: in Arabic the unit
/// rendered **before** the number — «MB 60.5» instead of «60.5 MB».
///
/// The cause is the bidirectional algorithm, not the string. `60.5` is a
/// European number (a *weak* direction that takes its side from what is around
/// it) and `MB` is strong left-to-right, so inside an Arabic (right-to-left)
/// paragraph the two are laid out from the right and the unit lands first.
/// Nothing about the Dart string is wrong; it is the resolved display order.
///
/// The fix is to tell the layout that this fragment is its own left-to-right
/// run: U+2066 LEFT-TO-RIGHT ISOLATE opens it and U+2069 POP DIRECTIONAL
/// ISOLATE closes it. An *isolate* rather than an embedding (U+202A/U+202C) so
/// the fragment also cannot disturb the ordering of the Arabic on either side
/// of it — which is exactly what an embedding would risk.
library;

import 'digits.dart' show localizeDigits, uiLanguageCode;

/// Wraps [text] so it always reads left-to-right, whatever the surrounding
/// paragraph direction is. Use for anything that mixes digits with Latin
/// units or punctuation: sizes, versions, `12:30`, `604 pages`.
///
/// The two code points are built with `String.fromCharCode` rather than
/// written into a literal: they are invisible, so a literal containing them
/// makes the source read differently from how it compiles — which is exactly
/// what the analyzer's `text_direction_code_point_in_literal` warns about.
String ltr(String text) =>
    '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';

/// The mirror of [ltr]: wraps [text] so it always reads right-to-left,
/// whatever the surrounding paragraph direction is. U+2067 RIGHT-TO-LEFT
/// ISOLATE opens it, U+2069 POP DIRECTIONAL ISOLATE closes it.
///
/// Needed for the reverse of the bug [ltr] fixes. The Library's author line
/// is «توفي ١٤٢٠ هـ • 1 livres»: an Arabic fragment first, a Latin one second.
/// Inside a French (left-to-right) paragraph the Arabic run is reordered and
/// the line came out «1 livres توفي ١٤٢٠ هـ» — the two halves swapped, which
/// is what the owner photographed. Isolating each half pins both.
String rtl(String text) =>
    '${String.fromCharCode(0x2067)}$text${String.fromCharCode(0x2069)}';

/// A human-readable size, correct in RTL.
///
/// Uses decimal MB (10⁶), which is what the catalogues in this project
/// measure and what the file sizes were recorded in — not 1024², so the number
/// shown matches the number that was verified against the bucket.
/// A size in the reader's own numerals, still pinned left-to-right.
///
/// Two separate problems, and both fixes have to hold at once:
///
///  * Trap #16 - «60.5 MB» reversed to «MB 60.5» in an Arabic paragraph,
///    because a numeral is bidi-weak and took its direction from the Arabic
///    around it. `ltr()` pins the whole fragment. That stays.
///  * The digits were Latin while the rest of the app was Arabic-Indic. The
///    Downloads screen read «0 B» under «المساحة المستخدمة», and a library
///    card printed a Latin size directly under «توفي ٧٧٤ هـ».
///
/// Safe together: Arabic-Indic digits are class AN, and an AN run inside an
/// LTR isolate is laid out left-to-right as a unit, so «٦٠.٥ MB» keeps its
/// order. The UNIT stays Latin - «MB» is what the unit is called in Arabic
/// software too - and the decimal point stays a point for the same reason.
String _size(String value, String unit) =>
    ltr('${localizeDigits(value, uiLanguageCode)} $unit');

String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 1000) return _size(bytes.toString(), 'B');
  if (bytes < 1000 * 1000) {
    return _size((bytes / 1000).toStringAsFixed(decimals), 'KB');
  }
  if (bytes < 1000 * 1000 * 1000) {
    return _size((bytes / 1000000).toStringAsFixed(decimals), 'MB');
  }
  return _size((bytes / 1000000000).toStringAsFixed(decimals), 'GB');
}

/// A size in binary units (1024²), for the on-device storage readouts that
/// were already reporting that way — changing those numbers would make the
/// Downloads screen disagree with Android's own storage figures.
String formatBytesBinary(int bytes, {int decimals = 1}) {
  if (bytes < 1024) return _size(bytes.toString(), 'B');
  if (bytes < 1024 * 1024) {
    return _size((bytes / 1024).toStringAsFixed(decimals), 'KB');
  }
  if (bytes < 1024 * 1024 * 1024) {
    return _size((bytes / (1024 * 1024)).toStringAsFixed(decimals), 'MB');
  }
  return _size((bytes / (1024 * 1024 * 1024)).toStringAsFixed(decimals), 'GB');
}

/// «٠ / ٣٣», never «٣٣ / ٠» — two numbers with a separator between them.
///
/// THE DEFECT THIS EXISTS FOR, found twice in one day. The mushaf's page
/// badge rendered page 1 of 604 as «٦٠٤ / ١», and the tasbeeh counter
/// rendered 0 of 33 as «33 / 0». Both were written as one plain string,
/// `'$a / $b'`, and both flipped.
///
/// And [ltr] alone does NOT fix it — that was tried on the device first. The
/// isolate fixes where the run sits inside its paragraph; it does not change
/// what the neutral characters *inside* the run resolve to. The bidi
/// algorithm's rule N1 treats a number as **R** when deciding what a neutral
/// between two numbers becomes, so the « / » resolves right-to-left and the
/// two numbers swap around it — inside an isolate, and inside an LTR
/// paragraph, just the same.
///
/// The fix is to give that neutral a strong left-to-right neighbour on each
/// side. U+200E LEFT-TO-RIGHT MARK is a zero-width strong L: with one before
/// and one after the separator, N1 has no numbers to look at and resolves L.
/// The whole thing is then wrapped in [ltr] as well, so the fragment cannot
/// be re-ordered by the Arabic around it either (trap #16).
///
/// The marks are built with `String.fromCharCode` for the same reason [ltr]'s
/// are: they are invisible, and a literal containing them makes the source
/// read differently from how it compiles.
String ratio(Object a, Object b, {String separator = ' / '}) {
  const lrm = 0x200E;
  final mark = String.fromCharCode(lrm);
  return ltr('$a$mark$separator$mark$b');
}
