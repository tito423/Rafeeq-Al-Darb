import 'package:intl/intl.dart';

import 'byte_formatter.dart' show ltr;

/// Formats a HH:mm 24h time string into a 12-hour AM/PM string.
///
/// Wrapped in [ltr] for the same reason `formatBytes` is (CLAUDE.md trap #16):
/// «7:36 AM» is a bidi-weak numeral followed by a Latin marker, and inside an
/// Arabic or Urdu paragraph the two swap. The Urdu build showed the sunrise
/// tile as «AM 7:36» on emulator-5554. A LEFT-TO-RIGHT ISOLATE pins the whole
/// fragment as one left-to-right run without adding a visible character.
String formatTime12h(String hhmm) {
  if (hhmm == '--:--' || hhmm.isEmpty) return hhmm;
  try {
    final parts = hhmm.split(':');
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    return ltr(DateFormat('h:mm a').format(dt));
  } catch (_) {
    return hhmm;
  }
}
