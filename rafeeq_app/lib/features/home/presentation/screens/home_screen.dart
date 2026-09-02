import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../new_muslim/presentation/screens/new_muslim_guide_screen.dart';
import '../../data/prayer_controller.dart';

const _prayerOrder = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
const _prayerLabelKeys = {
  'fajr': 'prayer.fajr',
  'sunrise': 'prayer.sunrise',
  'dhuhr': 'prayer.dhuhr',
  'asr': 'prayer.asr',
  'maghrib': 'prayer.maghrib',
  'isha': 'prayer.isha',
};

/// Home tab — real prayer times (once location is granted) + quick access.
class HomeScreen extends ConsumerStatefulWidget {
  /// [onNavigate] is the shell tab index (1=quran, 2=azkar, 3=hadith, 4=settings).
  final void Function(int tab) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(prayerControllerProvider.notifier).refresh());
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'home.greeting_morning'.tr();
    if (hour >= 12 && hour < 18) return 'home.greeting_evening'.tr();
    return 'home.greeting_night'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final prayerState = ref.watch(prayerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('app.name'.tr()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(prayerControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              Text(
                _greeting,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.primary,
                  fontFamily: 'AmiriQuran',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'app.tagline'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _PrayerCard(state: prayerState),
              const SizedBox(height: 28),
              Text(
                'home.quick_access'.tr(),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _QuickCard(
                    icon: Icons.menu_book,
                    label: 'home.mushaf'.tr(),
                    onTap: () => widget.onNavigate(1),
                  ),
                  _QuickCard(
                    icon: Icons.auto_awesome,
                    label: 'home.tasbeeh'.tr(),
                    onTap: () => widget.onNavigate(2),
                  ),
                  _QuickCard(
                    icon: Icons.library_books,
                    label: 'new_muslim.title'.tr(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NewMuslimGuideScreen(),
                      ),
                    ),
                  ),
                  _QuickCard(
                    icon: Icons.settings,
                    label: 'nav.settings'.tr(),
                    onTap: () => widget.onNavigate(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final AsyncValue<PrayerTimesResult> state;
  const _PrayerCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _MessageCard(
        icon: Icons.error_outline,
        message: 'errors.generic'.tr(),
      ),
      data: (result) {
        if (result.locationDenied) {
          return _MessageCard(
            icon: Icons.location_off_outlined,
            message: 'home.location_needed'.tr(),
          );
        }
        if (result.times.isEmpty) {
          return _MessageCard(
            icon: Icons.wifi_off,
            message: 'errors.offline'.tr(),
          );
        }
        return _PrayerTimesTable(times: result.times);
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimesTable extends StatelessWidget {
  final PrayerTimes times;
  const _PrayerTimesTable({required this.times});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = PrayerTimesService().nextPrayer(times, DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (next != null) ...[
              Text('home.next_prayer'.tr(),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${_prayerLabelKeys[next.$1]!.tr()} • ${times.byName(next.$1)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_remaining(next), style: TextStyle(color: scheme.onSurfaceVariant)),
              const Divider(height: 28),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final key in _prayerOrder)
                  Expanded(
                    child: Column(
                      children: [
                        Text(_prayerLabelKeys[key]!.tr(),
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          times.byName(key),
                          style: TextStyle(
                            fontWeight: next?.$1 == key ? FontWeight.bold : FontWeight.normal,
                            color: next?.$1 == key ? scheme.primary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (times.hijriDate.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(times.hijriDate,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  String _remaining((String, DateTime) next) {
    final diff = next.$2.difference(DateTime.now());
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final label = 'home.remaining'.tr();
    if (h > 0) return '$label: $hس $mد';
    return '$label: $mد';
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
