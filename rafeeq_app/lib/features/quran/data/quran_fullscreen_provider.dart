import 'package:flutter_riverpod/flutter_riverpod.dart';

/// P3‑43 #6: "ملء الشاشة" used to only shrink `MushafTextPage`'s own card
/// padding — the AppBar and `AppShell`'s bottom nav bar, both ancestors
/// `QuranScreen` doesn't own, stayed on screen. `AppShell` isn't a parent
/// of `QuranScreen` in any way that lets it read the tab's own State
/// directly (same reason `quranJumpRequestProvider`/`requestedTabProvider`
/// exist), so this is that seam for the reverse direction: `QuranScreen`
/// sets this when full-screen reading is on, `AppShell` watches it to hide
/// its own `bottomNavigationBar` entirely while it's true.
final quranFullScreenProvider = StateProvider<bool>((ref) => false);

/// Whether the full-screen reader's floating controls (`MushafChrome`) are
/// showing. While they are, `AppShell` brings its navigation bar back over
/// the page (R5, 2026-10-02): the owner reopened the app onto a full-screen
/// mushaf and found no way to the other tabs — a page tap showed the
/// controls, but the tabs stayed hidden until full screen was turned off in
/// «العرض». The bar is laid over the page (`extendBody`), so showing it does
/// not re-lay out the mushaf.
final quranChromeShownProvider = StateProvider<bool>((ref) => false);
