import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/digits.dart';
import '../../../core/widgets/readable_insets.dart';
import '../data/journey_store.dart';
import 'journey_details.dart';

/// «رحلتي»: level, points, the streak of active days, and badges - every one
/// earned by acts the app counted (see [JourneyStore]). Kept on the phone.
class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  static IconData _icon(String kind) => switch (kind) {
    'dhikr' => Icons.auto_awesome_rounded,
    'tasbeeh' => Icons.radio_button_checked_rounded,
    'streak' => Icons.local_fire_department_rounded,
    'game' => Icons.extension_rounded,
    'surah' => Icons.menu_book_rounded,
    _ => Icons.workspace_premium_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    String n(int v) => localizeDigits('$v', lang);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('journey.title'.tr())),
      body: ValueListenableBuilder<int>(
        valueListenable: JourneyStore.instance.changes,
        builder: (context, _, _) => FutureBuilder<JourneySnapshot>(
          future: JourneyStore.instance.read(),
          builder: (context, snap) {
            final j = snap.data;
            if (j == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final span = j.pointsForNextLevel - j.pointsForThisLevel;
            final progress = span <= 0
                ? 0.0
                : (j.points - j.pointsForThisLevel) / span;
            return ListView(
              padding: readableInsets(
                context,
                const EdgeInsets.fromLTRB(16, 8, 16, 32),
              ),
              children: [
                _Tap(
                  radius: 28,
                  onTap: () => showPointsSheet(context, j),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8854D0), Color(0xFF3B2A7A)],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFFFD166),
                          size: 56,
                        ),
                        Text(
                          'journey.level'.tr(args: [n(j.level)]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 10,
                              color: const Color(0xFFFFD166),
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'journey.points'.tr(
                            args: [n(j.points), n(j.pointsForNextLevel)],
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.touch_app_rounded,
                              size: 16,
                              color: Colors.white60,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'journey.tap_more'.tr(),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFEE5253),
                        value: j.streak,
                        label: 'journey.streak'.tr(),
                        onTap: () => showDaysSheet(context, j),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFF2E86DE),
                        value: j.counts['surah'] ?? 0,
                        label: 'journey.surahs'.tr(),
                        onTap: () => showSurahsSheet(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFF10AC84),
                        value: j.counts['dhikr'] ?? 0,
                        label: 'journey.dhikr'.tr(),
                        onTap: () => showCountSheet(
                          context,
                          kind: 'dhikr',
                          count: j.counts['dhikr'] ?? 0,
                          icon: Icons.auto_awesome_rounded,
                          color: const Color(0xFF10AC84),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        icon: Icons.extension_rounded,
                        color: const Color(0xFFF79F1F),
                        value: j.counts['game'] ?? 0,
                        label: 'journey.game'.tr(),
                        onTap: () => showCountSheet(
                          context,
                          kind: 'game',
                          count: j.counts['game'] ?? 0,
                          icon: Icons.extension_rounded,
                          color: const Color(0xFFF79F1F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'journey.badges'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                  children: [
                    for (var i = 0; i < journeyBadges.length; i++)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 300 + i * 70),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) =>
                            Transform.scale(scale: t, child: child),
                        child: _Tap(
                          radius: 20,
                          onTap: () => showBadgeDialog(
                            context,
                            journeyBadges[i],
                            j,
                            _icon(journeyBadges[i].kind),
                          ),
                          child: _Badge(
                            icon: _icon(journeyBadges[i].kind),
                            title: 'journey.badge_${journeyBadges[i].id}'.tr(),
                            earned: j.earned(journeyBadges[i]),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'journey.note'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final VoidCallback onTap;
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _Tap(
    radius: 20,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          // Counts up from 0 when the screen opens.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              localizeDigits('${v.round()}', context.locale.languageCode),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
        ],
      ),
    ),
  );
}

/// A press that shows: a ripple, and a small dip while held.
class _Tap extends StatefulWidget {
  final double radius;
  final VoidCallback onTap;
  final Widget child;
  const _Tap({required this.radius, required this.onTap, required this.child});

  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _down ? 0.95 : 1,
    duration: const Duration(milliseconds: 120),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(widget.radius),
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _down = v),
        child: widget.child,
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool earned;
  const _Badge({required this.icon, required this.title, required this.earned});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: earned
            ? const Color(0xFFFFD166).withValues(alpha: 0.2)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(
          color: earned ? const Color(0xFFE0A800) : scheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            earned ? icon : Icons.lock_outline_rounded,
            size: 34,
            color: earned ? const Color(0xFFE0A800) : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: earned ? null : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
