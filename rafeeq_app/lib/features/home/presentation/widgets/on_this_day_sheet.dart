/// The two sheets the Home header's dates open — one per calendar.
///
/// «انا عايز لما اضغط ع التاريخ الهجري يعرض تاريخ اليوم واهم الاحداث اللي حصلت
/// فيه قبل كدة بشكل جميل وبالنسبة للتاريخ الميلادي عايز لما اضغط عليه يعرض
/// تاريخ اليوم الميلادي ويعرض اهم الاحداث … خاصة اللي يخص الاسلام والمسلمين».
///
/// They used to be ONE sheet: both halves of the header opened it and it showed
/// both dates over Wikimedia's `onthisday` feed. The trouble is that the feed is
/// keyed by the **Gregorian** month and day, so tapping «١٧ رمضان» and tapping
/// «8 March» gave the same list — the Hijri date had nothing of its own to say.
///
/// Now each date opens its own sheet:
///
///   * the Hijri one leads on the Hijri date and lists events dated by Hijri
///     year, from Arabic Wikipedia's per-Hijri-day pages;
///   * the Gregorian one leads on the Gregorian date and puts what concerns
///     Islam and the Muslims first, then everything else.
///
/// Both still show the other calendar's date underneath, because that
/// conversion is the first thing the header was ever asked for.
library;

// `intl`, which easy_localization re-exports, has a `TextDirection` of its own
// (`TextDirection.RTL`), and it shadows the widget one in this file. The
// paragraph direction below wants Flutter's, so it is named explicitly.
import '../../../../core/services/official_hijri.dart';
import '../../../../core/services/official_hijri_provider.dart';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/i18n/hijri_months.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../data/hijri_landmarks.dart';
import '../../data/islamic_event_keywords.dart';
import '../../data/on_this_day_repository.dart';

/// Which calendar a sheet is about.
enum DayCalendar { hijri, gregorian }

Future<void> showHijriDaySheet(BuildContext context, {int hijriOffset = 0}) =>
    _show(context, DayCalendar.hijri, hijriOffset);

Future<void> showGregorianDaySheet(BuildContext context,
        {int hijriOffset = 0}) =>
    _show(context, DayCalendar.gregorian, hijriOffset);

/// Kept so older call sites (and anything that just wants "the day sheet")
/// still compile; the Gregorian sheet is the one that covers both dates.
Future<void> showOnThisDaySheet(BuildContext context, {int hijriOffset = 0}) =>
    showGregorianDaySheet(context, hijriOffset: hijriOffset);

Future<void> _show(BuildContext context, DayCalendar calendar, int offset) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DaySheet(calendar: calendar, hijriOffset: offset),
  );
}

class _DaySheet extends ConsumerWidget {
  final DayCalendar calendar;
  final int hijriOffset;

  const _DaySheet({required this.calendar, required this.hijriOffset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = context.locale.languageCode;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    HijriCalendar.setLocal(locale == 'ar' ? 'ar' : 'en');
    ref.watch(officialHijriProvider);
    final (hYear, hMonth, hDay) =
        OfficialHijri.dateOf(now, offsetDays: hijriOffset);
    final hijri = '${localizeDigits('$hDay', locale)} '
        '${hijriMonthName(hMonth)} '
        '${localizeDigits('$hYear', locale)} '
        '${'hijri.suffix'.tr()}';
    final gregorian = DateFormat.yMMMMEEEEd(locale).format(now);

    final isHijri = calendar == DayCalendar.hijri;
    final events = isHijri
        ? ref.watch(onThisDayHijriProvider)
        : ref.watch(onThisDayProvider(locale));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          // The date this sheet is ABOUT leads, in the big face; the other
          // calendar stays underneath because the conversion is still the
          // first thing the header was asked for.
          IslamicPatternPanel(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Text(
                  isHijri ? hijri : gregorian,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily:
                        isHijri && locale == 'ar' ? 'AmiriQuran' : null,
                    fontSize: 20,
                    height: 1.7,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 90,
                  height: 1,
                  color: AppColors.gold.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 8),
                Text(
                  isHijri ? gregorian : hijri,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            icon: Icons.history_edu_rounded,
            text: (isHijri
                    ? 'home.on_this_day_hijri'
                    : 'home.on_this_day_gregorian')
                .tr(),
          ),
          const SizedBox(height: 10),
          events.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _Note(text: 'home.on_this_day_none'.tr()),
            data: (data) {
              final rows = isHijri
                  ? data.forMonthDay(hMonth, hDay)
                  : data.forDate(now);
              // What a non-Arabic reader is actually shown on the Hijri sheet:
              // the landmark events of this Hijri day, written in their own
              // language (`hijri_landmarks.dart`).
              final landmarks = isHijri && locale != 'ar'
                  ? hijriLandmarksFor(hMonth, hDay)
                  : const <HistoricalEvent>[];
              if (rows.isEmpty && landmarks.isEmpty) {
                return _Note(text: 'home.on_this_day_none'.tr());
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // «مش ينفع تعرض احداث بالعربي واللغه المختارة انجليزي».
                  //
                  // The day-by-day Hijri record exists only in Arabic, and a
                  // reader who chose French is not served by a wall of Arabic
                  // with an apology over it — which is exactly what this sheet
                  // did when it shipped. So the Arabic rows are NOT rendered
                  // outside Arabic: what a non-Arabic reader gets is the
                  // curated landmarks, translated, and a line saying where the
                  // rest of the record lives.
                  if (isHijri && locale != 'ar') ...[
                    ..._rows(landmarks, locale, hijriYears: true),
                    _Note(text: 'home.on_this_day_hijri_ar_only'.tr()),
                  ] else if (isHijri)
                    ..._rows(rows, data.lang, hijriYears: true)
                  else
                    ..._grouped(context, rows, data.lang),
                  const SizedBox(height: 14),
                  // CC BY-SA asks for attribution, and §1.2 asks for a link to
                  // every source. The same sentence does both.
                  InkWell(
                    onTap: () => openExternalLink(
                      isHijri
                          ? 'https://ar.wikipedia.org/wiki/'
                              '${Uri.encodeComponent('$hDay ${hijriMonthNameAr(hMonth)}')}'
                          : 'https://${locale == 'ar' ? 'ar' : 'en'}.wikipedia.org/'
                              'wiki/Special:Search?search='
                              '${Uri.encodeComponent(DateFormat.MMMMd(locale).format(now))}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        (isHijri
                                ? 'home.on_this_day_source_ar_wiki'
                                : 'home.on_this_day_source')
                            .tr(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(List<HistoricalEvent> rows, String lang,
      {bool hijriYears = false}) {
    // Wikipedia's own page order is not chronological — «٦ ربيع الآخر»
    // opens 365, 541, 1398, 1397, 1327 — and a column of years the eye cannot
    // run down is not «بشكل جميل». Sorting is a presentation choice over
    // sourced rows: nothing is added, removed or rewritten.
    final sorted = [...rows]..sort((a, b) {
        if (a.year == null) return b.year == null ? 0 : 1;
        if (b.year == null) return -1;
        return a.year!.compareTo(b.year!);
      });
    return [
      for (final e in sorted)
        _EventRow(event: e, hijriYear: hijriYears, arabicText: lang == 'ar'),
    ];
  }

  /// The Gregorian sheet, in two blocks: what concerns Islam and the Muslims,
  /// then the rest. Nothing is hidden — «خاصة اللي يخص الاسلام والمسلمين» is
  /// about what comes first, not about what is allowed through.
  List<Widget> _grouped(
      BuildContext context, List<HistoricalEvent> rows, String lang) {
    final islamic = <HistoricalEvent>[];
    final rest = <HistoricalEvent>[];
    for (final e in rows) {
      (concernsIslam(e.text, lang) ? islamic : rest).add(e);
    }
    if (islamic.isEmpty || rest.isEmpty) {
      return _rows(rows, lang);
    }
    return [
      _SubTitle(text: 'home.on_this_day_islamic'.tr()),
      const SizedBox(height: 8),
      ..._rows(islamic, lang),
      const SizedBox(height: 6),
      _SubTitle(text: 'home.on_this_day_world'.tr()),
      const SizedBox(height: 8),
      ..._rows(rest, lang),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: goldText(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          Container(width: 3, height: 15, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final HistoricalEvent event;

  /// Hijri years get «هـ» after them, and a year before the Hijra is stored
  /// negative and printed «ق.هـ» — which is how the source writes it.
  final bool hijriYear;

  /// The SENTENCE is Arabic even when the app is not. The Hijri list has only
  /// an Arabic source, and on the English UI its rows were laid out
  /// left-to-right: every full stop jumped to the head of the line and the
  /// wrapping broke mid-phrase. Seen on the emulator. The row keeps the app's
  /// direction; the paragraph gets its own.
  final bool arabicText;

  const _EventRow({
    required this.event,
    this.hijriYear = false,
    this.arabicText = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final y = event.year;
    final label = y == null
        ? '—'
        : hijriYear
            ? '${localizeDigits('${y.abs()}', locale)}'
                '${y < 0 ? ' ${'home.hijri_before_hijra'.tr()}' : 'hijri.suffix'.tr()}'
            : localizeDigits('$y', locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The year in its own well, so the column of years reads down the
          // card and the eye can find a period without reading every line.
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: goldText(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Directionality(
              textDirection:
                  arabicText ? ui.TextDirection.rtl : Directionality.of(context),
              child: Text(
                event.text,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.65,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1.7,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
