/// The sheet the Home header's dates open: both calendars, and what happened
/// on this day.
///
/// «لما أضغط على التاريخ الهجري تجيب ما يوافقه في كارت جميل جدًا بصريًا مزخرف
/// إسلاميًا، ويعرض الأحداث التاريخية … وكذلك في التاريخ الميلادي».
///
/// Both halves of the date are one control: tapping either side opens this,
/// and this shows both. Splitting them into two different sheets would be two
/// screens saying almost the same thing.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/i18n/hijri_months.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../data/on_this_day_repository.dart';

Future<void> showOnThisDaySheet(BuildContext context, {int hijriOffset = 0}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OnThisDaySheet(hijriOffset: hijriOffset),
  );
}

class _OnThisDaySheet extends ConsumerWidget {
  final int hijriOffset;

  const _OnThisDaySheet({required this.hijriOffset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = context.locale.languageCode;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    HijriCalendar.setLocal(locale == 'ar' ? 'ar' : 'en');
    final h = HijriCalendar.fromDate(now.add(Duration(days: hijriOffset)));
    final hijri = '${localizeDigits('${h.hDay}', locale)} '
        '${hijriMonthName(h.hMonth)} '
        '${localizeDigits('${h.hYear}', locale)} '
        '${'hijri.suffix'.tr()}';
    final gregorian = DateFormat.yMMMMEEEEd(locale).format(now);

    final events = ref.watch(onThisDayProvider(locale));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          // The two dates on one ornamented panel: this IS the conversion the
          // owner asked for, so it is the thing the sheet opens on.
          IslamicPatternPanel(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Text(
                  hijri,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: locale == 'ar' ? 'AmiriQuran' : null,
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
                  gregorian,
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
          Row(
            children: [
              const Icon(Icons.history_edu_rounded,
                  size: 19, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'home.on_this_day'.tr(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          events.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _Note(text: 'home.on_this_day_none'.tr()),
            data: (data) {
              final rows = data.forDate(now);
              if (rows.isEmpty) {
                return _Note(text: 'home.on_this_day_none'.tr());
              }
              return Column(
                children: [
                  for (final e in rows) _EventRow(event: e, locale: locale),
                  const SizedBox(height: 14),
                  // CC BY-SA asks for attribution, and §1.2 asks for a link to
                  // every source. Same sentence does both.
                  InkWell(
                    onTap: () => openExternalLink(
                      'https://${locale == 'ar' ? 'ar' : 'en'}.wikipedia.org/'
                      'wiki/Special:Search?search='
                      '${Uri.encodeComponent(DateFormat.MMMMd(locale).format(now))}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'home.on_this_day_source'.tr(),
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
}

class _EventRow extends StatelessWidget {
  final HistoricalEvent event;
  final String locale;

  const _EventRow({required this.event, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The year in its own well, so the column of years reads down the
          // card and the eye can find a period without reading every line.
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              event.year == null
                  ? '—'
                  : localizeDigits('${event.year}', locale),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.65,
                color: scheme.onSurface,
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
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
