import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Same seam, one level deeper: `LibraryScreen` has its own inner
/// `TabController` (0 = الكتب, 1 = الحديث), separate from the bottom-nav
/// index above. P3‑25: `DownloadsScreen`'s overview rows navigate here —
/// switching to the library bottom-nav tab isn't enough on its own to land
/// on "تحميل الكتب" specifically if the library tab happened to be sitting
/// on الحديث, so both providers get set together for that jump.
final requestedLibraryTabProvider = StateProvider<int?>((ref) => null);
