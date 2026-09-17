import 'package:intl/intl.dart';

import 'byte_formatter.dart' show ltr;

/// Formats a HH:mm 24-hour time into a 12-hour clock **in the reader's own
/// language**.
///
/// THE DEFECT THIS FIXES. The call was `DateFormat('h:mm a')` with no locale,
/// and `Intl.defaultLocale` is never set anywhere in this app — so `intl`
/// fell back to `en_US` and wrote **AM/PM for all seven languages**. The
/// owner caught it on his own phone: the prayer card read «المغرب، ٦:٢١ PM»
/// — Arabic-Indic digits, an Arabic prayer name, and a Latin marker glued to
/// the end of it.
///
/// Arabic writes «ص» and «م», Urdu «AM»/«PM» in its own convention, Russian
/// «AM»/«PM» lowercased differently again. Passing the locale is the whole
/// fix; the marker comes from the locale's own date symbols, not from a table
/// written here.
///
/// [localeCode] is the reader's language code. It is optional because two of
/// the four call sites are widgets deep in a build with no locale to hand,
/// and an English clock is a better failure than a crash — but every caller
/// that CAN pass it does.
///
/// Wrapped in [ltr] for the same reason `formatBytes` is (CLAUDE.md trap
/// #16): «7:36 AM» is a bidi-weak numeral followed by a marker, and inside an
/// Arabic or Urdu paragraph the two swap. The Urdu build showed the sunrise
/// tile as «AM 7:36» on emulator-5554. A LEFT-TO-RIGHT ISOLATE pins the whole
/// fragment as one left-to-right run without adding a visible character.
///
/// The locale's symbols must have been loaded by `initializeDateFormatting`
/// first — `main.dart` does that for every language the app speaks. Asking
/// `intl` for a locale it has not loaded throws, so an unknown code falls
/// back rather than taking the screen down with it.
String formatTime12h(String hhmm, [String? localeCode]) {
  if (hhmm == '--:--' || hhmm.isEmpty) return hhmm;
  try {
    final parts = hhmm.split(':');
    final now = DateTime.now();
    final dt = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return ltr(DateFormat('h:mm a', localeCode).format(dt));
  } catch (_) {
    // A locale whose symbols were never initialised throws here. Falling back
    // to the default locale keeps a clock on the screen; returning the raw
    // «18:21» would be worse than an English marker.
    try {
      return ltr(DateFormat('h:mm a').format(DateTime(
        2000,
        1,
        1,
        int.parse(hhmm.split(':')[0]),
        int.parse(hhmm.split(':')[1]),
      )));
    } catch (_) {
      return hhmm;
    }
  }
}
