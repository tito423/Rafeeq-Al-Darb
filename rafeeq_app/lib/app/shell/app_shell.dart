import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/prayer_times.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/alarm_permissions_service.dart';
import '../../core/services/ayah_audio_service.dart';
import '../../core/services/download_manager.dart';
import '../../features/downloads/data/download_tap_channel.dart';
import '../../core/services/download_notifications.dart';
import '../../features/quran_audio/data/quran_audio_library.dart';
import '../../core/services/mushaf_page_service.dart';
import '../../features/quran/data/mushaf_edition.dart';
import '../../core/services/prayer_status_notification.dart';
import '../../features/adhan/data/prayer_status_enabled_provider.dart';
import '../../features/azkar/presentation/screens/azkar_screen.dart';
import '../../features/azkar/presentation/screens/tasbeeh_screen.dart';
import '../../features/home/data/prayer_controller.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/settings/data/focus_mode_provider.dart';
import '../../features/quran/data/quran_fullscreen_provider.dart';
import '../../features/quran/presentation/screens/quran_screen.dart';
import '../../features/tutorial/data/tutorial_state.dart';
import '../../features/tutorial/presentation/screens/tutorial_screen.dart';
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

/// A nav icon that springs in when its tab becomes the selected one: it grows
/// from a little smaller with an elastic overshoot and a quarter-swing.
class _PopIcon extends StatelessWidget {
  final IconData icon;
  const _PopIcon(this.icon);

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.rotate(
          angle: (1 - t) * -0.5,
          child: Transform.scale(scale: 0.55 + 0.45 * t, child: child),
        ),
        child: Icon(icon),
      );
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;

  void _goTo(int index, {int? tab}) {
    setState(() => _index = index);
    // P3‑47: keep the active-tab signal in sync so kept-alive tabs (e.g. the
    // Qibla compass) can pause their sensor work when they aren't showing.
    ref.read(activeTabProvider.notifier).state = index;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPrayerStatus();
      // The guided tour, when it is due — the first time this build runs, or
      // on every launch if the owner turned that on in «المزيد». Opened from
      // here rather than from the splash so it lands on top of a settled
      // Home screen and a swipe-back leaves the reader inside the app, not
      // on a dead route. `AlarmPermissionsService` asks 900 ms from now, so
      // the tour goes up first and the permission dialog lands on it, which
      // is the same order a first run has always had.
      // A download notification that launched the app, or one tapped while
      // it runs. Wired from here rather than `main()` because both paths end
      // in a `Navigator.push`, and there is no navigator until the shell is
      // on screen. See `DownloadTapChannel` for why the plugin's own callback
      // cannot do this.
      unawaited(DownloadTapChannel.instance.start());
      if (mounted && shouldAutoShowTutorial(ref)) {
        TutorialScreen.open(context);
      }
      // The one point both first-run and returning users pass through, so
      // this is where the startup grants are asked for. Delayed past the
      // route transition so the dialog lands on a settled screen rather than
      // on one that is still animating in; the service itself only ever asks
      // once per launch.
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        AlarmPermissionsService.instance.requestStartupGrants();
      });
      // A process that has just started is downloading nothing, so any
      // download notification in the shade belongs to one Android killed —
      // and a mushaf download he asked for is picked up where it stopped.
      unawaited(DownloadNotifications.instance.clearStale());
      Future<void>.delayed(const Duration(seconds: 5), () async {
        if (!mounted) return;
        try {
          final editions = await ref.read(mushafEditionsProvider.future);
          await MushafPageService.instance.resumeWantedDownloads(editions);
        } catch (_) {}
        // The per-ayah recitation files are gone from the app since 3.17.0;
        // free what earlier builds left, once. Then pick up any whole-surah
        // download that was on its way.
        unawaited(AyahAudioService.instance.purgeLegacyAyahFiles());
        // «احذف الكليبات» — the adhan background clips are gone from the
        // app, so a phone that downloaded some is holding bytes nothing
        // would ever offer to free again. Once per install.
        unawaited(DownloadManager.instance.purgeAdhanVideos());
        unawaited(QuranAudioLibrary.instance.ensureReady());
      });
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
      _recheckLocationIfDenied();
    }
  }

  /// P3‑43 #10: "after permission is actually granted, the app doesn't
  /// pick it up automatically" — true for the path where the user grants
  /// location from the OS Settings app directly rather than through the
  /// new in-app button (which already re-fetches immediately as part of
  /// its own tap, no separate recheck needed there). Only re-fetches when
  /// the last known state genuinely was "denied", so this doesn't refetch
  /// location on every ordinary app resume.
  void _recheckLocationIfDenied() {
    final result = ref.read(prayerControllerProvider).valueOrNull;
    if (result?.locationDenied == true) {
      ref.read(prayerControllerProvider.notifier).refresh();
    }
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
      ref.read(activeTabProvider.notifier).state = tab;
      Future.microtask(
        () => ref.read(requestedTabProvider.notifier).state = null,
      );
    });

    // P3‑57: the OTHER half of the P3‑45 fix below, and the half that was
    // missing — dropping `const` let a tab re-`build()` when `AppShell`
    // rebuilds, but nothing made `AppShell` rebuild on a language change in
    // the first place. Its `build()` read no locale, so switching language
    // left every already-built tab exactly as it was: the owner's real-device
    // screenshots show the Library tab's chrome in FRENCH under an English
    // UI, and the Adhkar grid's tiles in ENGLISH under a French one, with the
    // strings sitting correctly in their own locale files all along.
    //
    // Reading `context.locale` here registers the dependency that makes the
    // rebuild happen. `KeyedSubtree` then forces it all the way down rather
    // than relying on no `const` widget existing anywhere below: a changed key
    // rebuilds the subtree outright, where an identical `const` child deeper
    // in a tab would otherwise still be skipped by the same
    // `identical(old, new)` shortcut described below. The cost is that a tab's
    // scroll position resets when the language changes, which is the right
    // trade for a screen that is being re-rendered in another language anyway.
    final localeCode = context.locale.languageCode;

    // P3‑45: real-device feedback found whole tabs (Library's "Hadith" /
    // "Available books" chrome, seen live after switching locale mid-
    // session) frozen in whatever language was active on the app's first
    // frame. `IndexedStack` keeps every tab's `Element`/`State` alive at
    // once by design (that's the whole point — Home already isn't `const`
    // here because its `onNavigate` closure captures `this`), but a
    // `const` screen with no constructor arguments gets canonicalized to
    // one shared Dart object; passing that *same identical* instance back
    // on every `AppShell.build()` makes Flutter's own element-update path
    // skip calling `build()` on it entirely (an `identical(old, new)`
    // widget is treated as "nothing changed"), so a screen that only
    // depends on `.tr()` — which reads easy_localization's global current
    // locale, not a `BuildContext` dependency — never gets a chance to
    // re-render with the new language. Dropping `const` from the other
    // five doesn't lose any of their state (same runtimeType + no key
    // still reuses the same `State` object, `initState` does not re-run)
    // — it just means `build()` actually runs again on the rare
    // `AppShell` rebuilds (tab switch, locale, theme), which is exactly
    // what every one of these screens needs to stay in sync.
    final screens = [
      HomeScreen(onNavigate: (t) => _goTo(t, tab: t)),
      QuranScreen(),
      QiblaScreen(),
      AzkarScreen(),
      TasbeehScreen(),
      LibraryScreen(),
      MoreScreen(),
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

    // «وضع التركيز». The nav bar is not merely hidden - the index is
    // pinned, so a `requestedTabProvider` set by a pushed screen, or a
    // stale `_index` from before the mode was turned on, cannot land the
    // reader on another tab behind a missing bar.
    final focus = ref.watch(focusModeProvider);
    if (focus && _index != AppTab.quran) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(AppTab.quran);
      });
    }

    // P3‑44: real-device feedback — pressing the system back button/gesture
    // on any non-Home tab exited the app outright (Android's own default
    // for a root route with nothing beneath it in the Navigator stack).
    // Real apps with a bottom-nav shell almost universally treat "back" on
    // a non-Home tab as "go to Home" first, reserving an actual exit for
    // back-on-Home — that's what `canPop`/`onPopInvokedWithResult` do here,
    // rather than a literal AppBar arrow that wouldn't make sense on a
    // root bottom-nav screen.
    return PopScope(
      canPop: !focus && _index == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // In focus mode the back gesture IS the way out - the owner asked
        // for «جيستشر عادي او زر الخروج» and this is the gesture half. No
        // `maybePop` anywhere near it: that would hand the request back to
        // this very handler (trap #44).
        if (focus) {
          ref.read(focusModeProvider.notifier).set(false);
          return;
        }
        setState(() => _index = AppTab.home);
        ref.read(activeTabProvider.notifier).state = AppTab.home;
      },
      child: Scaffold(
        // The Qur'an tab lays a whole mushaf page out against the body's
        // height; letting a keyboard shrink it re-laid the page on every frame
        // of the keyboard's slide — «لما بضغط على زر الانتقال الشاشة في الخلفية
        // بتمش أو بتعمل فليكر جامد جدا». Its dialogs float above the keyboard
        // on their own.
        resizeToAvoidBottomInset: _index != AppTab.quran,
        body: KeyedSubtree(
          key: ValueKey<String>(localeCode),
          child: IndexedStack(index: _index, children: screens),
        ),
      // P3‑57: seven destinations is more than Material's bar is designed
      // for (the spec says three to five), so the longest translated label
      // wins or loses by a few pixels. On the owner's phone «Bibliothèque»
      // wrapped to two lines and had its last letter clipped by the bar's
      // fixed 68px height. Pinning the text scale stops a device font-size
      // setting from making that worse, and is the only part of this that a
      // user setting could otherwise break.
      bottomNavigationBar: fullScreen
          ? null
          : focus
              ? const _FocusModeBar()
              : MediaQuery.withNoTextScaling(
              child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _goTo,
              // «اعملي أنيميشن جميل في شكل … أيقونات الشريط الرئيسي السفلي».
              // The selected icon is built fresh whenever a tab becomes
              // selected, so `_PopIcon` plays its entrance exactly then.
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const _PopIcon(Icons.home),
                  label: 'nav.home'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const _PopIcon(Icons.menu_book),
                  label: 'nav.quran'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const _PopIcon(Icons.explore),
                  label: 'nav.prayer'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const _PopIcon(Icons.auto_awesome),
                  label: 'nav.azkar'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.radio_button_checked_outlined),
                  selectedIcon: const _PopIcon(Icons.radio_button_checked),
                  label: 'nav.tasbeeh'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.library_books_outlined),
                  selectedIcon: const _PopIcon(Icons.library_books),
                  label: 'nav.library'.tr(),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu),
                  selectedIcon: const _PopIcon(Icons.menu_open),
                  label: 'nav.more'.tr(),
                ),
              ],
            ),
          ),
      ),
    );
  }
}


/// The only way out of «وضع التركيز» that is visible on screen.
///
/// It sits exactly where the navigation bar was, so the reader's thumb finds
/// it where it expects something to be, and it says what it does rather than
/// being a bare icon - a mode that traps you is only acceptable when the exit
/// is unmistakable. The back gesture does the same thing; see `AppShell`'s
/// `PopScope`.
class _FocusModeBar extends ConsumerWidget {
  const _FocusModeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ref.read(focusModeProvider.notifier).set(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 20, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'focus.exit'.tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
