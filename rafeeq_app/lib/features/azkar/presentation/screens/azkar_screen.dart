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
          final sections = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final s = sections[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(s.title),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AzkarSectionScreen(section: s),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TasbeehTab extends ConsumerStatefulWidget {
  const _TasbeehTab();

  @override
  ConsumerState<_TasbeehTab> createState() => _TasbeehTabState();
}

class _TasbeehTabState extends ConsumerState<_TasbeehTab> {
  int _count = 0;
  int _target = 33;

  void _tap() {
    setState(() => _count++);
    if (ref.read(azkarSettingsProvider).haptics) {
      HapticFeedback.lightImpact();
      if (_count % _target == 0) HapticFeedback.mediumImpact();
    }
  }

  void _reset() => setState(() => _count = 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text('azkar.target'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
          Wrap(
            spacing: 8,
            children: [33, 100, 1000].map((t) {
              return ChoiceChip(
                label: Text('$t'),
                selected: _target == t,
                onSelected: (_) => setState(() => _target = t),
              );
            }).toList(),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _tap,
                child: Container(
                  width: 220,
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    border: Border.all(color: AppColors.gold, width: 3),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_count',
                          style: const TextStyle(
                              fontSize: 56, fontWeight: FontWeight.bold)),
                      Text(
                        '${_count > 0 && _count % _target == 0 ? _target : _count % _target} / $_target',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: Text('azkar.reset'.tr()),
            ),
          ),
        ],
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
