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

/// A human-readable size, correct in RTL.
///
/// Uses decimal MB (10⁶), which is what the catalogues in this project
/// measure and what the file sizes were recorded in — not 1024², so the number
/// shown matches the number that was verified against the bucket.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes < 1000) return ltr('$bytes B');
  if (bytes < 1000 * 1000) {
    return ltr('${(bytes / 1000).toStringAsFixed(decimals)} KB');
  }
  if (bytes < 1000 * 1000 * 1000) {
    return ltr('${(bytes / 1000000).toStringAsFixed(decimals)} MB');
  }
  return ltr('${(bytes / 1000000000).toStringAsFixed(decimals)} GB');
}

/// A size in binary units (1024²), for the on-device storage readouts that
/// were already reporting that way — changing those numbers would make the
/// Downloads screen disagree with Android's own storage figures.
String formatBytesBinary(int bytes, {int decimals = 1}) {
  if (bytes < 1024) return ltr('$bytes B');
  if (bytes < 1024 * 1024) {
    return ltr('${(bytes / 1024).toStringAsFixed(decimals)} KB');
  }
  if (bytes < 1024 * 1024 * 1024) {
    return ltr('${(bytes / (1024 * 1024)).toStringAsFixed(decimals)} MB');
  }
  return ltr('${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(decimals)} GB');
}
