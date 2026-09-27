# Every screen, every device, every orientation, and a TV remote

Owner, 2026-09-26 (hard requirement, «شرط أساسي»): the whole app must lay out
correctly upright and sideways, nothing overlapping or hidden, space used well
in both directions, on every phone, tablet and smart screen of any size and
density - and be usable with a TV remote. Step by step, researched, «مش عايز
أي مفاجآت».

## What was researched (live, 2026-09-26)

| Source | What it says |
|---|---|
| docs.flutter.dev/ui/adaptive-responsive/general | Decide layout from the **window size** (`MediaQuery.sizeOf`, `LayoutBuilder`), not orientation or device type; 600 dp is the rail/bottom-bar break; never lock portrait. |
| developer.android.com window size classes (updated 2026-09-22) | Width: compact < 600, medium 600-840, expanded 840-1200, large 1200-1600, XL >= 1600 dp. Height: compact < 480 (99.78 % of phones sideways), medium 480-900, expanded >= 900. |
| developer.android.com/training/tv/get-started/navigation | Something must always have focus; a **visible** focus indicator everywhere; every control reachable by D-pad; lists scroll with up/down; Back returns and eventually exits, never gated. |
| developer.android.com TV app quality | `CATEGORY_LEANBACK_LAUNCHER` intent, 320x180 banner, `android.hardware.touchscreen` and `android.software.leanback` `required="false"`, landscape without letterboxing. |
| Flutter 3.38.7 source, `widgets/app.dart` | Arrow keys -> `DirectionalFocusIntent`; `select` (D-pad centre) and `gameButtonA` -> `ActivateIntent`. So InkWell/buttons already work with a remote; `GestureDetector` does not (not focusable). |

## Measured in the code (2026-09-26)

- 33 layout decisions in 20 files keyed to **orientation** rather than size.
- 21 tap targets in 22 files are bare `GestureDetector(onTap:)` - a remote
  cannot reach them (clock, prayer slides, tasbeeh counter, Hajj counters,
  hifz, mushaf page, player, splash, tutorial...). 60 `InkWell`s are fine.
- Orientation locks: the image mushaf (quran_screen) and `AdhanActivity`
  (`screenOrientation="portrait"` - on a TV that letterboxes; TV-LO).
- Manifest has no LEANBACK_LAUNCHER, no banner, no touchscreen
  `required="false"`: the app is not in a TV's launcher at all.
- No Android TV system image on this machine; only `Medium_Phone_API_36.1`.

## Stages (each ends committed, built, seen)

**A. Foundation.** `ScreenClass` (the Android breakpoints above) in
`core/`; the 33 orientation checks move to size where size is what they mean
(two panes = width >= 600 or height < 480; side tabs = height compact or
width >= 840...). Manifest for TV (launcher intent, banner built from the
owner's icon unchanged, touch not required). Adhan activity unlocked.

**B. Remote.** Visible focus ring app-wide (theme focus colours + a ring on
cards); the 21 `GestureDetector` targets become focusable/activatable;
mushaf: D-pad left/right turns the page, centre selects the ayah; counters
count on centre; initial focus on every screen; Back never traps.

**C. Sweep.** Every screen and sheet at: phone 1080x2400/420 (the
emulator), phone 1220x2712/480 (the owner's Xiaomi), tablet 1600x2560/320,
smart screen 1080x1920/240, TV 1920x1080/320 - upright and sideways, and
walked with `adb shell input keyevent DPAD_*`. Faults fixed as found.

**D. Real TV.** Android TV emulator image (needs the owner's OK for the
download) - install, launcher banner, remote walk, adhan on TV.

Each stage: analyze clean, tests pass, `build_github_release.bat`, seen on
the emulator, TASK_FOLLOWUP + checkpoint. Release only when he asks.
