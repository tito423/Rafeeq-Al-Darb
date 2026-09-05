import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `AppShell`'s bottom-nav tab indices, named — P3‑16 (inserting the new
/// "الصلاة" tab between Quran and Azkar) silently broke a hardcoded `= 3`
/// for Library elsewhere in the codebase (`downloads_screen.dart`) that
/// nothing caught until it was traced by hand; every screen that jumps to
/// a specific tab should use these constants instead of a bare int, so the
/// next tab insertion is a compile-time-visible one-line change here
/// rather than a silent runtime misnavigation. P3‑4 round 2 inserted
/// `tasbeeh` the same safe way, right after `azkar`.
abstract final class AppTab {
  static const home = 0;
  static const quran = 1;
  static const prayer = 2;
  static const azkar = 3;
  static const tasbeeh = 4;
  static const library = 5;
  // P3‑41: Settings is no longer a bottom-nav tab at all (see AppShell's
  // own doc) — reached via a button on Home instead, a real
  // `Navigator.push`, so there's no tab index for it any more.
}

/// Cross-route "switch the bottom-nav tab to N" seam.
///
/// `HomeScreen`'s own cards can call `HomeNavigate.of(context)` (an
/// `InheritedWidget` scoped to `HomeScreen`'s subtree) because they're built
/// inside it. A screen reached via `Navigator.push` — like `KhatmaScreen`,
/// sitting in the `Navigator`'s `Overlay` above `AppShell`, not inside
/// `HomeScreen`'s widget tree — is not a descendant of that
/// `InheritedWidget`, so `HomeNavigate.of(context)` there is always null.
/// (P3‑6: this was exactly why "افتح المصحف" inside the full khatma manager
/// silently did nothing but pop back to Home — it set
/// `quranJumpRequestProvider` correctly, but nothing ever switched the
/// visible tab away from Home, so the reader "opened" off-screen.)
///
/// This is that seam instead, mirroring `quranJumpRequestProvider`'s
/// set-once/consume-once shape: any pushed screen sets a target tab index
/// here; `AppShell` listens and switches to it, then resets to null so it
/// only fires once.
final requestedTabProvider = StateProvider<int?>((ref) => null);

/// P3‑47: the bottom-nav tab currently on screen. Unlike
/// [requestedTabProvider] (a one-shot "please switch" request), this always
/// reflects the tab actually showing. Exists because every tab's `State`
/// stays alive at once inside `AppShell`'s `IndexedStack` — so a screen with
/// a live sensor stream (the Qibla compass) keeps running, and buzzing, even
/// while a different tab is on screen. Real-device feedback: "random haptic
/// in the background I can't find the source of" was the Qibla alignment
/// buzz firing from the kept-alive Prayer tab. Screens with background-
/// unfriendly work watch this and pause when they aren't the active tab.
final activeTabProvider = StateProvider<int>((ref) => AppTab.home);

/// Same seam, one level deeper: `LibraryScreen` has its own inner
/// `TabController` (0 = الكتب, 1 = الحديث), separate from the bottom-nav
/// index above. P3‑25: `DownloadsScreen`'s overview rows navigate here —
/// switching to the library bottom-nav tab isn't enough on its own to land
/// on "تحميل الكتب" specifically if the library tab happened to be sitting
/// on الحديث, so both providers get set together for that jump.
final requestedLibraryTabProvider = StateProvider<int?>((ref) => null);
