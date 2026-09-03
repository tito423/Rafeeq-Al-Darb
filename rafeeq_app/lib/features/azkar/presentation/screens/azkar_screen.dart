import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../data/azkar_settings_provider.dart';
import 'azkar_section_screen.dart';

/// Azkar tab — real sections from Hisn al-Muslim (134 real sections, no
/// duplicates within a section — verified against the bundled DB) plus a
/// free digital tasbeeh counter.
class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('nav.azkar'.tr()),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            tabs: [
              Tab(text: 'azkar.tab_azkar'.tr()),
              Tab(text: 'azkar.tab_tasbeeh'.tr()),
            ],
          ),
          actions: const [_SettingsButton()],
        ),
        body: const TabBarView(children: [_SectionsTab(), _TasbeehTab()]),
      ),
    );
  }
}

/// P3‑11: real-keyword → icon mapping for the grid redesign
/// (`design_refs/ref_azkar_hub.jpg`) — deliberately **not** a fixed 6-card
/// taxonomy (أذكار الصباح / أذكار المساء / التسبيح والتحميد / أدعية
/// قرآنية / … as separate cards), because Hisn al-Muslim's real 134
/// sections don't actually split that way: there is exactly **one**
/// combined "أذكار الصباح والمساء" section (§29), no standalone "أدعية
/// قرآنية" section, and no "التسبيح والتحميد" dhikr-text section (§132/133
/// are *about* the virtue of tasbih, not the dhikr texts themselves — that
/// content lives in the المسبحة tab instead). Inventing separate cards for
/// categories the data doesn't actually have would be exactly the kind of
/// placeholder structure rule 1 forbids. Instead: every one of the real 133
/// sections (⁠المقدمة filtered) gets its own card in a 2-column grid — the
/// reference's *visual language* (icon + title card, not a bare list row),
/// applied honestly to the real content.
IconData _azkarIcon(String title) {
  const map = <String, IconData>{
    'الصباح': Icons.wb_sunny_outlined,
    'المساء': Icons.nights_stay_outlined,
    'النوم': Icons.bedtime_outlined,
    'الاستيقاظ': Icons.alarm,
    'الاستغفار': Icons.refresh,
    'السفر': Icons.flight_outlined,
    'الطعام': Icons.restaurant_outlined,
    'المريض': Icons.healing_outlined,
    'الميت': Icons.spa_outlined,
    'المسجد': Icons.mosque_outlined,
    'الوضوء': Icons.water_drop_outlined,
    'الصلاة': Icons.self_improvement,
    'الأذان': Icons.campaign_outlined,
    'الهم': Icons.sentiment_dissatisfied_outlined,
    'الكرب': Icons.sentiment_very_dissatisfied_outlined,
    'الزواج': Icons.favorite_outline,
    'المولود': Icons.child_care_outlined,
    'المطر': Icons.water_outlined,
    'الرعد': Icons.bolt_outlined,
    'الحج': Icons.location_on_outlined,
    'العطاس': Icons.sick_outlined,
    'الغضب': Icons.mood_bad_outlined,
    'السلام': Icons.waving_hand_outlined,
  };
  for (final entry in map.entries) {
    if (title.contains(entry.key)) return entry.value;
  }
  return Icons.auto_awesome_outlined;
}

class _SectionsTab extends ConsumerWidget {
  const _SectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(sciencesRepositoryProvider);
    return repoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(sciencesRepositoryProvider)),
      data: (repo) => FutureBuilder<List<AzkarSection>>(
        future: repo.azkarSections(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // P3‑11: "المقدمة" (section 1) is al-Qahtani's own author's preface
          // to Hisn al-Muslim — real front-matter, but not a dhikr a user
          // would ever tap into from a list of dhikr categories. Filtered
          // out here, not at the DB/repository layer, so the underlying
          // "134 real sections" count and azkar_items(1) both stay exactly
          // as bundled — this is a display-only decision.
          final sections =
              snapshot.data!.where((s) => s.title != 'المقدمة').toList();
          final scheme = Theme.of(context).colorScheme;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('azkar.hub_subtitle'.tr(),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('azkar.choose_type'.tr(),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final s = sections[i];
                      return _AzkarSectionCard(
                        section: s,
                        icon: _azkarIcon(s.title),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AzkarSectionScreen(section: s),
                          ),
                        ),
                      );
                    },
                    childCount: sections.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AzkarSectionCard extends StatelessWidget {
  final AzkarSection section;
  final IconData icon;
  final VoidCallback onTap;
  const _AzkarSectionCard(
      {required this.section, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.gold, size: 26),
              Text(
                section.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the four standard tasbeeh phrases + the pill/accent colour the
/// owner's reference image (`design_refs/ref_tasbeeh.jpg`) used for it.
class _DhikrOption {
  final String textKey;
  final Color color;
  const _DhikrOption(this.textKey, this.color);
}

const _dhikrOptions = [
  _DhikrOption('azkar.tasbeeh_subhanallah', Color(0xFF2E9FE8)), // blue
  _DhikrOption('azkar.tasbeeh_alhamdulillah', Color(0xFF2E9D6F)), // green
  _DhikrOption('azkar.tasbeeh_allahuakbar', Color(0xFF6C5FBC)), // purple
  _DhikrOption('azkar.tasbeeh_lailahaillallah', Color(0xFFC9A227)), // gold
];

/// P3‑12 redesign, matching `design_refs/ref_tasbeeh.jpg`: pick one of the
/// four standard tadhkir phrases (a colour-coded pill each), tap the glowing
/// circle to count it, target is the classical 33 per round — reaching it
/// advances "عدد الجولات" (rounds) and rolls the count back to 0 rather than
/// climbing to some arbitrary target the old 33/100/1000 chips picked. A
/// "المجموع" chip tracks the running total across every dhikr and round
/// this session; the trash icon clears everything back to zero.
class _TasbeehTab extends ConsumerStatefulWidget {
  const _TasbeehTab();

  @override
  ConsumerState<_TasbeehTab> createState() => _TasbeehTabState();
}

class _TasbeehTabState extends ConsumerState<_TasbeehTab> {
  static const _target = 33;
  int _dhikrIndex = 0;
  int _count = 0;
  int _rounds = 0;
  int _total = 0;

  void _tap() {
    final haptics = ref.read(azkarSettingsProvider).haptics;
    setState(() {
      _count++;
      _total++;
      if (_count >= _target) {
        _count = 0;
        _rounds++;
      }
    });
    if (haptics) {
      HapticFeedback.lightImpact();
      if (_count == 0) HapticFeedback.mediumImpact(); // a round just closed
    }
  }

  void _selectDhikr(int i) {
    if (i == _dhikrIndex) return;
    setState(() {
      _dhikrIndex = i;
      _count = 0;
      _rounds = 0;
    });
  }

  void _clearAll() {
    setState(() {
      _count = 0;
      _rounds = 0;
      _total = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _dhikrOptions[_dhikrIndex];
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Row(
              children: [
                Chip(
                  label: Text('azkar.tasbeeh_total'.tr(args: ['$_total'])),
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                const Spacer(),
                Text('azkar.tab_tasbeeh'.tr(),
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'common.reset_all'.tr(),
                  onPressed: _total == 0 && _rounds == 0 && _count == 0
                      ? null
                      : _clearAll,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _dhikrOptions.length; i++)
                  _DhikrPill(
                    option: _dhikrOptions[i],
                    selected: i == _dhikrIndex,
                    onTap: () => _selectDhikr(i),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _tap,
                child: Container(
                  width: 250,
                  height: 250,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(
                        selected.color.withValues(alpha: 0.10),
                        scheme.surfaceContainerHighest),
                    border: Border.all(
                        color: selected.color.withValues(alpha: 0.55),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: selected.color.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected.textKey.tr(),
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: selected.color,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('$_count',
                          style: const TextStyle(
                              fontSize: 56, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('azkar.tap_to_count'.tr(),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text('azkar.rounds_count'.tr(args: ['$_rounds']),
              style: TextStyle(color: scheme.onSurfaceVariant)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: IconButton.filledTonal(
              tooltip: 'azkar.reset'.tr(),
              onPressed: () => setState(() {
                _count = 0;
                _rounds = 0;
              }),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }
}

class _DhikrPill extends StatelessWidget {
  final _DhikrOption option;
  final bool selected;
  final VoidCallback onTap;
  const _DhikrPill(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: option.color,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          option.textKey.tr(),
          style: const TextStyle(
            fontFamily: 'AmiriQuran',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends ConsumerWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.tune),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _AzkarSettingsSheet(),
      ),
    );
  }
}

class _AzkarSettingsSheet extends ConsumerWidget {
  const _AzkarSettingsSheet();

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay? current,
    void Function(TimeOfDay?) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(azkarSettingsProvider);
    final notifier = ref.read(azkarSettingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text('azkar.vibration'.tr()),
              value: settings.haptics,
              onChanged: notifier.setHaptics,
            ),
            const Divider(),
            Text('azkar.reminders'.tr(),
                style: Theme.of(context).textTheme.titleSmall),
            ListTile(
              title: Text('azkar.morning_reminder'.tr()),
              subtitle: Text(settings.morningReminder == null
                  ? 'azkar.reminder_off'.tr()
                  : settings.morningReminder!.format(context)),
              trailing: Wrap(children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _pickTime(context, ref, settings.morningReminder,
                      notifier.setMorningReminder),
                ),
                if (settings.morningReminder != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => notifier.setMorningReminder(null),
                  ),
              ]),
            ),
            ListTile(
              title: Text('azkar.evening_reminder'.tr()),
              subtitle: Text(settings.eveningReminder == null
                  ? 'azkar.reminder_off'.tr()
                  : settings.eveningReminder!.format(context)),
              trailing: Wrap(children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _pickTime(context, ref, settings.eveningReminder,
                      notifier.setEveningReminder),
                ),
                if (settings.eveningReminder != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => notifier.setEveningReminder(null),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
