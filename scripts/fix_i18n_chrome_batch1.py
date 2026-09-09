# -*- coding: utf-8 -*-
"""The Dart half of driving `i18n_audit.py`'s `chrome` bucket to zero.

Applied as a script rather than by hand because every one of these edits is an
exact string swap and a script can assert that the string it is replacing is
present exactly as many times as expected - a hand edit cannot.

Three of these were NOT on the audit's list, and are the reason it was worth
reading the files rather than trusting the count:

  * `adhan_entry.dart` - the Adhan alert boots its own miniature Flutter app
    with its own `supportedLocales` list, and that list had SIX locales:
    **Urdu was missing**. An Urdu user's full-screen adhan alert fell back to
    Arabic while the rest of the app was in Urdu. Both lists now come from
    `core/i18n/supported_locales.dart`.
  * `adhan_scheduler.dart` - `_prayerLabelsAr` is a hardcoded Arabic table of
    the five prayer names, and it is what the alert screen renders through
    `prayer.azan_of`. The audit never saw it: a `'key': 'value'` map line is
    skipped as a lookup table. On a French UI the alert read "Adhan de الظهر".
  * `azan_player_screen.dart` - even localised, a label baked in at schedule
    time goes stale when the language changes before the alarm fires, so the
    name is now resolved from the (stable) prayer key at display time.

The Arabic strings here are why this is a Python file and not a shell heredoc
(CLAUDE.md trap #11).
"""

import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "rafeeq_app", "lib")

_edits = 0


def sub(rel, old, new, count=1):
    """Replace `old` with `new` in lib/<rel>, asserting the exact hit count."""
    global _edits
    path = os.path.join(LIB, rel.replace("/", os.sep))
    src = io.open(path, encoding="utf-8").read()
    n = src.count(old)
    if n != count:
        raise SystemExit("%s: expected %d occurrence(s) of %r, found %d"
                         % (rel, count, old[:70], n))
    io.open(path, "w", encoding="utf-8", newline="").write(
        src.replace(old, new))
    _edits += count


def write(rel, body):
    path = os.path.join(LIB, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    io.open(path, "w", encoding="utf-8", newline="").write(body)


# ── 1. One list of locales, not two ─────────────────────────────────────────

write("core/i18n/supported_locales.dart", '''import 'package:flutter/widgets.dart';

/// The seven locales the app ships, in one place.
///
/// There were two hand-maintained lists: `main.dart`'s and the one in
/// `adhan_entry.dart`, which boots the full-screen Adhan alert as its own
/// miniature Flutter app. They had drifted - the alert's list held **six**
/// locales, missing Urdu, so an Urdu user's adhan alert fell back to Arabic
/// while every other screen was in Urdu. Both read from here now, and
/// `test/supported_locales_test.dart` asserts this list matches the
/// translation files actually shipped in `assets/translations`.
const kSupportedLocales = <Locale>[
  Locale('ar'),
  Locale('en'),
  Locale('es'),
  Locale('ru'),
  Locale('pt'),
  Locale('fr'),
  // Urdu: RTL like Arabic, so the whole shell mirrors the same way the
  // Arabic locale already does - nothing special-cased for it.
  Locale('ur'),
];
''')

sub("main.dart",
    """      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('es'),
        Locale('ru'),
        Locale('pt'),
        Locale('fr'),
        // Urdu: RTL like Arabic, so the whole shell mirrors the same way the
        // Arabic locale already does — nothing special-cased for it.
        Locale('ur'),
      ],""",
    "      supportedLocales: kSupportedLocales,")
sub("main.dart",
    "import 'core/services/alarm_permissions_service.dart';",
    "import 'core/i18n/supported_locales.dart';\n"
    "import 'core/services/alarm_permissions_service.dart';")

sub("adhan_entry.dart",
    """      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
        Locale('es'),
        Locale('ru'),
        Locale('pt'),
        Locale('fr'),
      ],""",
    "      supportedLocales: kSupportedLocales,")
sub("adhan_entry.dart",
    "import 'core/models/adhan_mode.dart';",
    "import 'core/i18n/supported_locales.dart';\nimport 'core/models/adhan_mode.dart';")

# The fallback spec, used when the Activity hands over a malformed route. Its
# label is a generic "the prayer" - it must not be Arabic on a Russian phone.
sub("adhan_entry.dart",
    """  return const AdhanSpec(
    prayerKey: 'dhuhr',
    prayerLabel: 'الصلاة',""",
    """  return AdhanSpec(
    prayerKey: 'dhuhr',
    prayerLabel: 'prayer.adhan'.tr(),""")


# ── 2. The prayer name the adhan alert shows ────────────────────────────────

sub("features/adhan/data/adhan_scheduler.dart",
    """const _prayerLabelsAr = {
  'fajr': 'الفجر',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

""",
    "")
sub("features/adhan/data/adhan_scheduler.dart",
    "    prayerLabel: _prayerLabelsAr[prayerKey] ?? prayerKey,",
    "    // Localised here because this label is what the *native* notification\n"
    "    // prints; the Flutter alert screen resolves the name from `prayerKey`\n"
    "    // at display time instead, so a language change before the alarm\n"
    "    // fires cannot leave it stale.\n"
    "    prayerLabel: 'prayer.$prayerKey'.tr(),")
sub("features/adhan/data/adhan_scheduler.dart",
    "import '../../../core/models/adhan_mode.dart';",
    "import 'package:easy_localization/easy_localization.dart';\n\n"
    "import '../../../core/models/adhan_mode.dart';")

sub("features/adhan/presentation/screens/azan_player_screen.dart",
    "'prayer.azan_of'.tr(args: [widget.spec.prayerLabel]),",
    "'prayer.azan_of'.tr(args: [_prayerName(widget.spec)]),")
sub("features/adhan/presentation/screens/azan_player_screen.dart",
    "import '../../data/azan_subtitle.dart';",
    """import '../../data/azan_subtitle.dart';

/// The prayer's name in the app's *current* language.
///
/// [AdhanSpec.prayerLabel] is baked in when the alarm is scheduled — it used
/// to be a hardcoded Arabic table, so this line read "Adhan de الظهر" on a
/// French UI. Even localised at schedule time it goes stale the moment the
/// language changes before the alarm fires, and the key does not, so the name
/// is resolved here. The baked label stays as the fallback for a spec whose
/// key this build does not know.
String _prayerName(AdhanSpec spec) {
  const known = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};
  return known.contains(spec.prayerKey)
      ? 'prayer.${spec.prayerKey}'.tr()
      : spec.prayerLabel;
}""")


# ── 3. «رفيق الدرب» is the app's name, and the app has one ──────────────────

sub("core/services/ayah_audio_service.dart",
    "        album: 'رفيق الدرب',",
    "        album: 'app.name'.tr(),", count=2)
sub("core/services/ayah_audio_service.dart",
    "    final displayName = title ?? 'سورة $surah';",
    "    final displayName = title ?? '${'quran.surah'.tr()} $surah';")
sub("core/services/ayah_audio_service.dart",
    "import 'package:background_downloader/background_downloader.dart' as bd;",
    "import 'package:background_downloader/background_downloader.dart' as bd;\n"
    "import 'package:easy_localization/easy_localization.dart';")

sub("features/quran/presentation/widgets/ayah_share_card.dart",
    "text: 'رفيق الدرب — $reference'",
    "text: '${'app.name'.tr()} — $reference'")
sub("features/quran/presentation/widgets/ayah_share_card.dart",
    "            'رفيق الدرب',",
    "            'app.name'.tr(),")
sub("features/quran/presentation/widgets/ayah_share_card.dart",
    "import 'package:flutter/material.dart';",
    "// `hide TextDirection`: easy_localization re-exports package:intl, whose\n"
    "// TextDirection collides with dart:ui's - and this file uses dart:ui's.\n"
    "import 'package:easy_localization/easy_localization.dart' hide TextDirection;\n"
    "import 'package:flutter/material.dart';")


# ── 4. The Hijri era suffix and the month name on the adjustments preview ───

sub("features/adhan/presentation/screens/prayer_adjustments_screen.dart",
    "    return '${date.hDay} ${date.longMonthName} ${date.hYear} هـ';",
    "    return '${date.hDay} ${hijriMonthName(date.hMonth)} ${date.hYear}'\n"
    "        '${'hijri.suffix'.tr()}';")
sub("features/adhan/presentation/screens/prayer_adjustments_screen.dart",
    "import '../../../../core/theme/app_colors.dart';",
    "import '../../../../core/i18n/hijri_months.dart';\n"
    "import '../../../../core/theme/app_colors.dart';")


# ── 5. «س» and «د» on the Home countdown ────────────────────────────────────

sub("features/home/presentation/screens/home_screen.dart",
    "    if (h > 0) return '$label: $hس $mد';\n"
    "    return '$label: $mد';",
    "    final hu = 'home.hours_short'.tr();\n"
    "    final mu = 'home.minutes_short'.tr();\n"
    "    if (h > 0) return '$label: $h$hu $m$mu';\n"
    "    return '$label: $m$mu';")


# ── 6. The juz label: a nav sheet is chrome, a mushaf's page header is not ──

# In the navigation sheet the juz list sits beside «الآيات» and the surah's
# page number, both of which already follow the interface language, and it is
# a navigation control - not part of any printed page. Plain digits, to match
# its neighbours `${s.id}` and `${s.ayahsCount}`.
sub("features/quran/presentation/widgets/mushaf_nav_sheets.dart",
    "                      'الجزء ${_arabicNumber(juz)}',",
    "                      '${'quran.juz'.tr()} $juz',")
sub("features/quran/presentation/widgets/mushaf_nav_sheets.dart",
    "                    trailing: Text('p.${juzStartPages[juz] ?? 1}'),",
    "                    trailing:\n"
    "                        Text('${'quran.page'.tr()} ${juzStartPages[juz] ?? 1}'),")
sub("features/quran/presentation/widgets/mushaf_nav_sheets.dart",
    "                      '  •  p.${startPages[s.id] ?? 1}',",
    "                      '  •  ${'quran.page'.tr()} ${startPages[s.id] ?? 1}',")
# `_arabicNumber` was only ever used by that juz label.
sub("features/quran/presentation/widgets/mushaf_nav_sheets.dart",
    """
String _arabicNumber(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}""",
    "")

# On the mushaf page itself the badge overlays a scanned page, and the page's
# own printed numbering is Arabic-Indic by the owner's decision - so the digits
# stay, and only the word follows the interface language.
sub("features/quran/presentation/screens/quran_screen.dart",
    "                      _HeaderBadge(text: 'الجزء ${_arabicNumber(juzNumber!)}'),",
    "                      _HeaderBadge(\n"
    "                          text: '${'quran.juz'.tr()} "
    "${_arabicNumber(juzNumber!)}'),")


# ── 7. An Arabic source name reads right-to-left, whatever the UI is ────────

sub("features/settings/presentation/screens/sources_screen.dart",
    """                      Text(
                        source.host,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),""",
    """                      // A source's identity is its own name: `sunnah.com`
                      // is Latin, and «مسند أحمد — ط الرسالة» is Arabic and
                      // carries an em dash and an editor's name. On a French
                      // UI that line inherits an LTR paragraph and its parts
                      // migrate to the wrong end. The name itself is never
                      // translated - a credit that renames its source stops
                      // being a credit (CLAUDE.md §1.2) - so what is fixed
                      // here is direction, not words.
                      if (_hasArabic.hasMatch(source.host))
                        ArabicText(
                          source.host,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          source.host,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),""")
sub("features/settings/presentation/screens/sources_screen.dart",
    "import '../../../../core/theme/app_colors.dart';",
    "import '../../../../core/theme/app_colors.dart';\n"
    "import '../../../../core/widgets/arabic_text.dart';")
sub("features/settings/presentation/screens/sources_screen.dart",
    "/// (section title key, sources) — grouped by what part of the app they feed.",
    "final _hasArabic = RegExp(r'[\\u0600-\\u06FF]');\n\n"
    "/// (section title key, sources) — grouped by what part of the app they feed.")


def main():
    print("applied %d edits" % _edits)


if __name__ == "__main__":
    main()
