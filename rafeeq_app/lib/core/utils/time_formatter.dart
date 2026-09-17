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
/// Arabic writes «ص» and «م»; Spanish «a. m.»/«p. m.»; French, Portuguese and
/// Russian all write «AM»/«PM» in CLDR. Passing the locale is the whole fix;
/// the marker comes from the locale's own date symbols, not from a table
/// written here — with exactly one documented exception, [_markerOverrides].
///
/// CORRECTION. An earlier version of this comment said Urdu gets «AM»/«PM»
/// "in its own convention". It does not, in the version of `intl` this app
/// actually locks. Read from the package's own symbol table rather than
/// assumed:
///
///     intl 0.18.1   "ur"  AMPMS: const ['AM', 'PM']
///     intl 0.20.2   "ur"  AMPMS: const ['a', 'p']      <- what we resolve
///
/// CLDR's *narrow* day-period for Urdu has landed in the *abbreviated* slot
/// upstream, so an Urdu reader's clock renders «4:47 a» — a bare Latin letter
/// that means nothing in Urdu or in any other language. That is a defect in
/// the data, not in this app, but it reaches the owner's screen either way.
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
/// The one place a marker is not taken from `intl`.
///
/// Keyed by language code. The value is what `intl` ITSELF shipped for that
/// locale before the upstream regression described above — not something
/// invented here, and not a translation anyone guessed at.
///
/// Delete an entry the moment `intl` is right again. The test
/// `time_marker_locale_test` asserts no supported language renders a bare
/// single Latin letter, so a future `intl` that fixes `ur` makes this entry
/// redundant rather than wrong.
const Map<String, List<String>> _markerOverrides = {
  // intl 0.20.2 gives ['a', 'p']; intl 0.18.1 gave ['AM', 'PM'].
  'ur': ['AM', 'PM'],
};

/// Swaps a degenerate marker out of an already-formatted clock.
String _applyMarkerOverride(String formatted, String? localeCode) {
  if (localeCode == null) return formatted;
  final lang = localeCode.split(RegExp('[_-]')).first;
  final fix = _markerOverrides[lang];
  if (fix == null) return formatted;
  final symbols = DateFormat('h:mm a', localeCode).dateSymbols.AMPMS;
  var out = formatted;
  for (var i = 0; i < symbols.length && i < fix.length; i++) {
    // Replace the marker only as a trailing token, so a digit is never hit.
    if (out.endsWith(' ${symbols[i]}')) {
      out = '${out.substring(0, out.length - symbols[i].length)}${fix[i]}';
      break;
    }
  }
  return out;
}

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
    return ltr(_applyMarkerOverride(
        DateFormat('h:mm a', localeCode).format(dt), localeCode));
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
