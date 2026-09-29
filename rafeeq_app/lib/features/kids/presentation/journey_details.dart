import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/db/quran_repository.dart';
import '../../../core/utils/arabic_normalize.dart' show surahNamePlain;
import '../../../core/utils/byte_formatter.dart' show ratio;
import '../../../core/utils/digits.dart';
import '../data/journey_store.dart';
import 'ayah_game_screen.dart';
import 'kids_corner_screen.dart';

/// What opens when something on «رحلتي» is tapped (owner, 2026-09-30: «كل
/// حاجة هنا ثابتة … أي حاجة بضغط عليها ثابتة … اخترع حاجة من عندك»). Every
/// number is the reader's own, from [JourneySnapshot]; nothing is decoration.

String _n(BuildContext c, int v) => localizeDigits('$v', c.locale.languageCode);

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

Widget _title(String t, IconData icon, Color c) => Row(
  children: [
    Icon(icon, color: c, size: 28),
    const SizedBox(width: 10),
    Expanded(
      child: Text(
        t,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
    ),
  ],
);

/// How the points are made, and the ladder of levels.
Future<void> showPointsSheet(BuildContext context, JourneySnapshot j) {
  const kinds = [
    ('dhikr', Icons.spa_rounded, Color(0xFF10AC84)),
    ('tasbeeh', Icons.radio_button_checked_rounded, Color(0xFF0ABDE3)),
    ('game', Icons.extension_rounded, Color(0xFFF79F1F)),
    ('surah', Icons.menu_book_rounded, Color(0xFF2E86DE)),
  ];
  final scheme = Theme.of(context).colorScheme;
  return _sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'journey.how_title'.tr(),
          Icons.emoji_events_rounded,
          const Color(0xFFE0A800),
        ),
        const SizedBox(height: 12),
        for (final (kind, icon, color) in kinds)
          Card(
            child: ListTile(
              leading: Icon(icon, color: color),
              title: Text('journey.kind_$kind'.tr()),
              subtitle: Text(
                'journey.row_points'.tr(
                  args: [
                    // One argument, kept in order under RTL (trap #16).
                    ratio(
                      _n(context, j.counts[kind] ?? 0),
                      _n(context, JourneyStore.weights[kind]!),
                      separator: ' × ',
                    ),
                  ],
                ),
              ),
              trailing: Text(
                _n(
                  context,
                  (j.counts[kind] ?? 0) * JourneyStore.weights[kind]!,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'journey.levels'.tr(),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (var lv = 1; lv <= j.level + 2; lv++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: lv == j.level
                  ? const Color(0xFF8854D0).withValues(alpha: 0.22)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: lv == j.level
                    ? const Color(0xFF8854D0)
                    : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  lv < j.level
                      ? Icons.check_circle_rounded
                      : lv == j.level
                      ? Icons.flag_rounded
                      : Icons.lock_outline_rounded,
                  color: lv <= j.level
                      ? const Color(0xFF8854D0)
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'journey.level_row'.tr(
                      args: [_n(context, lv), _n(context, 50 * lv * (lv - 1))],
                    ),
                  ),
                ),
                if (lv == j.level)
                  Text(
                    'journey.you_are_here'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF8854D0),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The last 28 days, lit where the reader did something.
Future<void> showDaysSheet(BuildContext context, JourneySnapshot j) {
  final scheme = Theme.of(context).colorScheme;
  final today = DateTime(j.today.year, j.today.month, j.today.day);
  final days = [
    for (var i = 27; i >= 0; i--) today.subtract(Duration(days: i)),
  ];
  return _sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'journey.days_title'.tr(),
          Icons.local_fire_department_rounded,
          const Color(0xFFEE5253),
        ),
        const SizedBox(height: 6),
        Text('journey.current_streak'.tr(args: [_n(context, j.streak)])),
        Text(
          'journey.best_streak'.tr(args: [_n(context, j.bestStreak)]),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var i = 0; i < days.length; i++)
              _DayDot(
                day: days[i].day,
                on: j.activeDays.contains(JourneyStore.dayKey(days[i])),
                isToday: i == days.length - 1,
                delay: i,
              ),
          ],
        ),
      ],
    ),
  );
}

class _DayDot extends StatelessWidget {
  final int day;
  final bool on;
  final bool isToday;
  final int delay;
  const _DayDot({
    required this.day,
    required this.on,
    required this.isToday,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + delay * 25),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on
              ? const Color(0xFFEE5253)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: isToday
              ? Border.all(color: const Color(0xFFFFD166), width: 2.5)
              : null,
        ),
        child: on
            ? const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 18,
              )
            : Text(
                _n(context, day),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}

/// The surahs marked as memorised, by name.
Future<void> showSurahsSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final repo = await container.read(quranRepositoryProvider.future);
  final all = await repo.surahs();
  final done = (await JourneyStore.instance.memorized()).toList()..sort();
  if (!context.mounted) return;
  final ar =
      context.locale.languageCode == 'ar' ||
      context.locale.languageCode == 'ur';
  return _sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'journey.memorized_title'.tr(),
          Icons.menu_book_rounded,
          const Color(0xFF2E86DE),
        ),
        const SizedBox(height: 12),
        if (done.isEmpty)
          Text('journey.memorized_none'.tr())
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in done)
                Chip(
                  avatar: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFE0A800),
                    size: 18,
                  ),
                  label: Text(
                    ar
                        ? surahNamePlain(all[id - 1].nameAr)
                        : all[id - 1].nameEn,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const KidsCornerScreen()),
            );
          },
          icon: const Icon(Icons.stairs_rounded),
          label: Text('journey.go_path'.tr()),
        ),
      ],
    ),
  );
}

/// A count and the way to add to it.
Future<void> showCountSheet(
  BuildContext context, {
  required String kind,
  required int count,
  required IconData icon,
  required Color color,
}) {
  final next = journeyBadges
      .where((b) => b.kind == kind && b.target > count)
      .firstOrNull;
  return _sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('journey.kind_$kind'.tr(), icon, color),
        const SizedBox(height: 10),
        Text(
          _n(context, count),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 6),
          Text(
            'journey.next_badge'.tr(
              args: [
                'journey.badge_${next.id}'.tr(),
                _n(context, next.target - count),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: count / next.target,
              minHeight: 8,
              color: color,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () {
            Navigator.of(context).pop();
            if (kind == 'game') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AyahGameScreen()),
              );
            } else {
              Navigator.of(context).popUntil((r) => r.isFirst);
              ProviderScope.containerOf(
                context,
              ).read(requestedTabProvider.notifier).state = AppTab.azkar;
            }
          },
          icon: Icon(icon, color: Colors.white),
          label: Text('journey.go_$kind'.tr()),
        ),
      ],
    ),
  );
}

/// One badge, large, with what it asks for and how far the reader is.
Future<void> showBadgeDialog(
  BuildContext context,
  JourneyBadge b,
  JourneySnapshot j,
  IconData icon,
) {
  final earned = j.earned(b);
  final have = switch (b.kind) {
    'streak' => j.bestStreak,
    'level' => j.level,
    final k => j.counts[k] ?? 0,
  };
  const gold = Color(0xFFE0A800);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: earned
                    ? const RadialGradient(
                        colors: [Color(0xFFFFE08A), Color(0xFFE0A800)],
                      )
                    : null,
                color: earned ? null : Colors.grey.withValues(alpha: 0.2),
                boxShadow: earned
                    ? [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.5),
                          blurRadius: 24,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                earned ? icon : Icons.lock_outline_rounded,
                size: 56,
                color: earned ? Colors.white : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'journey.badge_${b.id}'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'journey.need_${b.kind}'.tr(args: [_n(context, b.target)]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (earned)
            Text(
              'journey.badge_earned'.tr(),
              style: const TextStyle(
                color: gold,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (have / b.target).clamp(0.0, 1.0),
                minHeight: 8,
                color: gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'journey.badge_progress'.tr(
                args: [_n(context, have), _n(context, b.target)],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('journey.close'.tr()),
        ),
      ],
    ),
  );
}
