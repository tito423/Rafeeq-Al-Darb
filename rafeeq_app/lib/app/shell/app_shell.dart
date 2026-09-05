import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/prayer_times.dart';
import '../../core/services/adhan_alarm_service.dart';
import '../../core/services/prayer_status_notification.dart';
import '../../features/adhan/data/prayer_status_enabled_provider.dart';
import '../../features/adhan/presentation/adhan_navigation.dart';
import '../../features/azkar/presentation/screens/azkar_screen.dart';
import '../../features/azkar/presentation/screens/tasbeeh_screen.dart';
import '../../features/home/data/prayer_controller.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/quran/data/quran_fullscreen_provider.dart';
import '../../features/quran/presentation/screens/quran_screen.dart';
import 'tab_request_provider.dart';

/// Main navigation shell — bottom navigation bar across the app's primary
/// sections (Home, Quran, Prayer, Azkar, Tasbeeh, Library). "Library" holds
/// the Hadith hub and the books catalog. P3‑4 round 2: Tasbeeh used to be a
/// sub-tab inside Azkar; the owner's real reference screenshots of the old
/// app's own bottom nav show it as its own separate tab, so it was split
/// out (`AppTab`/`tab_request_provider.dart` tracks the indices).
///
/// P3‑41: Settings is deliberately **not** one of these tabs any more —
/// real-device feedback asked directly for it to come off the bottom nav
/// and live as a button on Home instead (`_SettingsButton` in
/// `home_screen.dart`, a plain `Navigator.push` to the same
/// `SettingsScreen` that used to be tab 6). Six tabs read more cleanly
/// than seven, and Settings is opened rarely enough that it doesn't need
/// a permanent slot in the bar every other screen fights for space in.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPrayerStatus();
      _checkActiveAdhan();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPrayerStatus();
      _checkActiveAdhan();
    }
  }

  /// P3‑43 #2: fallback for a full-screen Adhan alert that should have
  /// auto-navigated via its notification Intent but didn't — see
  /// `AdhanAlarmService.findActiveAdhanPayload`'s own doc for why this
  /// exists as a second, OS/OEM-agnostic path rather than trusting that
  /// Intent journey alone. `openAdhanFromPayload` itself no-ops if the
  /// alert screen is already showing, so this is safe to call on every
  /// resume, not just a suspicious one.
  Future<void> _checkActiveAdhan() async {
    final payload = await AdhanAlarmService.instance.findActiveAdhanPayload();
    if (payload != null) openAdhanFromPayload(payload);
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
        () => ref.read(requestedTabProvider.notifier).state = null,
      );
    });

    final screens = [
      HomeScreen(onNavigate: (t) => _goTo(t, tab: t)),
      const QuranScreen(),
      const QiblaScreen(),
      const AzkarScreen(),
      const TasbeehScreen(),
      const LibraryScreen(),
    ];

    // P3‑43 #6: a genuinely full-screen mushaf reader needs this bar gone
    // too, not just the Quran tab's own AppBar — see
    // `quran_fullscreen_provider.dart` for why this is a shared provider
    // rather than a direct call, `QuranScreen` isn't a parent of this bar.
    // Gated on `_index == AppTab.quran` too, not the flag alone: `IndexedStack`
    // keeps every tab's `State` alive at once, so `QuranScreen`'s restored
    // `_pageFillScreen` (persisted across app restarts) stays live even
    // while a completely different tab is the one actually on screen — a
    // real bug caught live, not by inspection: a fullscreen toggle left on
    // from an earlier session made the bottom nav vanish on Home too.
    final fullScreen =
        ref.watch(quranFullScreenProvider) && _index == AppTab.quran;

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: fullScreen
          ? null
          : NavigationBar(
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
              ],
            ),
    );
  }
}
