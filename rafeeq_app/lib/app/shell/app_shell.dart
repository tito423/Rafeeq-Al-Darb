import '../../features/library/data/library_api_service.dart';
import 'dart:async';

import 'side_tabs.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/prayer_times.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/accordion.dart';
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
import '../../features/hifz/presentation/hifz_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/qibla/presentation/screens/qibla_screen.dart';
import '../../features/settings/data/focus_mode_provider.dart';
import '../../features/settings/data/reader_name_provider.dart';
import '../../features/settings/presentation/widgets/reader_name_sheet.dart';
import '../../features/quran/data/quran_fullscreen_provider.dart';
import '../../features/quran/presentation/screens/quran_screen.dart';
import '../../features/tutorial/data/tutorial_state.dart';
import '../../features/tutorial/presentation/widgets/tutorial_overlay.dart';
import '../../features/splash/data/splash_video_provider.dart';
import '../rafeeq_app.dart';
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
  final _tabsKey = GlobalKey();

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
      // A download notification that launched the app, or one tapped while
      // it runs. Wired from here rather than `main()` because both paths end
      // in a `Navigator.push`, and there is no navigator until the shell is
      // on screen. See `DownloadTapChannel` for why the plugin's own callback
      // cannot do this.
      unawaited(DownloadTapChannel.instance.start());
      // Books that ship in the APK are put in the library once, quietly -
      // after the first screen has settled, not while it is drawing.
      unawaited(
        Future<void>.delayed(
          const Duration(seconds: 8),
          LibraryApiService.instance.installBuiltinBooks,
        ),
      );
      // The one point both first-run and returning users pass through, so
      // this is where the startup grants are asked for. Delayed past the
      // route transition so the dialog lands on a settled screen rather than
      // on one that is still animating in; the service itself only ever asks
      // once per launch.
      //
      // THE TOUR WAITS FOR THEM. It used to go up first, and the three
      // system permission dialogs then landed on top of it - seen on
      // emulator-5554, the tour advancing from chapter 4 to chapter 10
      // behind the notification and audio prompts, narrating screens nobody
      // could look at. The owner asked for it «بعد الاسبلاش اسكرين
      // والاذونات», so it starts when the grants are actually finished,
      // not on a guessed delay.
      Future<void>.delayed(const Duration(milliseconds: 900), () async {
        await AlarmPermissionsService.instance.requestStartupGrants();
        if (!mounted) return;
        if (shouldAutoShowTutorial(ref)) {
          ref.read(tutorialRunningProvider.notifier).state = true;
          return;
        }
        // «التطبيق يسأل المستخدم عن اسمه المفضّل». Asked once, and only after
        // the tour has had its turn - a first run that opens on a form is a
        // first run people leave. Skipping is a real answer and is never
        // asked again.
        if (ref.read(readerNameProvider.notifier).shouldAsk) {
          await showReaderNameSheet(context);
        }
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
    // The splash intro's clock: it plays again only after the app has been
    // away `splashAwayThreshold`, so the moment of leaving is what counts.
    if (state != AppLifecycleState.detached) {
      markAppActiveNow(ref.read(sharedPrefsProvider));
    }
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

    // «وضع التركيز». The nav bar is not merely hidden - the index is
    // pinned, so a `requestedTabProvider` set by a pushed screen, or a
    // stale `_index` from before the mode was turned on, cannot land the
    // reader on another tab behind a missing bar. Read this early: the
    // stack's children depend on it (`AppTab.focusHifz`).
    final focus = ref.watch(focusModeProvider);

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
      // AppTab.focusHifz — not a destination, and built ONLY while focus
      // mode is on it. `IndexedStack` builds every child it is given, and
      // `HifzScreen` opens the Qur'an database and reads the hifz store the
      // moment it is built; nobody who is not in that mode should pay for
      // that on every launch.
      focus == FocusTarget.hifz ? HifzScreen() : const SizedBox.shrink(),
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
    // What the stack actually shows. Taking it from the focus target rather
    // than from `_index` closes the one-frame gap the post-frame pin below
    // would otherwise leave, and is the only way `FocusTarget.hifz` — a slot
    // with no bottom-nav button — reaches the screen at all.
    final shown = focus?.tab ?? _index;

    final fullScreen =
        ref.watch(quranFullScreenProvider) && shown == AppTab.quran;

    final tour = ref.watch(tutorialRunningProvider);
    // On a true first run the tour has the screen, so the name is asked when
    // the tour ends rather than never.
    ref.listen<bool>(tutorialRunningProvider, (was, isRunning) {
      if (was != true || isRunning) return;
      // The context is captured before the await, and re-checked through the
      // State's own `mounted` after it: `context` from a State that is still
      // mounted is the same element.
      // Read from the provider, which restored the flag at startup, so there
      // is no await between deciding and using `context`.
      if (ref.read(readerNameProvider.notifier).shouldAsk) {
        showReaderNameSheet(context);
      }
    });
    // `_index` follows a tab target so the bar and `activeTabProvider` agree
    // with what is on screen — but only for a target that IS a tab.
    // `FocusTarget.hifz` pins a stack slot past the last destination, and
    // `NavigationBar` asserts on a `selectedIndex` it has no button for, so
    // `_index` is deliberately left on a real tab there: the frame in which
    // focus is switched off must already be a valid one for the bar.
    if (focus != null && focus.isTab && _index != focus.tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(focus.tab);
      });
    }

    // The seven tabs, once, for the bottom bar upright and the rail sideways.
    const tabs = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home, 'nav.home'),
      (Icons.menu_book_outlined, Icons.menu_book, 'nav.quran'),
      (Icons.explore_outlined, Icons.explore, 'nav.prayer'),
      (Icons.auto_awesome_outlined, Icons.auto_awesome, 'nav.azkar'),
      (
        Icons.radio_button_checked_outlined,
        Icons.radio_button_checked,
        'nav.tasbeeh',
      ),
      (Icons.library_books_outlined, Icons.library_books, 'nav.library'),
      (Icons.menu, Icons.menu_open, 'nav.more'),
    ];
    // The GlobalKey is what makes turning the phone keep every tab's state:
    // sideways the stack moves from the Scaffold's body into a Row beside
    // `SideTabs`, and without it that move would build every tab afresh -
    // the mushaf page, every scroll position, an open card.
    final tabStack = KeyedSubtree(
      key: _tabsKey,
      child: KeyedSubtree(
        key: ValueKey<String>(localeCode),
        child: IndexedStack(index: shown, children: screens),
      ),
    );
    // SIDEWAYS, THE TABS GO TO THE SIDE. Measured on the owner's Xiaomi held
    // sideways (2026-09-26): the bottom bar took 290 of the screen's 1220 px,
    // leaving every tab a letterbox under a header card. A phone on its side
    // has width to spare and height to none, so the tabs stand at the
    // start edge (`SideTabs`) and every screen gets the full height. The IndexedStack
    // is the same one either way (`_tabsKey`).
    final sideways =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        !fullScreen &&
        focus == null;

    // P3‑44: real-device feedback — pressing the system back button/gesture
    // on any non-Home tab exited the app outright (Android's own default
    // for a root route with nothing beneath it in the Navigator stack).
    // Real apps with a bottom-nav shell almost universally treat "back" on
    // a non-Home tab as "go to Home" first, reserving an actual exit for
    // back-on-Home — that's what `canPop`/`onPopInvokedWithResult` do here,
    // rather than a literal AppBar arrow that wouldn't make sense on a
    // root bottom-nav screen.
    return PopScope(
      canPop: !tour && focus == null && _index == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // An open card on the tab in front takes this press: back closes it
        // first, and only the next press goes Home (core/widgets/accordion).
        if (accordionHandlesBack(context)) return;
        // In focus mode the back gesture IS the way out - the owner asked
        // for «جيستشر عادي او زر الخروج» and this is the gesture half. No
        // `maybePop` anywhere near it: that would hand the request back to
        // this very handler (trap #44).
        // The tour first: while it plays, back means "leave the tour".
        if (tour) {
          endTutorial(ref);
          return;
        }
        if (focus != null) {
          ref.read(focusModeProvider.notifier).leave();
          return;
        }
        setState(() => _index = AppTab.home);
        ref.read(activeTabProvider.notifier).state = AppTab.home;
      },
      // THE TOUR SITS OVER THE WHOLE SCAFFOLD, not inside its body.
      //
      // It used to be one layer of the body's Stack, and on the device that
      // showed: the tour's dim stopped at the top of the navigation bar, so
      // the bar stayed at full brightness and the spotlight that was supposed
      // to ring one tab could not be seen at all. Worse, the body's local
      // coordinates are not the window's, and the tour measures its targets
      // with `localToGlobal` - so every rectangle was offset by the bar's own
      // height. Wrapping the Scaffold puts the overlay in the same coordinate
      // space it measures in, and lets it light a navigation button.
      child: Stack(
        children: [
          Scaffold(
            // The Qur'an tab lays a whole mushaf page out against the body's
            // height; letting a keyboard shrink it re-laid the page on every frame
            // of the keyboard's slide — «لما بضغط على زر الانتقال الشاشة في الخلفية
            // بتمش أو بتعمل فليكر جامد جدا». Its dialogs float above the keyboard
            // on their own.
            resizeToAvoidBottomInset: shown != AppTab.quran,
            body: sideways
                ? Row(
                    children: [
                      SideTabs(
                        tabs: tabs,
                        selectedIndex: _index,
                        onSelect: _goTo,
                        selectedIcon: (icon) => _PopIcon(icon),
                      ),
                      const VerticalDivider(width: 1),
                      // The rail already stands clear of the notch; the screen
                      // beside it must not clear it AGAIN. Measured on the
                      // owner's Xiaomi (ROTATION_90, 2026-09-26): the home cards
                      // began 60 dp past the rail - 39 dp of that was the notch
                      // inset re-applied by the tab's own SafeArea.
                      Expanded(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeLeft:
                              Directionality.of(context).name == 'ltr',
                          removeRight:
                              Directionality.of(context).name == 'rtl',
                          child: tabStack,
                        ),
                      ),
                    ],
                  )
                : tabStack,
            // P3‑57: seven destinations is more than Material's bar is designed
            // for (the spec says three to five), so the longest translated label
            // wins or loses by a few pixels. On the owner's phone «Bibliothèque»
            // wrapped to two lines and had its last letter clipped by the bar's
            // fixed 68px height. Pinning the text scale stops a device font-size
            // setting from making that worse, and is the only part of this that a
            // user setting could otherwise break.
            bottomNavigationBar: fullScreen || sideways
                ? null
                : focus != null
                ? const _FocusModeBar()
                : MediaQuery.withNoTextScaling(
                    child: NavigationBarTheme(
                      // «اكتب اسماء الايقونات دايما تحت الايقونات اللي في البوتوم
                      // نافيجيشن» — every tab carries its name now, on every width.
                      //
                      // The width rule this replaces was not wrong about the problem,
                      // only about the fix: seven tiles on a narrow window leave each
                      // about 41 dp, and «المسبحة» broke into «المسبد / ة» on
                      // emulator-5554 at `wm density 600`. Hiding six of the seven
                      // labels was what his own phone got — the Honor measures
                      // 1224 px at density 520, which is 376.6 dp, four short of the
                      // 380 threshold.
                      //
                      // So the label shrinks to fit instead of disappearing.
                      // `nav_label_width_test` budgets each label against **56 dp per
                      // tile at 11 px**, the theme's size; scaling the size by the
                      // real tile's share of that 56 dp keeps every one of those
                      // budgets true at any width, which a fixed smaller size would
                      // not. Floored at 0.72 so it stays legible rather than chasing
                      // an absurd window.
                      data: NavigationBarThemeData(
                        labelTextStyle: WidgetStatePropertyAll(
                          (Theme.of(context).navigationBarTheme.labelTextStyle
                                      ?.resolve(<WidgetState>{}) ??
                                  const TextStyle(fontSize: 11))
                              .copyWith(
                                fontSize:
                                    11 *
                                    ((MediaQuery.sizeOf(context).width / 7) /
                                            56)
                                        .clamp(0.72, 1.0),
                              ),
                        ),
                      ),
                      child: NavigationBar(
                        selectedIndex: _index,
                        onDestinationSelected: _goTo,
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        // «اعملي أنيميشن جميل في شكل … أيقونات الشريط الرئيسي السفلي».
                        // The selected icon is built fresh whenever a tab becomes
                        // selected, so `_PopIcon` plays its entrance exactly then.
                        destinations: [
                          for (final (icon, selected, key) in tabs)
                            NavigationDestination(
                              icon: Icon(icon),
                              selectedIcon: _PopIcon(selected),
                              label: key.tr(),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (tour) TutorialOverlay(onGoToTab: _goTo),
        ],
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
            onTap: () => ref.read(focusModeProvider.notifier).leave(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: goldText(context),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'focus.exit'.tr(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: goldText(context),
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
