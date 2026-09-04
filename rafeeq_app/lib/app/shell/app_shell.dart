import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/prayer_times.dart';
import '../../core/services/prayer_status_notification.dart';
import '../../features/adhan/data/prayer_status_enabled_provider.dart';
import '../../features/azkar/presentation/screens/azkar_screen.dart';
import '../../features/azkar/presentation/screens/tasbeeh_screen.dart';
import '../../features/home/data/prayer_controller.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/quran/presentation/screens/quran_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'tab_request_provider.dart';

/// Main navigation shell — bottom navigation bar across the app's primary
/// sections (Home, Quran, Prayer, Azkar, Tasbeeh, Library, Settings).
/// "Library" holds the Hadith hub and the books catalog. P3‑4 round 2:
/// Tasbeeh used to be a sub-tab inside Azkar; the owner's real reference
/// screenshots of the old app's own bottom nav show it as its own separate
/// tab, so it was split out (`AppTab`/`tab_request_provider.dart` tracks
/// the indices).
///
/// Also the single place the persistent "next prayer" status card (P2‑6) is
/// kept in sync: whenever the prayer times resolve, the opt-in toggle flips,
/// or the app is resumed, [_syncPrayerStatus] re-posts (or clears) the card.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;

  void _goTo(int index, {int? tab}) {
    setState(() => _index = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPrayerStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncPrayerStatus();
  }

  /// Push the current prayer times + toggle state to the status-bar card.
  void _syncPrayerStatus() {
    final enabled = ref.read(prayerStatusEnabledProvider);
    final result = ref.read(prayerControllerProvider).valueOrNull;
    PrayerStatusNotification.instance.refresh(
      times: result?.times ?? PrayerTimes.empty(),
      localeCode: context.locale.languageCode,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync when the real times arrive or the toggle changes.
    ref.listen(prayerControllerProvider, (_, _) => _syncPrayerStatus());
    ref.listen(prayerStatusEnabledProvider, (_, _) => _syncPrayerStatus());
    // A screen pushed on top of the shell (e.g. KhatmaScreen) asking to
    // switch tabs — see tab_request_provider.dart for why this exists.
    ref.listen<int?>(requestedTabProvider, (_, tab) {
      if (tab == null) return;
      setState(() => _index = tab);
      Future.microtask(
          () => ref.read(requestedTabProvider.notifier).state = null);
    });

    final screens = [
      HomeScreen(onNavigate: (t) => _goTo(t, tab: t)),
      const QuranScreen(),
      const QiblaScreen(),
      const AzkarScreen(),
      const TasbeehScreen(),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'nav.home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: 'nav.quran'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: 'nav.prayer'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: 'nav.azkar'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.all_inclusive_outlined),
            selectedIcon: const Icon(Icons.all_inclusive),
            label: 'nav.tasbeeh'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            selectedIcon: const Icon(Icons.library_books),
            label: 'nav.library'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: 'nav.settings'.tr(),
          ),
        ],
      ),
    );
  }
}
