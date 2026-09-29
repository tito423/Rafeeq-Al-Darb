import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/hijri_months.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../data/islamic_occasions.dart';

/// The big card behind a tap on the weekday name: the Islamic occasions still
/// to come in this Hijri year, each with its Hijri and Gregorian date and how
/// far away it is. See [islamicOccasions] for what is listed and where the
/// dates come from.
Future<void> showIslamicOccasionsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _OccasionsSheet(),
    );

class _OccasionsSheet extends ConsumerWidget {
  const _OccasionsSheet();

  /// «بعد ٣ أيام» - Arabic has four number forms; the others take one or two.
  String _inDays(int n, String locale) {
    final String form;
    if (locale == 'ar') {
      form = n == 1
          ? 'one'
          : n == 2
              ? 'two'
              : n <= 10
                  ? 'few'
                  : 'many';
    } else {
      form = n == 1 ? 'one' : 'many';
    }
    return 'occasions.in_days_$form'
        .tr(args: [localizeDigits('$n', locale)]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final result = ref.watch(islamicOccasionsProvider);
    final today = DateTime.now();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          IslamicPatternPanel(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Text(
                  'occasions.title'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: locale == 'ar' ? 'AmiriQuran' : null,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
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
                  result.maybeWhen(
                    data: (r) => 'occasions.subtitle'.tr(args: [
                      '${localizeDigits('${r.hijriYear}', locale)}'
                          '${'hijri.suffix'.tr()}',
                    ]),
                    orElse: () => '',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          result.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('errors.generic'.tr(), textAlign: TextAlign.center),
            ),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < r.upcoming.length; i++)
                  _OccasionTile(
                    item: r.upcoming[i],
                    left: r.upcoming[i].daysFrom(today),
                    locale: locale,
                    inDays: _inDays,
                    highlight: i == 0,
                  ),
                const SizedBox(height: 8),
                Text(
                  (r.fromNetwork ? 'occasions.source_online' : 'occasions.source_offline')
                      .tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OccasionTile extends StatelessWidget {
  final OccasionDate item;
  final int left;
  final String locale;
  final String Function(int, String) inDays;
  final bool highlight;
  const _OccasionTile({
    required this.item,
    required this.left,
    required this.locale,
    required this.inDays,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = item.occasion;
    final hijri = '${localizeDigits('${o.day}', locale)} '
        '${hijriMonthName(o.month)} '
        '${localizeDigits('${item.hijriYear}', locale)}'
        '${'hijri.suffix'.tr()}';
    final gregorian =
        DateFormat.yMMMMEEEEd(context.locale.toString()).format(item.gregorian);
    const gold = AppColors.gold;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? gold.withValues(alpha: 0.85)
              : scheme.outlineVariant.withValues(alpha: 0.6),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'occasions.${o.key}'.tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(hijri,
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w600)),
                Text(gregorian,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: highlight ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              left == 0 ? 'occasions.today'.tr() : inDays(left, locale),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
