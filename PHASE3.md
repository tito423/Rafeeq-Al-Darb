# PHASE 3 — Real-device feedback pass (owner, 2026-09-03)

> **Recovery note (2026-09-03):** the original P3-1..19 section below was briefly, accidentally truncated by a buggy append-script mid-session (it opened the file in write mode, which empties it immediately, then hit an encoding error before finishing — a retry then built on top of the already-emptied file). Recovered in full from git history (commit 5048241, the last fully-intact version) and merged back with the ROUND 2 section, which was never affected. Flagging this here in case anything looks slightly re-flowed compared to what was on screen before.

**This is the working task list for Phase 3.** It consolidates the owner's
last 3 content messages from the same real-device testing session, in order:

1. One long message covering nearly every screen — verbatim, organized, in
   `PHASE3_FEEDBACK.md`.
2. A new app-icon reference image + "restyle the RGB theme toward the
   tasbeeh reference's look."
3. Four reference screenshots — tasbeeh, Azkar hub, Home screen, and the new
   icon installed — with "take the design of the rest of the images and
   build typical/similar ones," saved to `design_refs/`.

Work through this the same way `PHASE2.md` was worked: one task at a time,
`flutter analyze` after each, checkpoint (`.\cp.bat`) after every meaningful
edit, mark a task `-Done` only once it's actually verified (device where the
bug was device-specific, emulator where that's sufficient). **P3‑7 (Adhan)
and P3‑13 (persistent prayer notification) are confirmed real bugs on a real
device** — not emulator limitations — the highest-value next step for both
is a live `adb logcat` while the owner reproduces them on his connected
phone.

Reference images: `design_refs/ref_tasbeeh.jpg`, `ref_azkar_hub.jpg`,
`ref_home.jpg`, `ref_icon_installed.jpg`.

---

## Status table

| # | Task | Status |
|---|---|---|
| P3‑1 | New app icon (crescent + open Quran, glowing blue/gold) | ✅ done, `flutter analyze` clean |
| P3‑2 | Rename "السبحة" → "المسبحة" everywhere | ✅ done |
| P3‑3 | RGB theme restyle toward the tasbeeh reference's palette | ✅ **done, live-verified** — calmer near-black backdrop, glow rings instead of filled blobs, sparse star-dots instead of a tiled grid; a real crash (unrelated to the restyle itself, in P3-20/21's navigation code) found+fixed along the way |
| P3‑4 | Home screen redesign (RGB info card, per-card Islamic pattern bg, interactive prayer card, hadith/khatma/continue-reading cards) | 🔶 header card, prayer card (**P3-22**), ornate hadith card, and continue-reading card all ✅ done + live-verified; only the app-wide per-card Islamic-pattern background pass (a much larger separate task) still open |
| P3‑5 | **Login / accounts — architecture decision** | ✅ **answered: optional** (guest mode stays default, sign-in adds sync) — not yet built |
| P3‑6 | Khatma card bugs + redesign | 🔶 nav bug fixed, undo added, duplicate label removed; full visual redesign still open — **real reference finally received** (`design_refs/khatma_app_ref/`, a competing app's own خطمة screens), unblocking this after being stuck all session for lack of one |
| P3‑7 | Adhan: confirmed real bugs + feature requests | 🔶 auto-play-on-select DONE; bug half **blocked on live device/logcat** (see P3‑19 for a real, concrete Android-14 lead found by code review) |
| P3‑8 | Mushaf reader: confirmed real bugs + feature requests | 🔶 surah-jump strip ✅ done + live-verified, caching re-verified as not-a-bug (see notes), toolbar captions done (P3‑34); pinch-zoom needs a live gesture check (code already there); first-open edition prompt + first-install onboarding still open (ties to P3‑21) |
| P3‑9 | Search & tafsir correctness bugs | 🔶 both search bugs fixed; ✅ **tafsir-ayah-link fixed — was a major bug: ~83% of the Quran showed an earlier ayah's tafsir, plus one whole source was mislabeled (real content = Ibn Kathir, not Jalalayn) — full data rebuild, live-verified**; non-Hafs-gating still open |
| P3‑10 | "معاني الكلمات" tab — remove unless a real source is found | ✅ done — tab removed |
| P3‑11 | Azkar redesign (remove intro, swipe nav, grid hub) | ✅ **done, live-verified on emulator** — المقدمة filtered, swipe nav, and the grid-hub redesign (2-column card grid, all 133 real sections after المقدمة, each card icon-matched by keyword) all shipped and confirmed on-device |
| P3‑12 | Tasbeeh redesign to match reference | ✅ **done, live-verified on emulator** — matches `ref_tasbeeh.jpg` closely |
| P3‑13 | Persistent prayer notification — confirmed real bug + "must not be dismissible" | **blocked on live device/logcat** — a dead second implementation found + removed along the way, see P3‑19 |
| P3‑14 | Settings: Russian layout bug, French locale | 🔶 Russian bug ✅ fixed (was a Khatma-card layout bug, not a Settings screen bug — see below); French still open |
| P3‑15 | Library: slow reader, page-nav redesign, مكتبتي split, catalog scope | 🔶 catalog +3 books DONE, مكتبتي split DONE; reader speed investigated — **does not reproduce with a real 15.8MB book on this emulator**, code already lean; scroll/fast-jump/pinch-zoom **all confirmed already built in** to the PDF viewer library — only the visual theming pass is genuinely still open |
| P3‑16 | New "الصلاة" bottom-nav tab incl. professional Qibla compass | ✅ **done, live-verified** — real great-circle Qibla bearing + live compass needle, honest fallback states, Adhan-settings link; found+fixed a real cross-cutting tab-index bug + a real location-hang bug along the way; only the "populated" (real GPS) needle state is unverified, same emulator-location limitation as P3‑22 |
| P3‑17 | R2 hosting migration | ✅ done this session, see `HOSTING.md` — rotate token / old-bucket decision still open |
| P3‑18 | P2‑8 items already approved (#11 app-lock, #12 group khatma w/ real sign-in) | queued, **#12 folds into P3‑5** |
| P3‑19 | Dead native notification code found + removed; Android-14 full-screen-intent permission gap found + fixed | ✅ all done — cleanup, native check/settings-launch methods, and the settings card all shipped |

---

## P3‑1 — App icon ✅ DONE

New mark: a crescent moon (glowing blue→gold gradient) cradling an open
Quran/mus-haf (gold pages, gilt spine), a few soft stars, on a deep-navy
radial glow field — matching the owner's reference image and reasonably
close to `design_refs/ref_icon_installed.jpg`. Rebuilt as code, same
reproducible pipeline as the P2‑1.5/mosque redesigns:

- `rafeeq_app/assets/icon/src/icon_full.svg` / `icon_fg.svg` / `icon_bg.svg`
  rewritten (crescent via the standard two-arc "moon" construction — **not**
  two full circles combined with `evenodd`, which XORs instead of
  subtracting whenever the discs aren't fully nested; found this the hard
  way rendering an intermediate version and fixed it before finalizing).
- Rendered via headless Chrome per `assets/icon/src/README.md`'s existing
  recipe (transparent-background flag on the foreground layer, alpha
  sanity-checked: corner pixel `A=0`), `dart run flutter_launcher_icons`
  regenerated all Android densities + adaptive XML + iOS. `flutter analyze`
  clean.
- Visually reviewed by rendering + reading the SVG/PNG at each step (not
  just assumed) — iterated once on the crescent geometry after the first
  pass came out as a near-full ring instead of an open crescent.

**Not yet re-verified on-device** — will show up in the next APK build.

## P3‑2 — "السبحة" → "المسبحة" ✅ DONE

All 3 occurrences in `ar.json` (`home.tasbeeh`, `azkar.tasbeeh`,
`azkar.tab_tasbeeh`) updated. Parity unaffected (values changed, not keys).

## P3‑3 — RGB theme restyle ✅ DONE, live-verified

Owner: "خلي ثيم التطبيق rgb قريب للثيم اللي انت شايف في صورة المسبحة" (make
the RGB theme close to the theme in the tasbeeh reference image). Looking at
`design_refs/ref_tasbeeh.jpg`: a near-black background, a soft emerald/teal
glowing ring around the counter circle, small scattered star-dots, warm gold/
purple/teal/blue pill buttons for the four dhikr choices — calmer and darker
than the old `rgb_backdrop.dart` (which leaned brighter neon teal/violet/
gold aurora, three large filled radial-gradient blobs plus a busy tiled
rub-el-hizb star grid).

**Restyled `_RgbPainter`** — kept the exact same seam (`AppTheme.rgb()` +
`RgbScaffoldBackground`/`_RgbPainter`, §5.6 of `HANDOVER.md`), only retuned
what it paints:
- The three large filled blobs (`RadialGradient` discs, alpha 0.28,
  covering most of the screen) → three soft glow **rings** (stroked
  circles with a blur mask, alpha ~0.11), teal-weighted (teal picked 2× as
  often as violet/gold) so the dominant colour reads as the reference's
  emerald glow rather than an even three-way rotation — this directly
  echoes the reference's actual "glow ring around the counter" motif
  instead of a filled wash.
- The tiled rub-el-hizb star grid (repeating every 132px across the whole
  screen, alpha 0.05) → a small fixed set of 18 twinkling star-dots (a
  seeded `Random(7)` so positions never jitter, only their alpha pulses) —
  matching the reference's few scattered dots instead of a busy repeating
  pattern.
- Motion slowed down further (phase multiplier 0.4 vs. 1.0) for a calmer
  drift.
- `AppTheme.rgb()`'s own `ColorScheme` (primary `0xFF22E0C6` emerald, dark
  semi-transparent cards) was already close to the reference and left
  untouched — only the backdrop needed retuning.

`flutter analyze`/`flutter test` clean.

**A real crash found live, not by static review, while testing this** —
unrelated to the painter itself, but only surfaced through this same
testing pass: switching to the RGB theme from Settings crashed with
`Looking up a deactivated widget's ancestor is unsafe` — root-caused via
`flutter run`'s live stack trace (not guessable from a screenshot alone)
to `SplashScreen._proceed()` and `OnboardingScreen._finish()` (both P3-20/
21, this same session): both called `Navigator.of(context).pushReplacement`
with a `builder:` callback that read `context.locale.languageCode` — but
that closure runs *later*, once the old screen's element may already be
mid-deactivation from the `pushReplacement` itself, so the ancestor lookup
inside `.locale` throws. Fixed in both places by reading
`context.locale.languageCode` into a local **before** calling
`pushReplacement`, not inside the `builder:` closure. This crash had
nothing to do with the RGB restyle itself — it would have fired switching
*into* RGB from any theme, found only because this task's testing pass
happened to be the first time that exact navigation path ran after P3-20/21
shipped.

**Live-verified on `emulator-5554`** (via `flutter run` for the live crash
trace, then a full rebuild+install to confirm the fix): Settings → RGB
theme now switches with no crash — confirmed the calmer near-black
backdrop with faint teal glow rings and scattered star-dots renders behind
Settings, Home, and the Adhkar tab's Tasbeeh screen (a strong side-by-side
match to `ref_tasbeeh.jpg`'s own mood, especially next to the tasbeeh
counter's own already-shipped P3-12 glow-ring styling). "Motion effects"
toggle (existing, unaffected) still visible and working.

## P3‑4 — Home screen redesign

Two different asks layer on top of each other here — keep them straight:

1. **From the long feedback message:** replace the "رفيق الدرب" title +
   "صباح/مساء الخير" greeting with **one fixed RGB card**, same in every
   theme, showing: Hijri date (right, RTL "far side"), "مرحبا بك يا
   `<username>`" (center — needs P3‑5), Gregorian date (left). All cards
   app-wide get a calm, theme-aware Islamic-pattern background.
2. **From `design_refs/ref_home.jpg`:** the actual reference layout — top:
   Hijri + Gregorian date row, a live `HH:MM:SS` clock, "الصلاة القادمة"
   pill with countdown ("متبقي 1 ساعة و 7 دقيقة"), location line; a row of
   4 colored prayer-time chips; a "متابعة القراءة" (continue-reading) card;
   the Khatma card (redesign, see P3‑6); an ornate "حديث شريف" card with
   decorative corner flourishes. This is the concrete shape to build
   toward — closer to the existing Home's *content* (next-prayer, khatma,
   random-hadith cards already exist per P2‑6/11/13) than to a wholesale
   redesign; the work here is mostly the visual language (the RGB glow
   card, the live countdown clock, the ornamental hadith frame) and the new
   date/greeting header, not new data plumbing.

**✅ Header card done + live-verified.** New `_HeaderCard` in
`home_screen.dart` replaces the old AppBar title + time-of-day greeting
entirely: a fixed dark navy→teal→violet gradient card (same in every app
theme, a static echo of the RGB theme's own palette, gold-tinted border
glow) with the real Hijri date (`hijri` package, `HijriCalendar.now()`) at
the row's start, "مرحبا بك" centred, the real Gregorian date
(`DateFormat.yMMMd`, locale-aware) at the end — "start"/"end" not literal
left/right, so it mirrors correctly in both RTL and LTR locales rather than
hardcoding a side. P3‑5 was answered (optional login) but **login itself
isn't built yet**, so the welcome text is honestly generic ("مرحبا بك"),
not a placeholder name — swap it for the real signed-in name once accounts
exist, per rule 1 (never invent data). +6 keys × 5 locales
(`home.welcome_guest`). `flutter analyze` clean, `flutter test` 15/15,
**and live-verified on `emulator-5554`**: installed a fresh debug build,
confirmed the card renders exactly as intended — "٢١ ربيع الأول ١٤٤٨ هـ"
right, "مرحبًا بك" centre, "٣ سبتمبر ٢٠٢٦" left, correct real dates for
today.

**Animated/interactive prayer-times card + live countdown clock: ✅ already
done** (superseded by round-2 **P3-22**, live-verified there).

**✅ Ornamental "حديث شريف" card + "متابعة القراءة" continue-reading card —
DONE, live-verified.** The owner sent a real reference
(`design_refs/round2_2026-09-04/ref_hadith_card.jpg` +`ref_home_v2.jpg`)
with "use pics in new folder and proceed all":

- **`DailyHadithCard` wrapped in a new `_OrnateFrame`** — a gold hairline
  border, a gold quarter-circle corner flourish (`CustomPainter`, mirrored
  into all four corners), and small gold stars flanking the title text
  ("★ حديث اليوم ★"), echoing the reference's own corner-ornament/star
  motif. Deliberately **not** the reference's near-black-green palette —
  this app's own navy/gold theme instead (light theme gets a matching
  light-scaffold/white gradient), same adaptation rule as P3‑29's Shamela
  reference.
- **New `ContinueReadingCard`**, split out of `KhatmaCard`'s own "اقرأ
  اليوم" nudge — the reference shows it as its own, separate
  bookmark-style "where you left off" card, not tied to any khatma's
  progress. Built on **real data only**: `quran_screen.dart` already
  persists the reader's last-open page on every page change
  (`kQuranLastPageKey`); the card resolves the real first ayah on that
  page (`data.repo.ayahsOfPage`) for the surah name + ayah number, and
  renders nothing at all when that key has never been set (a fresh
  install, Quran tab never opened) — no fabricated "الفاتحة · آية 1"
  default for every guest. Tapping it jumps straight to that page via the
  existing `quranJumpRequestProvider` + `HomeNavigate` seam
  (`KhatmaCard` already uses the same pattern).
- +2 keys (`home.continue_reading_title`, `home.continue_reading_button`)
  × 5 locales; reuses the existing `quran.ayah`/`quran.page` keys for the
  subtitle rather than adding duplicates.

**A real reactivity bug found live, not by static review:** the first
version had `ContinueReadingCard` read the raw `SharedPreferences` value
directly on every build. That looks reactive but isn't — `AppShell` keeps
every tab mounted in an `IndexedStack`, so switching *back* to Home
doesn't rebuild it; the card kept showing whatever it saw on its *first*
build (usually "nothing yet"), even after the user read several pages of
Quran in the same session and returned to Home. Confirmed live on the
emulator: read Quran page 2, switched back to Home, the card still didn't
appear. Fixed with a proper `StateNotifierProvider`
(`quranLastPageProvider` in the new `quran_last_read.dart`) — `set()`
updates real provider state, which `ref.watch` in the always-mounted
`ContinueReadingCard` reacts to regardless of which tab is visible.
`quran_screen.dart`'s `_persistPage()` now goes through this provider
instead of writing `SharedPreferences` directly.

**Live-verified on `emulator-5554`** (a fresh AVD instance — the previous
one had degraded to 13.5h uptime / load average 15+, the same known
emulator-exhaustion pattern documented earlier this project, not a code
issue): fresh install → Home showed the ornate hadith card correctly, no
Continue Reading card (honest — nothing read yet); opened Quran, jumped to
Surah al-Baqarah (page 2); returned to Home — the Continue Reading card
appeared **live, same session, no restart needed** — "Continue Reading /
سُورَةُ البَقَرَة / Ayah 1 · Page 2"; tapped the card — navigated straight
back to page 2 in the Quran tab, confirming the read-position round-trip
end to end.

**Still open:** per-card calm Islamic-pattern backgrounds (app-wide, not
just Home — this is a much larger, separate pass touching many screens,
not scoped into this round).

## P3‑5 — Login / accounts — owner decision needed

The long feedback message says login should happen "في بداية التطبيق" (at
the start of the app) so khatma/azkar/settings persist per user — this is a
bigger claim than P2‑8 #12's "group khatma needs accounts" (already
approved with real Google Sign-In, `PHASE2_RESEARCH.md` §12): it asks for
accounts to gate **the whole app**, reversing the deliberately-documented
"guest mode is the only mode" architecture (`HANDOVER.md` STAGE 7).

**Ask the owner directly before writing any of this:** is login
**mandatory** (no using the app at all pre-sign-in) or **optional** (guest
mode still works exactly as today; signing in adds the personalized
card + lets data follow the account across devices)? This one answer
determines the onboarding flow, whether local-only data needs a "guest →
signed-in" migration path, and how big this task actually is.

## P3‑6 — Khatma card

- ✅ **Fixed: "افتح المصحف" (and "قرأت اليوم" from inside the full
  `KhatmaScreen`) did nothing but pop back to Home.** Root cause:
  `AppShell`'s bottom-nav tab index was local `State`, reachable only via a
  `HomeNavigate` `InheritedWidget` scoped to `HomeScreen`'s own subtree —
  `KhatmaScreen`, pushed as a separate route sitting in the `Navigator`'s
  `Overlay`, isn't a descendant of it, so the callback was always null there.
  New `lib/app/shell/tab_request_provider.dart` (`requestedTabProvider`)
  mirrors the existing `quranJumpRequestProvider` seam — any pushed screen
  sets a target tab, `AppShell` listens and switches, then resets to null.
- ✅ **Added an undo for "قرأت اليوم".** `KhatmaStore.restore(previous)`
  reverts to the exact pre-tap snapshot; a snackbar with a "تراجع" action
  (new `common.undo` key, all 5 locales) shows right after marking today
  read, from both the Home card's inline button and the full manager's
  tile. `flutter analyze` clean, `flutter test` 15/15 (2 new cases added in
  the same pass for the search fixes below).
- Still open: the duplicated "ختمة جديدة" label (shows both below and
  inside/on the button), and the full redesign to `design_refs/ref_home.jpg`'s
  compact card language (no image of the specific "ختمة" app referenced was
  attached — that reference image is the closer, actually-in-hand one).

## P3‑7 — Adhan

**Confirmed real bugs (need live device/logcat, not guesswork):**
- Full-screen video/karaoke screen **never appears at all** on a real
  device, tapping "تجربة" only shows a notification.
- Stop/Mute buttons on that notification **do nothing**.
- Selecting a different adhan while one is previewing/playing doesn't stop
  the previous one — can overlap.

**Feature requests (unblocked, no device debugging needed to build):**
- Setting: let the alert go full-screen **regardless of lock state**, not
  only when locked.
- Auto-play a preview immediately on selecting an adhan (no separate play
  tap).
- A dedicated **preview button for adhan video** clips (audio already has
  one).
- Redesign the "طريقة العرض" / "الأذان الافتراضي" pickers as a card with a
  dropdown; also let the user choose **how** pickers present app-wide —
  popup/dropdown vs. full-screen.
- Owner will supply **10 of his own adhan audio files** to replace all
  currently-bundled ones ("مش عاجباني" — he doesn't like any of the current
  sounds). Wait for the files before removing the current 10.

## P3‑8 — Mushaf reader (text/image/Sunan as-Suwar)

**Re-investigated live on `emulator-5554` — the back button itself turned
out to work correctly, at least for the Sunan as-Suwar single-surah
reader:** opened سورة السجدة from Home, the AppBar's auto-generated back
arrow (mirrored to the top-right under RTL — correct Material behaviour,
not a bug) was there and, once tapped at its actual coordinates (a first
attempt missed — its real hit-box is `[943,74]-[1070,200]` in a
1080×2400 frame, easy to eyeball wrong), it returned cleanly to Home. No
`PopScope` override anywhere in `single_surah_screen.dart`, so there was
nothing to have broken it in the first place. **This makes the "no back
button" complaint most likely a description of the already-fixed P3‑6
khatma navigation bug** (tapping "افتح المصحف" used to silently strand the
user on Home with the reader never really opening, which could easily read
as "opened somewhere with no way back") rather than a separate defect in
the mushaf/Sunan-as-Suwar chrome itself. Left open, not closed: the plain
Quran tab (`QuranScreen`) is a bottom-nav **root** tab, not a pushed route —
Android backing out of a root tab to the home screen/launcher is standard,
expected behavour there, not a bug to fix. The "error indicator top-right"
part of the original report is still unexplained — not reproduced this
pass; flag it again with a screenshot if it still shows up.

**Other bugs / gaps, all unblocked:**
- No pinch-to-zoom in text **or** image mode. — **re-check before assuming**:
  `mushaf_text_page.dart` already wraps text mode in an `InteractiveViewer`
  (`minScale: 1, maxScale: 3`), found while working P3-32/P3-34 — needs a
  live-device/emulator pinch-gesture check, not more code review, to
  confirm it actually works (or find why it might not).
- ✅ **Re-verified, does not reproduce — likely stale.** Read
  `MushafPageService.svgForPage()` closely: it checks an in-memory ring
  buffer, then disk, then network, in that order, and only writes to disk
  once a download is confirmed complete (`_isIntact`). Live-tested on
  `emulator-5554` in image mode: paged forward 1→4 (each new page shows a
  real "جارِ تحميل الصفحة..." loading state, as expected for a genuine
  first fetch), then paged back 4→3→1 — **every revisited page rendered
  instantly, screenshotted with zero delay between the tap and the full
  page appearing, no loading state at all** — exactly what a cache hit
  should look like. No re-fetch bug found; flag again with a specific
  page number/reproduction if it's still felt on a real device.
- ✅ **Done — a fast surah-jump strip, live-verified.** New `_SurahStrip`
  in `quran_screen.dart`: a horizontally-scrollable row of all 114 surah
  chips above the page-number bar, the current surah's chip highlighted
  gold and auto-scrolled into view as the reader pages through the mushaf,
  tapping any chip jumps straight to that surah (reuses the same
  `surahStartPages` lookup the existing full-screen "السور" sheet already
  uses). `flutter analyze` clean, `flutter test` 15/15. **Live-verified on
  a freshly-restarted `emulator-5554`:** chip #1 (الفاتحة) correctly
  highlighted on page 1; tapped chip #2 (البقرة) — jumped straight to page
  2, correct content, chip #2 highlighted; paged forward with the normal
  arrow to page 3 (still inside البقرة) — chip #2 correctly stayed
  highlighted, no regression to the existing page-turn controls.
- ✅ **Done — captions under the Quran-tab toolbar icons**, see P3-34.
- Missing: first-open-of-Quran-tab prompt to pick + download a mushaf
  edition immediately, saved locally.
- Missing: first-app-install onboarding prompting the user to pick +
  download an image mushaf edition **and** a recitation — flagged
  "أساسيين" (essential), i.e. should happen up front, not be left to
  discover.

## P3‑9 — Search & tafsir correctness

- ✅ **Fixed: substring-match bug** ("نشورا" matching inside "منشورا"). New
  `arabicWordBoundaryContains()` (`arabic_normalize.dart`) requires a match
  to start at a word boundary (index 0 or right after a space) in both
  `QuranRepository.search()` and `HadithRepository.search()` — a useful
  *prefix* match within a word (e.g. "رحم" → "الرحمن") still works, since
  only the start is constrained.
- ✅ **Fixed: "فاسقين" returned nothing.** Root cause found by querying
  `quran_local.db` directly with sqlite3 rather than guessing: U+0670 (the
  Quranic "dagger alif", the small mark inside "ٱلْفَٰسِقِينَ") was being
  stripped to nothing instead of expanded to ا — so the correctly-spelled
  query could never match. Fixed in `normalizeArabic`, but that alone
  breaks a small, separate, well-known exception list (الرحمن, هذا, ذلك,
  لكن, السماوات, …) where modern typed Arabic *omits* that same letter —
  so a new `normalizeArabicLoose` was added alongside it, and both
  search functions now check a query against both normalized forms. Full
  before/after verified directly against the real bundled DB (19 real hits
  for "فاسقين" after the fix, vs. 1 spurious hit before). `arabic_normalize_test.dart`
  covers all three cases now. **Not yet re-verified on-device/emulator** —
  will show up in the next build.
- ✅ **Fixed: "tafsir not linked to the right ayahs" — root-caused precisely,
  not just patched.** This was much bigger and more serious than the vague
  report suggested. Investigated by directly querying `quran_sciences.db`'s
  `tafseer_texts` table rather than guessing, and found **two separate real
  bugs**, both now fixed by a full data rebuild:
  1. **Every source only ever had real per-ayah data for roughly the first
     ~10 ayahs of every surah** (~1,000–1,060 rows total per source, when
     the Quran needs 6,236). Root cause: api.quran.com's tafsir endpoint
     paginates at 10 results/page by default, and the original one-off
     fetch never handled pagination. `build_sciences_db.py`'s range-
     grouping logic then made it far worse: whenever a surah's source data
     ran out early, it silently stretched the *last present* verse's range
     all the way to that surah's final ayah — so roughly **83% of the
     Quran was showing an earlier, unrelated ayah's tafsir**, not a gap.
     Confirmed directly: querying 2:255 (Ayat al-Kursi) against the old DB
     returned a row spanning ayahs 10–286 whose text was actually about
     2:10 ("في قلوبهم مرض"), nothing to do with Ayat al-Kursi at all.
  2. **The source labelled "جلالايين" (Tafsir al-Jalalayn) was never
     actually Tafsir al-Jalalayn.** Verified against api.quran.com's own
     `/resources/tafsirs` listing: the id that had been fetched (14) is,
     and has always been, **Tafsir Ibn Kathir** — confirmed independently
     by the content itself (extensive hadith citations with full isnad
     chains, comparing scholarly opinions at length — Jalalayn's whole
     reputation is being a hyper-terse word-by-word gloss; what shipped
     was neither terse nor Jalalayn). Real Jalalayn isn't offered by this
     provider at all currently, so rather than fabricate/guess a
     replacement, the source was relabelled to its real, verified
     identity: **تفسير ابن كثير**.

  **The fix, in full:** new `scripts/fetch_tafsirs_complete.py` re-fetches
  all 3 sources (Muyassar=16, Qurtubi=90, Ibn Kathir=14 — verified ids)
  complete, per ayah, via `?per_page=300` (covers even Al-Baqarah's 286
  ayahs in one request per chapter — the actual working shape of the API,
  found by testing it directly rather than assuming). `build_sciences_
  db.py`'s tafsir-loading rewritten (`load_tafsir_complete`): ranges are
  now inferred **only** from the real, complete sequence of ayahs present
  per source (a legitimate real behaviour — Muyassar genuinely comments on
  several consecutive ayahs together sometimes) and are **never** stretched
  past the last real entry to a surah's end — the exact "assume it
  continues" logic that caused bug #1 is now structurally impossible. Also
  removed the `ayah_sciences`/`tafseer_saadi`/`tafseer_ibn_kathir` table +
  columns entirely — confirmed completely dead (not in the shipped DB, no
  Dart code ever read them, and their own fetch mechanism was independently
  broken too, returning `0` tafsirs every time it ran).

  **Results, verified directly against the rebuilt DB:** muyassar 5,278
  real entries (up from ~1,013 — genuinely groups ayahs, as expected),
  ibn_kathir 6,205 (near-total 1:1 coverage), qurtubi 6,235 (essentially
  exactly 1:1, only 1 ayah of the whole Quran ungrouped-and-uncovered).
  Zero overlapping ranges anywhere. Only muyassar has any real coverage
  gap left (61 ayahs total across the whole Quran, all honestly at
  chapter-tail edges where the source data itself stops — left blank
  rather than guessed, unlike the old bug). Re-ran `2:255` directly: all 3
  sources now correctly return Ayat al-Kursi's own text (Ibn Kathir opens
  literally naming it — "هذه آية الكرسي ولها شأن عظيم..."). `SciencesRepository.
  tafseerSources` updated to the corrected key + label. Had to separately
  recover `translations`/`translation_editions` (37,416 rows, 6 editions)
  from the last git-committed DB after `build_sciences_db.py`'s
  `os.remove(OUTDB)` step wiped them — their own source JSON files had
  already been deleted after the original ingest, so they weren't
  re-derivable; merged back in via `ATTACH DATABASE`, verified row counts
  match exactly. `flutter analyze` clean, `flutter test` 15/15.

  **Live-verified on `emulator-5554`:** navigated to page 42 (real 2:254,
  one ayah before Kursi — deep into the surah, far past the old ~10-ayah
  cutoff), opened the ayah sheet's Tafsir tab: Muyassar's text accurately
  paraphrases **this specific ayah** ("أخرجوا الزكاة المفروضة... قبل
  مجيء يوم القيامة" — matches 2:254's actual content about spending
  before a day with no trade/friendship/intercession, not some earlier
  ayah); confirmed the dropdown now lists **"تفسير ابن كثير"** (not
  "تفسير الجلالين") as the third option. The Translation tab's English
  text for the same ayah also checked out independently correct ("O you
  who have believed, spend from that which We have provided...").

- **Still open:** tafsir/translation gating for non-Hafs riwayat editions
  (`MushafEdition.sciencesAvailableFor` — re-check the gating message
  logic).

## P3‑10 — "معاني الكلمات" tab

Owner repeats a decision already recorded in `PHASE2_RESEARCH.md`'s
word-meanings section: this tab should be real *gharib al-Qur'an* (Arabic
word explanations), not the English-gloss stopgap currently shown. **Now
explicit: if no real ayah-aligned free source is wired in, remove the tab
entirely** rather than keep shipping the English version dressed up next to
the Arabic word. (`al-Mufradat fī Gharīb al-Qurʾān` by al-Rāghib al-Iṣfahānī
is the one real PD candidate found so far, root-indexed — needs a matching
pipeline against `word_grammar.root` that was never built; build it or pull
the tab.)

## P3‑11 — Azkar redesign ✅ DONE, live-verified

- ✅ "المقدمة" (intro) section filtered out entirely.
- ✅ Bottom arrow-navigation buttons removed; navigation is by **swipe**
  now, direction-aware (RTL-correct for Arabic).
- ✅ **Grid-hub redesign shipped.** Investigated the real `azkar_sections`
  table directly (134 real Hisn al-Muslim sections, sqlite3 query against
  the bundled DB) before building anything: `ref_azkar_hub.jpg`'s apparent
  6-category taxonomy (أذكار الصباح /
  المساء / التسبيح والتحميد /
  أذكار النوم / أدعية قرآنية /
  الاستغفار as separate cards) does **not** map cleanly
  onto the real 133-section data — correctly declined to invent that
  structure (rule 1: no fabricated data), and instead rebuilt `_SectionsTab`
  (`azkar_screen.dart`) to show all 133 real sections as a 2-column
  `SliverGrid` of new `_AzkarSectionCard`s, each with a real section title
  and an icon picked by a new keyword-matching `_azkarIcon()` helper (~23
  keyword→icon mappings), plus a "من حصن المسلم
  وكتب السنة" subtitle and a "اختر نوع
  الذكر" header (new `azkar.hub_subtitle`/`azkar.choose_type`
  keys, +2 keys × 5 locales). `flutter analyze` clean, `flutter test`
  15/15.

**Live-verified on `emulator-5554`, not just built:** installed a fresh
debug build (worked around an `INSTALL_FAILED_INSUFFICIENT_STORAGE` error
via `adb uninstall` before install — emulator disk was near-full), walked
the notification + location permission dialogs (`uiautomator dump`-derived
exact coordinates), confirmed the grid renders with real section titles/
icons starting right after المقدمة (item #1 is really
"فضل الذكر", not the old intro), and confirmed tapping a
card ("فضل الذكر") opens its section reader correctly — which
also showed the earlier swipe-nav work rendering correctly there (no arrow
buttons, "مرّر للتنقل بين الأذكار" hint
visible, working back button, real ayah/dhikr content, "تم بحمد
الله" completion button).

## P3‑12 — Tasbeeh redesign ✅ DONE, live-verified

Rebuilt `_TasbeehTab` (`azkar_screen.dart`) to match `design_refs/ref_tasbeeh.jpg`
— this changed the actual interaction model, not just decoration: the old
33/100/1000 numeric-target chips are gone, replaced with **4 colour-coded
dhikr-phrase pills** (سبحان الله blue / الحمد لله green / الله أكبر purple
/ لا إله إلا الله gold — new `_DhikrOption`/`_DhikrPill`), a glowing circle
(colour + border + `BoxShadow` matching the selected pill) showing the
phrase + a live count + "اضغط للتسبيح", a fixed classical target of 33 that
rolls the count back to 0 and advances "عدد الجولات" (rounds) instead of
climbing to an arbitrary ceiling, a "المجموع" chip tracking the running
total across every dhikr/round this session, and a trash icon that clears
everything. +9 keys × 5 locales (the 4 dhikr phrases are religious content,
kept identically Arabic in every locale file — same convention as
`adhan_text.dart`/du'a text elsewhere; only the UI-chrome keys are actually
translated per locale). `flutter analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`, not just built:** installed the debug
build, opened الأذكار → المسبحة, confirmed all 4 pills render with the
right colours and the selected one (سبحان الله) glows; tapped the circle 3
times → count went to 3, المجموع went to 3; switched to الحمد لله → circle
re-coloured green, its own phrase shown, count reset to 0, **المجموع stayed
at 3** (confirmed the running total is per-session not per-dhikr, as
intended). Not yet exercised: reaching a full round of 33, the trash-clear
button, haptics (emulator has no haptic feedback to observe).

## P3‑13 — Persistent prayer status notification

**Confirmed real bugs, need live device/logcat:**
- Doesn't appear at all on the real device ("مش شغال يا معلم").
- When swiped away from the shade, it must **not** be removable — should
  behave as a true always-on notification Android can't casually dismiss
  (current code already sets `ongoing`/`autoCancel:false` — either that
  isn't taking effect on this OS version, or the notification isn't being
  posted at all; same investigation as P3‑7).

## P3‑14 — Settings

- ✅ **Russian locale bug FIXED.** The screenshot the owner sent showed it
  wasn't actually a Settings-screen bug at all — it was the Home screen's
  Khatma card title ("Хатм Корана") rendering **one Cyrillic letter per
  line** down the whole card. Root cause: `KhatmaCard._ActiveKhatmaRow` put
  the progress ring, an `Expanded` title column, *and* the "read today"
  button in one `Row` — the button isn't width-constrained, so it claims
  its full natural width, and Russian's button label is far longer than
  Arabic's ("Читать сегодня (4 стр.)" vs. "اقرأ اليوم (٤)"), squeezing the
  `Expanded` title down to a couple of pixels. Fixed generically (this
  wasn't a Russian-only patch — any locale with a long enough label would
  trigger it): the button moved to its own row below instead of sharing one
  with the title, mirroring the same layout `_BatteryCard`/
  `_FullScreenIntentCard` already use. `khatma_screen.dart`'s own tile was
  checked for the same anti-pattern and is already safe (both its buttons
  are individually `Expanded`, 50/50). **Not yet checked:** other Home
  cards for the identical anti-pattern — this was fixed where the owner's
  screenshot pointed, not swept for everywhere else it might also exist.
- **French** is apparently listed as supported but not actually wired in —
  needs scoping: Phase 2's 5 locales were ar/en/es/ru/pt (`fr` was never
  one of them). Check whether the owner means adding French as a genuine
  6th locale (full `fr.json` at parity, `main.dart` `supportedLocales`,
  language picker, translation-parity test update) or whether something is
  already half-there and just broken — grep for `fr.json`/`'fr'` before
  assuming which.

## P3‑15 — Library

- 🔶 **Investigated, does not reproduce here — documented honestly rather
  than guessed at further.** `book_reader_screen.dart` is already about as
  lean as this can be — a plain `StatelessWidget` handing the file
  straight to `SfPdfViewer.file(...)`, no extra state, no redundant
  rebuilds to remove; there's no obvious code-level inefficiency to fix.
  Live-tested on `emulator-5554` with a real downloaded book (رياض
  الصالحين, 15.8 MB scanned PDF, not a small file): opened it, scrolled
  rapidly through 13+ swipes deep into the book (well past page 14) — every
  frame captured showed complete, correctly-rendered real content, no
  blank pages, no visible stutter or lag in this pass. **Not claiming the
  complaint is wrong** — a real device or a much larger/heavier scanned
  book could behave differently than this test did — but re-verify with a
  specific book + a real device before assuming more code work is needed
  here. One real, standard performance lever *is* available if slowness is
  confirmed later: `SfPdfViewer`'s `pageLayoutMode` defaults to
  `continuous` (keeps a wider virtualized scroll window); switching to
  `PdfPageLayoutMode.single` (one page at a time) is a well-documented way
  to lighten this for very large PDFs — not applied speculatively here
  since it wasn't confirmed necessary, and it would need reconciling with
  the "scroll + fast jump strip" navigation ask directly below (continuous
  scroll is presumably still wanted as the primary way to read).
- Page navigation redesign: **scroll already exists** (`SfPdfViewer`'s
  default `PdfPageLayoutMode.continuous`) **and a fast-jump control
  already exists too** (`canShowScrollHead: true`, already set — a
  draggable scroll thumb with a live page number, Syncfusion's own
  equivalent of the surah strip just built for the mushaf reader in
  P3‑8). ✅ **Pinch-zoom is also already built in**, confirmed by reading
  the package source (`syncfusion_flutter_pdfviewer` 33.2.13):
  `pdf_scrollable.dart` wires an `InteractiveViewer`-style
  `onInteractionUpdate` handler gated on `scaleEnabled`, and the public
  API's own docs list "when pinch zoom is performed" as one of three
  documented triggers for `onZoomLevelChanged` — not something added this
  pass, just confirmed present rather than assumed missing (a real
  two-finger pinch isn't practical to simulate over `adb`, so this is
  source+docs verification, not a live gesture test). **Only "refreshed
  visual design" is still a real, open ask** — a plain default
  `SfPdfViewer` today, no theming pass done on it yet.
- ✅ **DONE.** "مكتبتي" now shows two clearly separate, headed sections
  (مصوّر then نصي) instead of one flat list interleaving both editions of
  the same book.
- ✅ **DONE (first batch).** Catalog expansion ("زي الشاملة") resolved —
  the owner clarified, once asked, that this meant *the نص reading design*
  for the specific authors already requested back in P2-4 (Ibn Taymiyyah,
  al-Hakim al-Tirmidhi, Ibn Abi al-Dunya), not a literal full mirror of
  Shamela. Added all 3, built with the exact same `build_book_text.py`
  pipeline and provenance discipline as the original 5, نص-only (no
  مصوّر hunted for these — the owner's explicit call; `LibraryBook`'s
  image-PDF fields are now nullable, a new `hasImage` getter gates the
  مصوّر|نص switch so it only shows when both editions actually exist):
  - **العقيدة الواسطية** (Ibn Taymiyyah, d. 728 AH) — Shamela 22665, ed.
    Ashraf ʿAbd al-Maqsud, Aḍwā’ al-Salaf. 72 pages, `printReliable: true`.
  - **نوادر الأصول في أحاديث الرسول** (al-Ḥakīm al-Tirmidhī, d. ~320 AH)
    — Shamela 720, ed. ʿAbd al-Raḥmān ʿUmayra, Dār al-Jīl (4 volumes).
    1237 pages. Honesty flag carried into `descriptionAr` itself, not
    hidden: this specific book is one classical hadith scholarship itself
    flags as containing a number of weak/unverified narrations alongside
    sound ones — a real characteristic of this book in any edition,
    unrelated to Shamela or this project.
  - **الصمت وآداب اللسان** (Ibn Abi al-Dunya, d. 281 AH) — Shamela
    13039, ed. Abū Isḥāq al-Ḥuwaynī al-Athari, Dār al-Kitāb al-ʿArabī.
    787 pages.
  - All 3 uploaded to R2 (`rafeeq-content/books/text/*.json`, the migrated
    host from P3‑17/`HOSTING.md` — not GitHub), byte-verified via
    `head_object` **and** a live `curl -I` against the public URL, same
    discipline as the R2 content migration. `flutter analyze` clean,
    `flutter test` 15/15.
  - **Not yet done:** more titles beyond these 3 (the owner's "زي
    الشاملة" reads as "keep growing this," not "these 3 and stop"), and
    the "if you find a مصوّر too, fine" half of the instruction — none of
    the 3 new books had an image edition specifically sought this pass.

## P3‑19 — Dead code found & removed (not owner-reported)

While investigating why the persistent prayer notification (P6/P3‑13)
might not fire on a real device, `MainActivity.kt` turned out to carry a
**second, completely different, entirely dead** native implementation of
essentially the same feature: a `com.tito.rafeeq_aldarb/salatuk_notification`
method channel building a custom `RemoteViews` notification
(`notification_salatuk.xml`, 6 prayer-time chips + a native chronometer) —
**never called from any Dart code** (confirmed by grep — no
`MethodChannel('...salatuk_notification')` anywhere under `lib/`). This
doesn't explain the reported bug (dead code can't misfire), but its
existence — completely undocumented in `HANDOVER.md`'s P2‑6 history — is
worth the owner knowing: it strongly suggests an earlier, undocumented
attempt at this exact feature before `prayer_status_notification.dart`'s
pure-Dart approach (the one `HANDOVER.md` actually describes) was built.
Removed the method channel handler, the now-orphaned
`showCustomNotification` function, and the unused layout XML — real APK
bloat and a real source of confusion for the next reader, owner included.
`prayer_status_notification.dart` itself was read closely for a live bug
and none was found by static review — its logic matches exactly what
`HANDOVER.md` already documented as emulator-verified working; **P6/P3‑13
genuinely needs a live device/logcat to diagnose further**, not more
guessing.

Also reviewed the Adhan Stop/Mute action-button wiring
(`adhan_alarm_service.dart`'s `_onNotificationResponse` /
`AndroidNotificationAction`s) end to end — structurally correct and
unchanged from what STAGE 1 already verified working on both emulator and
a real device. No defect found by static review; **P3‑7's remaining bug
half also needs a live device**, not another guess. One thing this review
did turn up as a real, concrete, fixable gap (not confirmed as *the*
cause here, but a genuine gap regardless): **Android 14+ (API 34) requires
the user to separately, manually grant a "Turn on full-screen
notifications" toggle** per app
(`Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`) — the
`USE_FULL_SCREEN_INTENT` manifest permission alone is no longer sufficient
on a fresh install targeting API 34+; without it, Android silently
downgrades a full-screen-intent notification to an ordinary heads-up one,
which matches "a notification appears but full-screen never does" exactly.
**✅ Built the same session, not left as a finding:** `MainActivity.kt`
gained `canUseFullScreenIntent` (native check, always `true` below API 34)
and `openFullScreenIntentSettings` (launches
`Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`), bridged through
`AdhanUriBridge`; `adhan_settings_screen.dart` shows a card — same visual
pattern as the existing battery-optimization-exemption one — when the OS
reports the grant is missing, and re-checks on app resume (the grant is
made from a system settings screen, not an in-app dialog, so there's no
synchronous result to read). +4 keys × 5 locales
(`prayer.full_screen_intent` / `_action`). `flutter analyze` clean,
`flutter test` 15/15, and — unlike the pure-Dart changes elsewhere this
session — this one touches native Kotlin, so it was also verified with a
real `flutter build apk --debug` (not just `flutter analyze`, which can't
see Kotlin errors at all) to confirm it actually compiles. **Not yet
verified on-device** whether granting this actually fixes the reported
full-screen symptom — that still needs the real phone.

## P3‑16 — New "الصلاة" (Prayer) bottom-nav tab ✅ DONE, live-verified

New 6th bottom-nav tab (`QiblaScreen`, between Quran and Azkar — matches
where `ref_home.jpg`/`ref_tasbeeh.jpg`'s bottom nav already showed a
"الصلاة" slot), built around a real Qibla compass:

- **The compass itself**: one needle (not a rotating dial face — much
  easier to read at a glance), pointing at the real great-circle bearing
  to the Kaaba (`21.4225°N, 39.8262°E`, the standard initial-bearing
  formula) offset live by `flutter_compass`'s device heading, with a
  gold→green glow + haptic pulse once the user is actually facing it
  (±5°). A plain geometric cube marks the needle tip — original art, no
  photo/trademarked Kaaba image, per this project's own content rule.
  N/E/S/W tick marks are fixed in place; only the needle rotates.
- **Every real-world failure state handled honestly, never faked**:
  locating (spinner), no location permission (message + retry + "open app
  settings", reusing `Geolocator.openAppSettings()`), no magnetometer on
  this device (a real possibility on some devices/emulators — a 3s probe
  on `FlutterCompass.events` tells "never granted a sensor" apart from
  "granted but silent").
- **Consolidation**: a card linking straight to the existing
  `AdhanSettingsScreen` (reusing `prayer.adhan_settings`, an existing
  key) — the full settings migration wasn't attempted this pass (real
  scope risk for a single session), but the new tab is now a real,
  working entry point to it rather than just the compass alone.
- **A real, cross-cutting bug found and fixed along the way**: inserting
  a 6th tab shifted every index after it, and `downloads_screen.dart`
  (this same session's P3‑25 work) had `requestedTabProvider`'s Library
  index hardcoded as a bare `3` — silently wrong the moment this tab
  landed. Fixed properly, not just patched: new `AppTab` (`tab_request_
  provider.dart`) names every bottom-nav index; `downloads_screen.dart`
  and `khatma_screen.dart`'s local `_quranTabIndex` were both moved onto
  it, so the *next* tab insertion is a one-line change here instead of a
  silent runtime misnavigation somewhere else.
- **A second real bug found live-testing, not by code review**: location
  fetches could hang indefinitely on at least this AVD image — well past
  `Geolocator`'s own `timeLimit`, and even wrapping just that one call in
  an explicit `.timeout()` wasn't enough (the earlier `checkPermission`/
  `requestPermission` awaits could apparently also stall, upstream of
  that fix). `LocationService.getCurrentPosition()` now wraps the *entire*
  permission-check-through-geocode chain in one outer 15s `.timeout()` —
  benefits this screen **and** the Home prayer card, which shares the
  exact same service. During this investigation the emulator also hit a
  genuine Android ANR ("Input dispatching timed out... FocusEvent") —
  traced via `adb shell uptime` (12.5h continuous uptime, load average
  ~6–8, ~200MB free of 2GB) to this specific AVD being heavily degraded
  after a very long session, confirmed not code-related by a clean
  relaunch working normally afterward; noted here rather than silently
  dismissed, in case it recurs.
- +1 key (`nav.prayer`) + a new `qibla.*` namespace (11 keys) × 5 locales.
  `flutter analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`:** the new 6-tab bottom nav renders
correctly (compass icon, "Prayer"/"الصلاة" label, both LTR and RTL —
confirmed in both English and Arabic device-locale runs); opened the tab —
"Locating you…" shows correctly; after the fix, a location-denied/failed
attempt correctly settles into the honest fallback card every time (not
just once), "Try again" correctly re-attempts and correctly times out
again the same way, "Open app settings" correctly opens the real Android
App Info screen for this app; the Adhan-settings link correctly opens the
real, existing `AdhanSettingsScreen` with all its content intact. **Not
verified**: the actual rotating needle against a real GPS fix + real
compass heading — this specific AVD's location provider never resolves a
position at all (the same limitation P3‑22 already documented for the
Home prayer card), so the "populated" compass state needs either a real
device or a differently-configured AVD to see rendered, same caveat as
P3‑22's own still-open item.

## P3‑17 — R2 hosting migration ✅ DONE (this session)

See `HOSTING.md` §2/§7. Still open: rotate the R2 token that was pasted
into chat to provision this; decide the contaminated old
`rafeeq-aldarb-data` bucket's fate (recommend: delete it, and check the
Cloudflare billing page — that bucket alone is already over the free 10 GB
tier).

## P3‑18 — P2‑8 items already approved

From the same real-device session, before the big feedback message: owner
approved building **#11** (app-lock during prayer time, sensitive
Accessibility/UsageStats permission — approved as-is) and **#12** (group
khatma) with **real Google Sign-In** specifically (not the anonymous-id
fallback) — which now folds directly into **P3‑5** above; do them together,
not as two separate accounts efforts. #8 (tajweed-colour text mode) and #13
(radio) are still just research-confirmed-buildable, not started.

---

# PHASE 3, ROUND 2 (2026-09-03, later) — owner resent + expanded feedback

The owner's next message had two parts:

1. **"اولا" — a verbatim resend of his original giant feedback message**
   (already logged as `PHASE3_FEEDBACK.md` and tracked as P3-1..P3-19
   above), ending "دي كانت كل طلباتي اللي فات، اتأكد منها وحدة وحدة" (these
   were all my past requests, confirm them one by one). **Do not re-log
   these as new items** — cross-check each against the status table above
   instead. As of this addendum: P3-1/2/6/9/10/11/12/14 (partial) are done
   and several live-verified; P3-3/5(design)/7(bug half)/8/13/15(reader UX)/16
   are still open — see the table, it is the authoritative status, not this
   note.
2. **"ثانيا" — genuinely new items**, logged below as P3-20 onward. A video
   (`design_refs/old_app_video.mp4`, 14 frames extracted to
   `design_refs/old_app_frames/`) of an **earlier working build of this
   same app** was attached, showing a splash screen, a first-run mushaf-
   choice/download flow, and — critically — the live animated Home screen
   `ref_home.jpg` only showed as a static mock before: a real ticking
   `HH:MM:SS` clock, "الصلاة القادمة: الفجر" pill with a live countdown, a
   location line, 4 coloured prayer chips with a "القادمة" badge on the
   next one, then the "متابعة القراءة" card. This is now the exact,
   frame-verified target for P3-4's remaining animated-prayer-card work.

## ⚠️ Important finding from the video — do not build one part of it as shown

The mushaf-choice screen in the video ("مكتبة المصاحف الشريفة", "اختر
طبعتك المفضلة من بين 17 مصحفاً") shows **17 mushaf editions with real
scanned cover-image thumbnails**, filterable by riwayah. Several of the
edition names visible — **"مصحف 12 سطر"**, **"مصحف التهجد وقيام
الليل"**, **"أوردو (12 سطر)/(13 سطر)"**, **"ورش عن نافع (الأصبهاني)"** — are
the *exact* internal names `HANDOVER.md` §5.1 already identified and
purged as **QuranFlash-derived** (`Medina1/2`, `Shamarly`, `Tahajod`,
`12line`, `NaskhTaleek`, `Urdu12/13/15`). This is strong evidence the old
app's mushaf-catalog screen — cover thumbnails included — was built on
scraped QuranFlash assets, the same violation of rule 2 already cleaned up
once. **Do not recreate that catalog screen or fetch/derive thumbnails for
those 17 editions** — this project has exactly **5** legitimately-sourced
editions (`quranpedia/quran-svg`, CC0). The splash screen itself (geometric
star pattern, gold circular badge, calligraphy) is generic Islamic-art
styling with nothing QuranFlash-specific in it — safe to rebuild from
scratch with our own mark and colours, and is tracked as P3-20 below.

## P3-20 — Splash screen ✅ DONE, live-verified

Two layers, since a native Android splash literally cannot animate (it's
shown before the Flutter engine even attaches):

- **Native `launch_background.xml`** (all 4 density/theme variants) now
  centres `@mipmap/ic_launcher` (our real P3-1 crescent+book mark) on the
  existing navy field, instead of the blank navy screen it was before —
  the one honest improvement available at this layer.
- **A new Flutter `SplashScreen`** (`features/splash/`) takes over the
  instant the engine attaches: a slow radial girih lattice
  (`SplashLattice`, a bespoke `CustomPainter` — concentric rings + chords
  joining every 5th point of a 16-point circle, echoing `rgb_backdrop.dart`'s
  own low-alpha-stroke/slow-rotation *technique*, not its tiled-star
  *shape*, since the reference frame is a single rosette, not a grid), a
  breathing-glow gold badge around a bundled copy of the real app icon
  (`assets/branding/app_mark.png` — a deliberate, documented exception to
  the "don't bundle `assets/icon/`" rule, since this copy actually ships
  at runtime), "رفيق الدرب" in `AmiriQuran`, and the tagline.
- **`app.tagline` was dead** (grep confirmed zero call sites anywhere in
  `lib/`) — repurposed it for the video's own exact wording "زاد المسلم
  اليومي ومصحف القلوب" (+ translated for the other 4 locales) instead of
  the generic feature-list string that was never actually shown anywhere.
- **Honest about what the hold is for**: every async bootstrap step
  (`SharedPreferences`, translations, timezone data, the adhan/reminder
  services) already finishes in `main()` *before* `runApp()` — Android's
  own native launch screen covers that real wait. By `SplashScreen`'s
  first frame there is nothing left to wait for, so its ~1.4s hold is a
  deliberate brand pause only, and is skipped entirely under reduced
  motion (the in-app "Motion effects" toggle or the system accessibility
  setting) rather than forcing a pointless animation on anyone who's
  turned that off.
- Then navigates (`pushReplacement`, no back-stack entry) to
  `OnboardingScreen` on first run or straight to `AppShell` otherwise —
  see P3-21.

`flutter analyze`/`flutter test` clean. **Live-verified on `emulator-5554`**
across three full install→launch cycles; a genuine Android XML bug was
caught and fixed along the way (below).

**A real build bug, not just a cosmetic one:** the native `launch_background.xml`
files originally had a code comment containing "--" (em-dash-style), which
Android's AAPT2 XML comment parser rejects outright (`the string "--" is
not permitted within comments`) — this failed the Gradle build completely
for all four density/theme variants, not a warning. Fixed by rewording the
comments to avoid the double-hyphen; confirmed the rebuild succeeds.

**A second real bug, found later during P3-3's testing pass, lived here
too:** `_proceed()`'s `context.locale.languageCode` was read inside the
`pushReplacement` `builder:` closure instead of before it — see P3-3's
writeup for the full root-cause and fix (the same bug, same fix, was in
`OnboardingScreen._finish()` too).

## P3-21 — First-run onboarding ✅ DONE, live-verified

Ties into the already-tracked **P3-8 G4/G5** (pick + download a mushaf
edition; first-install pick + download an image mushaf edition *and* a
recitation, both "essential"). Built as a real, functional screen, not a
mockup:

- **Mushaf edition list** — the 5 real editions (Hafs/Shubah/Duri/Qalun/
  Warsh), no fabricated cover art. Tapping a card's radio selects it as
  the active reading edition (`selectedMushafEditionProvider`); the
  download button/progress/pause/cancel is the *exact same*
  `MushafPageService.prefetchEdition` job the Downloads screen already
  used — not a second, decorative copy. `MushafDownloadTile` was pulled
  out of `downloads_screen.dart` into a public, shared widget
  (`features/downloads/presentation/widgets/`) for this reuse.
- **Recitation section** (G5's "essential" second download) — a reciter
  dropdown plus the exact same bulk-download card P3-27 already built,
  likewise extracted to a public `FullRecitationCard` widget and reused
  here unchanged.
- **The forbidden 17-mushaf cover-art catalog was NOT rebuilt.** The
  reference video's onboarding screen has a "تصفح أغلفة ومعاينات الـ 17
  مصحفاً" button opening exactly that catalog — the same screen flagged in
  the warning above P3-20 as strong evidence of QuranFlash-derived scanned
  cover art. This project's onboarding has no such button and no cover
  images at all, by design.
- **Downloading is offered, not forced** — both are real background jobs
  a user can equally start later from Downloads, so the closing "ابدأ
  رحلتك الإيمانية 🚀" CTA never blocks on either finishing; it just marks
  `onboarding.completed` (`SharedPreferences`) and replaces the route with
  `AppShell`.

**A real bug found live, not by static review:** the screen was first
built wrapped in a hardcoded `Directionality(textDirection: TextDirection.rtl)`
— correct for `book_text_reader_screen.dart`/`quran_screen.dart` (always-
Arabic *content* regardless of UI language) but wrong here, since this
screen's chrome should follow the ambient locale like the rest of the app.
Confirmed live on the emulator (device/app locale = English): the English
subtitle rendered with its trailing period bidi-flipped to the front, and
"0 / 604 pages saved" rendered reversed as "pages saved 604 / 0". Fixed by
removing the hardcoded `Directionality` entirely (letting it inherit the
real ambient direction); both strings confirmed correct after the fix.

`flutter analyze`/`flutter test` clean (translation parity included, +5
new `onboarding.*` keys × 5 locales). **Live-verified on `emulator-5554`,
device locale English:** fresh install → notification permission →
onboarding renders correctly (title/subtitle/CTA in proper LTR order);
selecting a different edition (Hafs → Shubah) moved the gold selection
ring correctly; tapping Download on Shubah started a real prefetch job
("Downloading 1 / 604" with working Pause/Cancel); scrolled to the
recitation section — reciter dropdown showed مشاري العفاسي, the card
showed real "0 / 114 Surah" status; tapped the CTA — navigated to the
real `AppShell` Home screen. **Force-stopped and relaunched the app** (a
true cold process start, confirmed via `ps -A` showing no running
process beforehand) — onboarding was correctly **skipped**, landing
directly on Home, confirming the `onboarding.completed` flag persists and
is honoured on subsequent launches.

## P3-22 — Home: the animated interactive prayer card (frame-verified target)

Supersedes/completes the open half of **P3-4**. Exact target now confirmed
from the video, not just `ref_home.jpg`'s static mock: live `HH:MM:SS`
clock ticking every second, "الصلاة القادمة: <name>" + "متبقي X ساعة و Y
دقيقة" pill, a location line, then 4 coloured chips (one colour per prayer,
matching the video's palette) with a "القادمة" badge on the next one.

**✅ Built.** `_PrayerTimesTable` in `home_screen.dart` rebuilt to this
exact spec: a fixed dark/teal/violet gradient card (same family as
`_HeaderCard`), a live per-second `HH:MM:SS` clock (Home's own `_clock`
`Timer` changed from a 30s to a 1s tick for this), the existing
`_remaining()`/`nextPrayer()` logic reused for the countdown pill, and 6
colour-coded `_PrayerChip`s (kept all 6 prayers, not just 4 — the video's 4
looked like whatever fit that scroll position, not a deliberate cut) in a
horizontally scrollable row with a glow + "القادمة" badge on the next one.
`flutter analyze` clean, `flutter test` 15/15.

**Real location line, added properly, not stubbed:** `cityName` already
existed on `PrayerTimes` but was **always empty in practice** —
`location_service.dart` hard-coded `locality: null`, no reverse-geocoding
ever ran. Added the `geocoding` package (the platform's own Geocoder, no
API key) and a real `_reverseGeocode()` call, threaded a new `countryName`
field through `PrayerTimes`/`PrayerTimesService`/`PrayerController` so the
line can read "city، country" like the video's "دبي، الإمارات العربية
المتحدة" — best-effort, never a fake city if geocoding fails.

**Verification, precisely:** live-tested on `emulator-5554` through a full
install → grant notifications → grant location ("While using the app")
flow. The **honest fallback path renders correctly** — "فعّل الموقع لحساب
مواقيت صلاتك" shows with no crash, confirmed on screen. The **populated
path (real prayer times + clock + chips) was not visually confirmed this
session** — `Geolocator.getCurrentPosition()` never resolved on this
specific AVD despite location permission genuinely being granted
(confirmed via `dumpsys package`) and `adb emu geo fix` being sent
repeatedly; `dumpsys location` showed the "gps" provider's last fix frozen
on a stale reading from an earlier, unrelated session and never updating —
this looks like a Play-Store-image emulator quirk (classic console GPS
injection not reaching the Fused Location Provider on this image), not a
bug in `LocationService`/`PrayerController`, which are simple, already-
analyzed-clean code following the exact pattern `_HeaderCard` already uses
successfully. Says so plainly rather than claiming a verification that
didn't happen — needs either a real device or a differently-configured
AVD/Extended-Controls location fix to finish confirming.

## P3-23 — Icon replacement, round 2

Owner says the P3-1 icon is "زفت سيئة" (bad) and will send a new reference
image to copy/adapt. **Blocked on that image** — do not touch the icon
again until it arrives, guessing a second time without a reference is not
useful.

## P3-24 — Book download button ✅ DONE, live-verified

`DownloadManager.cancel(id)` already existed but nothing in
`library_screen.dart` called it — while a book was downloading, `_BookCard`
showed only a progress bar and a percentage, no button at all (not even a
disabled one), matching the report exactly. Added a "إلغاء" `TextButton.icon`
(`Icons.stop_circle_outlined`) next to the percentage, calling
`DownloadManager.instance.cancel(dlId)` — same visual pattern
`downloads_screen.dart`'s mushaf/recitation tiles already use, reused
rather than inventing a new one, `common.cancel` (existing key, no new
translations needed). `flutter analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`:** started downloading رياض الصالحين
(15.8 MB, image edition), confirmed the "إلغاء" button appeared next to
the in-progress "…" while the progress bar filled; tapped it — download
stopped immediately, the row cleanly reverted to the normal "تنزيل" button
(not stuck in a half-cancelled state).

## P3-25 — Downloads "نظرة عامة" rows ✅ DONE, live-verified

Two different destinations, since مصاحف/تلاوات and حديث/كتب aren't
actually the same *kind* of "section":

- **مصاحف/تلاوات** have their own tab right here on `DownloadsScreen`
  itself — tapping the row calls `DefaultTabController.of(context)
  .animateTo(1|2)`, a purely local switch.
- **حديث/كتب** are managed on a completely different screen
  (`LibraryScreen`, its own bottom-nav tab) — `DownloadsScreen` isn't
  where you'd ever download a book or the hadith DB from in the first
  place, so "jump to its section" has to mean leaving this screen. Tapping
  the row pops `DownloadsScreen` and sets **two** provider requests: the
  existing `requestedTabProvider` (bottom-nav → Library, index 3) and a
  new `requestedLibraryTabProvider` (`LibraryScreen`'s *own* inner
  `TabController` → الكتب/الحديث). `LibraryScreen` converted from
  `DefaultTabController` to an explicit `TabController` so it has
  something to drive from outside itself — same two-provider seam
  documented in `tab_request_provider.dart`, mirroring the P3‑6 khatma-nav
  fix's pattern exactly, not a new mechanism invented from scratch.
  الأذان's row has no download-browsing UI anywhere in the app to jump
  to yet, so it stays inert rather than pointing at a destination that
  doesn't exist. `flutter analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`:** from Settings → التنزيلات → نظرة
عامة — tapping "التلاوات" switched straight to the التلاوات tab in
place (no navigation, confirmed by the reciter picker + surah list
appearing instantly); tapping "الكتب" popped back out and landed on
`LibraryScreen`'s الكتب المتوفرة tab; tapping "الحديث" did the same but
landed on الحديث instead, confirming `requestedLibraryTabProvider`
actually drives the right inner tab and not just "whichever library tab
happened to be open."

## P3-26 — Persistent prayer notification — owner still reports it absent

Repeated again in this message. P3-13's investigation this session found
and removed a real dead second implementation and confirmed the live
`prayer_status_notification.dart` path matches what was emulator-verified
working before — **still genuinely needs the real device** to diagnose
further; nothing new to try without it. Keep flagging until a real-device
logcat session happens.

## P3-27 — "Download full recitation" card ✅ DONE, live-verified

Confirmed the assumption first: التلاوات downloads only ever offered one
surah at a time (a `ListView` of 114 individually-downloadable tiles),
exactly as suspected — no bulk action existed. Added
`_FullRecitationCard` directly under the reciter dropdown (`downloads_
screen.dart`), showing real "`done` / 114 سورة" status computed from the
actual on-disk files (`AyahAudioService.surahProgress`, not a guess), a
تحميل button that walks all 114 surahs **sequentially** (kinder to the
device/network than 114 at once) reusing `downloadSurah`'s own per-ayah
resume logic — so re-running it after a partial/cancelled run only
downloads what's still missing — and a cancel button that stops the loop
and immediately cancels whatever surah was mid-download. `flutter analyze`
clean, `flutter test` 15/15.

**A real staleness bug was found and fixed during this build, not left
for later:** the 114 individual `_SurahAudioTile`s each check their own
on-disk state exactly once, in `initState` — after a bulk run changes
files out from under them, they'd keep showing "not downloaded" until the
user did something to force a remount. Fixed with a `_generation` counter
in `_RecitationsTab`, bumped once the bulk run finishes/cancels and folded
into each tile's `ValueKey`, forcing them to remount and re-check reality.
+1 key (`downloads.download_all_recitation`) × 5 locales.

**Live-verified on `emulator-5554`:** picked مشاري العفاسي, confirmed the
card correctly showed "0 / 114 سورة" (not "0 / 0" or a placeholder),
tapped تحميل — button flipped to a stop icon, progress advanced through
سورة الفاتحة then partway into سورة البقرة (286 ayahs, so genuinely slow —
expected); tapped cancel — card reverted to تحميل showing "2 / 114 سورة",
**and the الفاتحة tile below immediately showed a real green "جاهز للعمل
بدون إنترنت" checkmark** (proving the generation-remount fix actually
works, not just that the card's own counter incremented), while سورة
البقرة's tile showed its own genuine partial progress bar rather than
resetting to blank.

## P3-28 — Mushaf edition thumbnails on their cards

Owner wants a cover thumbnail per mushaf edition card. **Must be an
originally-produced or clearly-licensed image per edition** (e.g. a
generated cover using this project's own palette/typography, or a
verified-PD/CC0 scan) — **not** sourced by searching for "the" cover image
of each edition online without checking, which is exactly the path that
produced the QuranFlash contamination flagged above. Not started; needs a
sourcing pass with the same rigor §5.7/P2-4 already established, per
edition, before any image ships.

## P3-29 — Book text reader: nav part ✅ DONE + visual part ✅ DONE, both live-verified

`book_text_reader_screen.dart`'s navigation half is now fixed — the two
chevron page-turn buttons are gone, replaced by **swipe** (same
direction-aware logic as `azkar_section_screen.dart`/P3-11: a rightward
swipe is "forward" under RTL) plus a **fast-jump slider** in the bottom bar
for scrubbing across a whole book in one drag (a real "شريط تمرير سريع",
exactly what was asked for) — the typed goto-page dialog is kept underneath
it as a precise alternative. New `library.text_swipe_hint` key, +1 key × 5
locales. `flutter analyze` clean, `flutter test` 15/15.

**A real bug was found and fixed during live verification, not by static
review alone:** the first implementation used a `GestureDetector`'s
`onHorizontalDragEnd` wrapped around the page body — analyze-clean, but on
the emulator the swipe silently did nothing. Root cause: the page body sits
inside a `SelectionArea` (existing selectable-text feature), whose own drag
recognizer competes for the same gesture-arena slot as the outer
`GestureDetector` and was winning it, so the swipe handler never fired.
Fixed by switching to a raw `Listener` (`onPointerDown`/`onPointerUp`)
instead — `Listener` doesn't enter the gesture arena at all, so it always
sees the pointer stream regardless of what `SelectionArea` claims. This is
exactly the kind of defect the project's "must live-verify, not just build"
rule exists to catch.

**Live-verified on `emulator-5554`:** downloaded "الصمت وآداب اللسان" (a
small نص-only book), opened it, confirmed the arrows are gone and the swipe
hint text renders correctly; a rightward `adb shell input swipe` moved
page 1→2, a leftward one moved back 2→1 (direction-aware, confirmed both
ways); dragging the slider thumb from position 1 to 546/787 jumped straight
there in one motion — content, breadcrumb section title ("باب حفظ اللسان
وفضل الصمت" → "باب ذم الكذب"), and the printed-page label all updated
correctly together. One testing-only gotcha worth recording: an `adb`
swipe starting within Android's system edge-gesture zone (roughly the outer
~60px of a 1080px-wide screen) gets intercepted as an OS back-gesture before
it ever reaches the app — not a bug, just something to avoid when scripting
future slider/edge-swipe tests on this AVD.

**Visual redesign — ✅ DONE, live-verified this session.** The owner resent
the al-Maktaba al-Shamela reference (`design_refs/ref_shamela_reader.jpg`,
saved immediately this time) with "shamela style but follow our theme
coloring" — adapt the layout, not the blue accent color. Built:

- **A new captioned toolbar row** (`AppBar.bottom`, same pattern as the
  Quran tab's P3-34 toolbar) with 6 actions matching the reference's 6-icon
  row, each backed by a real feature — no decorative icon that doesn't do
  anything:
  - **حجم الخط** (font size) — opens a small sheet with A‑/A+ and a live
    percentage, replacing the two always-visible `AppBar` buttons the nav
    redesign had used as a placeholder.
  - **لون الخط** (font color, new) — a sheet offering 3 real reading-ink
    choices (Default / Warm sepia / High contrast), each carrying separate
    light- and dark-theme colors so the choice stays readable against
    whichever paper tone the current theme is showing (a single fixed
    color risked landing unreadable in the other theme).
  - **التشكيل** (diacritics toggle, new) — a new exported
    `stripTashkeelForDisplay()` in `arabic_normalize.dart` (reuses the same
    harakat range `normalizeArabic` already strips for search, but
    deliberately touches only marks, never letterforms, since a display
    toggle must never silently rewrite which letter is on the page).
    Quoted Quran ayahs (`para.kind == 'aya'`) are exempt — always shown
    fully vocalized, same as everywhere else in the app.
  - **بحث** (search) — the existing in-book search, standing in for the
    reference's "التعليقات" (comments) slot: this app has no comments
    feature to back that icon honestly, so it was repurposed rather than
    built as a fake.
  - **الفهرس** (index) — the existing TOC/bookmarks drawer.
  - **إشارات مرجعية** (bookmarks) — the existing per-page bookmark toggle.
- **A shared `ToolbarAction` widget** (`core/widgets/toolbar_action.dart`,
  new file) extracted from `quran_screen.dart`'s private `_ToolbarAction`
  so both screens use the exact same icon+caption+press-animation look,
  with an added `active` bool (gold highlight) for the two toggle-style
  actions (diacritics, bookmark) that didn't exist in the original P3-34
  version.
- **Paper-toned reading surface**: the breadcrumb strip, page body,
  provenance strip and bottom nav bar now share the same
  `AppColors.paper`/`AppColors.nightSurface` (light/dark) pair
  `MushafTextPage` already uses for Quran text-reading mode, with a thin
  gold hairline border — "our theme coloring", not Shamela's blue.
- **"الجزء" (volume/part) was deliberately NOT added** — `book_text.dart`'s
  data model (`BookText`/`BookSection`/`BookPara`) carries no volume/juz
  field at all, and fabricating one would violate rule 1 (no mock data).
  The bottom bar keeps its existing real page-number + page-count +
  typed-goto affordances instead of inventing a fake "الجزء" pill.
- **AppBar header cleanup**: the old 3 bare `actions:` icons (font-/font+/
  search) are gone, replaced by the toolbar row; the "Text source" icon
  that briefly replaced them was then removed too (the existing provenance
  strip at the bottom already opens that same sheet, so a second entry
  point was just clutter the reference's own clean header doesn't have).
  **A real Flutter gotcha found live, not by static review:** passing
  `actions: const []` to suppress Flutter's automatic `endDrawer`-toggle
  hamburger button did *not* work — `AppBar.build()`'s actual check is
  `widget.actions != null && widget.actions!.isNotEmpty`, so an empty (but
  non-null) list still falls through to the auto-insert branch, confirmed
  by seeing the hamburger icon live on the emulator after that first fix.
  The correct fix is `automaticallyImplyActions: false`, verified live
  afterward — header now shows only the title and back arrow.
- +6 translation keys × 5 locales (`text_font_size`, `text_font_color`,
  `text_tashkeel`, `text_ink_default`, `text_ink_sepia`, `text_ink_contrast`).

`flutter analyze` clean (whole project), `flutter test` 15/15 (translation
parity included). **Live-verified on `emulator-5554`** with a freshly
downloaded "رياض الصالحين" text edition: all 6 toolbar actions tested by
hand — font size sheet (100%→120% live, A+/A− both work), font color sheet
(Warm sepia applied instantly, sheet auto-closes on pick, checkmark tracks
selection), diacritics toggle (harakat visibly stripped/restored, gold
highlight tracks state), search sheet (opens, autofocused), index drawer
(opens, shows the 387-entry TOC plus a live bookmark chip), bookmark toggle
(icon+label turn gold). Confirmed the reading surface, breadcrumb,
provenance strip and bottom bar all render in the paper/gold theme instead
of the old neutral grey. Confirmed the header shows only title + back
arrow after the `automaticallyImplyActions` fix (first attempt with
`actions: const []` was caught live, not assumed correct from analyze).

## P3-30 — Azkar / Tasbeeh "still old style" — likely stale, already shipped this session

Owner says these still look old and references the same images already
matched. **This was almost certainly written/queued before he saw the
batch-2 APK** (`phase3-batch2-2026-09-03`, released *after* P3-11/P3-12
were built and live-verified on the emulator this same session). Action:
do not rebuild blind — ask him to confirm on the batch-2 (or later) APK
specifically before assuming this is a real remaining gap.

## P3-31 — Add a "تفسير" download section: ~20 named tafsir sources

New downloads category, tafsir sources named explicitly: ابن القيم (الفوائد
already in Library, but he may mean his tafsir directly — clarify), ابن
الجوزي, القرطبي, البغوي, السعدي, ابن كثير, "وغيرهم" (~20 total, other
famous ones — candidate research set: الطبري, الشوكاني (فتح القدير),
أبو السعود, النسفي, الآلوسي (روح المعاني), الرازي, ابن عطية,
الواحدي, الثعالبي, الخازن, الطبراني, البيضاوي, الجلالين (already have),
الطنطاوي, الشعراوي, سيد قطب (في ظلال القرآن) — needs the same licence-check
discipline as every other content source before any of it ships (public
domain author-death-date basis, or an explicit free-distribution licence —
several of these, e.g. الشعراوي/سيد قطب, are 20th-century authors and need
individual copyright verification, not an assumption). Not started — a real
research pass (Shamela sourcing + licence check per title, same rigor as
P3-15's library books) is the prerequisite before any build work.

## P3-32 — Text-mode mushaf: ayah-end marker ✅ DONE, live-verified

Root cause: the marker was a `WidgetSpan` using
`PlaceholderAlignment.middle`, which centers it within the *whole line's*
ascent+descent box — for `AmiriQuran`, whose metrics reserve a lot of
headroom above the baseline for tashkeel, that box sits noticeably higher
than the base letters' actual visible body, so the marker read as sitting
low relative to the letters next to it. Switched to
`PlaceholderAlignment.baseline` (`baseline: TextBaseline.alphabetic`) in
`mushaf_text_page.dart`, which pins the marker to the alphabetic baseline
instead — a stable reference the base letters actually sit on, independent
of how much extra headroom the font reserves for diacritics. `flutter
analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`:** opened the text-mode mushaf on
سورة الفاتحة, cropped and zoomed screenshots of both the first and second
lines (via a small Pillow script, not just eyeballing the full screenshot)
— all 3 rosette markers visible sit centered on the letter-body height,
consistent line to line, clearly not "dropped low" any more.

## P3-33 — Ayah sciences sheet tafsir tab ✅ DONE, live-verified (dropdown part)

Reversed P2-8 #3's multi-tafsir compare/stacked-list view entirely —
`_TafseerTab` rewritten from scratch to exactly mirror `_TranslationTab`'s
already-established pattern just below it in the same file: one persisted
dropdown, one source shown at a time. New
`selected­TafseerSourceProvider` (`tafseer_source_provider.dart`,
identical shape to `translation_lang_provider.dart` — same
`StateNotifier` + `SharedPreferences` persistence pair), picks from
whichever of `SciencesRepository.tafseerSources`'s 3 bundled sources
(التفسير الميسّر / الجلالين / القرطبي) actually have text for the current
ayah, falling back to the first available one if the persisted choice
doesn't cover it. The now-dead compare-view toggle and its 2 translation
keys were removed outright (`tafseer_compare_view`/`tafseer_list_view`, ×5
locales) rather than left unused. `flutter analyze` clean, `flutter test`
15/15.

**Live-verified on `emulator-5554`:** opened سورة الفاتحة's ayah 2 sheet,
confirmed the Tafsir tab shows one dropdown ("Tafsir: التفسير الميسّر")
and one text card, no compare toggle anywhere; opened the dropdown —
confirmed all 3 real sources listed; picked تفسير القرطبي — dropdown and
card both updated together to the (correctly much longer, real classical)
Qurtubi text, single source only.

**Deliberately not done — the "if not downloaded, show a download
button" half:** there is currently **no per-source tafsir download
mechanism at all** — all 3 bundled sources ship together in
`quran_sciences.db` with no concept of a "missing" one to offer a
download for. Building a fake download button with nothing real behind it
would violate rule 1 (no fabricated affordances). This slots in naturally
once **P3-31** (the ~20-source tafsir download section, still needing its
licence-research pass first) introduces real per-source availability —
tracked there, not invented here ahead of it.

## P3-34 — Text-mode mushaf: toolbar redesigned ✅ DONE, live-verified; scroll re-confirmed fine; "speed control" needs owner clarification

- ✅ **Toolbar icons redesigned with captions + a tap animation.** The
  Quran tab's `AppBar` used to hold up to 8 plain, unlabelled
  `IconButton`s in `actions:` (font ±, search, surah list, juz, jump-to-
  page, edition picker, mode toggle). Moved into `AppBar.bottom` instead
  of `actions:` as a new captioned row (new `_ToolbarAction` widget: icon
  + a short label underneath, using the exact same string each action
  already had as its tooltip — nothing new translated, just made
  visible), with a small scale-down press animation
  (`AnimatedScale`/`GestureDetector`). Deliberately placed in `bottom:`
  rather than widened `actions:` — that spans the **full** screen width
  independent of the title, so with 6-8 captioned actions it can never
  overflow-crash on a narrow phone; wrapped in
  `SingleChildScrollView(scrollDirection: Axis.horizontal)` so it simply
  scrolls instead. `flutter analyze` clean, `flutter test` 15/15.
- ✅ **Scroll re-verified, not regressed.** `mushaf_text_page.dart` is
  still `SingleChildScrollView`-based, confirmed both by reading the code
  and by direct use during this same session's P3-32 work (scrolled
  through and zoomed into different lines of a real page). The "no
  scrolling at all" part of the report does not reproduce as filed.
- **"Scroll-speed control" — not built, needs the owner's own
  clarification before guessing further.** Text mode has no auto-scroll
  today (it's plain manual finger-scroll), so it's unclear whether this
  means a teleprompter-style auto-advancing scroll (a genuinely new
  feature, not a fix) or something else entirely — building either
  without knowing which risks wasted work or the wrong feature.

**Live-verified on `emulator-5554`:** opened the Quran tab in text mode —
all 8 captioned actions render and read correctly ("Smaller/Larger text",
"Thematic Search", "Surahs", "Juz", "Jump to", "Mushafs", "Mushaf mode"),
scrolled the row horizontally to confirm nothing is cut off/lost; tapped
"Mushaf mode" — correctly switched to the real image mushaf (a genuine
page render, not a placeholder), the caption itself flipped to "Text
mode" live, and the two font-size actions correctly disappeared from the
row (they're text-mode-only) — confirming the mode-dependent conditional
logic still works correctly inside the new widget structure.

## P3-35 — Ayah card: one play/stop toggle button ✅ DONE, live-verified

`ayah_sciences_sheet.dart`'s `_Header` had two separate `IconButton`s
(play, stop); collapsed into one `StreamBuilder<bool>`-driven toggle that
flips its icon/tooltip/action between play and stop (matches the tasbeeh
circle / khatma "read today" pattern of one affordance that toggles
state). New `AyahAudioService.isPlayingStream` (`Stream<bool>`, wraps the
existing `playerState` stream) keeps `package:just_audio`'s `PlayerState`
type out of the widget file. Because it's driven by the service's actual
playback stream rather than local per-button state, it also correctly
reflects audio started elsewhere in the same sheet (e.g. the "repeat"
menu action). `flutter analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`:** opened سورة الفاتحة in text mode,
tapped ayah 1 to open the sheet — one button, play icon. Tapped it:
icon flipped to a filled stop-square (confirmed both visually and via
`uiautomator`'s content-desc, which read "إيقاف"/stop) while audio played.
Tapped again: flipped back to the play icon, audio stopped. Single button,
both directions confirmed.

## P3-36 — Home: hadith reroll ✅ DONE, live-verified

Root cause found by reading `daily_hadith_provider.dart`, not by guessing:
`reroll()` set `state = const AsyncLoading()` before picking a new hadith,
and the card's `AsyncValue.when()` reacted to that by swapping the *entire*
card (several lines of hadith text, chip, etc.) for a 60px spinner box for
the moment the pick took, then back — on a scrolled-down Home that height
swing shifted everything below the card, which read as "the screen jumps
to the top". Fixed at the root: `reroll()` no longer emits an intermediate
loading state (`_pick()` is a fast local SQLite lookup — there's nothing
worth showing a loading state for), so the card's layout never changes
size during a reroll. `_PickedHadith` converted to
`ConsumerStatefulWidget` with its own small `_rerolling` flag purely for
the refresh button's own icon (swaps to a tiny in-button spinner while
awaiting), completely decoupled from the provider's state and the card's
size. `flutter analyze` clean, `flutter test` 15/15.

**Live-verified on `emulator-5554`:** downloaded `hadith.zip`, scrolled
Home down until the (long, near-max-height) hadith card was fully in view,
tapped "حديث آخر" and screenshotted immediately after — the hadith text,
book, and grade all changed completely (سنن النسائي #5012 → جامع الترمذي
#544) while the visible scroll position stayed pixel-identical (same cards
visible above/below, no jump).

## P3-37 — App display name follows device system language ✅ DONE, live-verified

Both halves, confirmed independently:

- **OS-level launcher label:** wasn't wired at all —
  `AndroidManifest.xml`'s `android:label` was a hardcoded literal string
  (`"Rafeeq AlDarb"`, no hyphen — also inconsistent with `app.name` in the
  translation JSONs, which all spell it "Rafeeq Al-Darb"), not a
  `@string/app_name` resource reference, so there was no `strings.xml` at
  all to pick up the OS's own language. Added
  `res/values/strings.xml` (default/fallback — "Rafeeq Al-Darb", matching
  en/es/ru/pt's `app.name` exactly since none of them actually translate
  the proper noun) and `res/values-ar/strings.xml` ("رفيق الدرب", byte-
  verified against `ar.json`'s `app.name` via a Python script rather than
  eyeballing it), then pointed the manifest at `@string/app_name`. No
  values-es/ru/pt needed — they already resolve to the same default file.
- **In-app first-run locale:** `main.dart`'s `EasyLocalization` had
  `startLocale: const Locale('ar')` hardcoded, so a fresh install always
  opened in Arabic no matter the device's language — this was the part
  actually missing, as suspected. Removed it entirely: omitting
  `startLocale` makes easy_localization auto-detect the device's own
  locale on the very first launch (matched against `supportedLocales`,
  falling back to `fallbackLocale` for any unsupported device language),
  and `saveLocale: true` (already set) persists whatever gets picked from
  then on — this only changes the *very first* launch's default.

Verified with a real `flutter build apk --debug` (not just `flutter
analyze`, which can't see manifest/resource errors) since this touches
native Android resources. `flutter analyze` clean, `flutter test` 15/15.

## P3-38 — Round-3 feedback: app icon v2, Azkar/Tasbeeh split into separate tabs, splash+app-store frames ✅ DONE, live-verified

Owner sent a new set of real references (`design_refs/round2_2026-09-04/`
— 4 images + a video, 25 frames extracted for review) plus a follow-up
clean icon photo, with four concrete asks:

1. **"Use the video as splash screen, first frame or two for the app
   store."** Reviewed all 25 extracted frames carefully. The video's own
   splash frames (girih lattice + gold circle + the **old mosque icon**)
   match what P3-20 already built from the earlier video — no new
   splash-layout change needed. What *did* change: once the new app icon
   (below) was live, `SplashScreen`'s own badge picked it up automatically
   (it reads the same `assets/branding/app_mark.png` the launcher icon is
   built from), so a fresh screenshot of **our own real splash** —not the
   old app's mosque-icon frame — was saved as the app-store candidate:
   `design_refs/app_store_candidates/splash_frame_1.png`, captured live
   from `emulator-5554`, not a mockup.
2. **Tasbeeh style** — already matched (P3-12, confirmed by the owner
   round 2). Re-verified live in this pass, no changes needed.
3. **Hadith card style** — already done earlier this same round (see
   P3-4's writeup above, the `_OrnateFrame` gold-corner-flourish card).
4. **"Separate azkar from misbha, put it in the bottom nav bar."** The
   owner's real screenshots of the old app's own bottom nav
   (`ref_azkar_hub_v2.jpg`/`ref_tasbeeh_v2.jpg`) clearly show **7** tabs —
   المسبحة as its own tab, not a sub-tab under الأذكار like this app had
   it. Split `azkar_screen.dart`'s `DefaultTabController`/`TabBarView`
   apart: `AzkarScreen` is now just the sections grid with its own
   `AppBar`, and a new `TasbeehScreen` (`tasbeeh_screen.dart`) carries the
   whole P3-12 counter UI unchanged. The shared reminders/haptics settings
   sheet (used by both) was pulled into its own
   `azkar_settings_sheet.dart` (public `AzkarSettingsButton`) so neither
   screen needs a second copy. `AppShell` gained the 7th
   `NavigationDestination` (∞ `Icons.all_inclusive`, between الأذكار and
   المكتبة); `AppTab` (`tab_request_provider.dart`) got `tasbeeh` inserted
   the same safe, named-constant way P3-16 already established — every
   other `AppTab.*` call site (`downloads_screen.dart`, `khatma_screen.dart`)
   kept working unchanged since they reference the names, not raw ints.
   +1 key (`nav.tasbeeh`) × 5 locales.

**App icon v2, genuinely redesigned — a fifth concrete ask that arrived
mid-turn.** The owner first sent a blurry install-screen video frame that
looked like a different icon; rather than guess-replacing an icon he'd
explicitly confirmed earlier the same day, asked directly — he chose to
send a clean reference photo instead. That photo (173×228, a phone
home-screen crop — still not clean vector-source quality, but clear
enough to read composition/palette) showed a moodier "cosmic swirl"
version of the same crescent+book mark: a blue-white glow core and a warm
gold wisp inside the crescent (rather than the old flat single-direction
gradient), and the book itself in cool blue tones instead of solid gold.
Rebuilt `assets/icon/src/icon_full.svg`/`icon_fg.svg` as fresh vector art
matching that composition (same reproducible pipeline P3-1 established:
hand-authored SVG, headless-Chrome render, `flutter_launcher_icons`) —
not a pixel-crop of the low-res source, which wouldn't have produced a
usable 1024² asset. Added a `crescentCore`/`crescentWisp` radial-gradient
overlay pair, clipped to the exact same crescent path already used for
the base fill, so the glow/wisp read as texture *inside* the moon rather
than a halo floating outside its silhouette. Also refreshed
`assets/branding/app_mark.png` (the splash screen's own icon copy, P3-20)
so it doesn't go stale relative to the real launcher icon.

**A real bug found live, twice, while regenerating the icon:**
`icon_fg.svg`'s existing comment (`... this with --default-background-color=...`,
present before this session's edit) contains a literal double-hyphen — SVG
is XML, and XML forbids `--` anywhere inside a comment body. Chrome's
headless screenshot renderer doesn't render the SVG at all when this
happens — it renders an **HTML error page instead**, which got silently
written to `icon_fg.png` as if it were a real icon until viewed by hand.
This is the same bug class as the `launch_background.xml` fix earlier in
this session, in a different file. Fixed by rewording the comment to
avoid the literal sequence — caught a **second** instance of the exact
same mistake immediately after, in the very sentence added to explain the
first one (the fix's own doc comment quoted `"--"` as an example,
recreating the violation it was describing). Both PNGs regenerated clean
after; alpha sanity-checked on `icon_fg.png` per the README's own
prescribed check (`A=0` at a transparent corner pixel, confirmed via a
`System.Drawing.Bitmap` read).

`flutter analyze` clean, `flutter test` 15/15. **Live-verified on
`emulator-5554`** across a full fresh-install cycle: the new icon renders
correctly at native-splash time (the centred `@mipmap/ic_launcher`, before
Flutter even attaches), inside `SplashScreen`'s own glow badge, and in the
regenerated `mipmap-xxxhdpi/ic_launcher.png` directly. The 7-tab bottom
nav fits without truncation or overflow at this device's width; tapped
into both الأذكار (sections grid, own `AppBar`, no leftover `TabBar`) and
المسبحة (full counter UI, own `AppBar` + settings gear) and confirmed both
work as fully independent screens, not remnants of the old tabbed
structure.

**Follow-up in the same round: "make yourself a splash screen inspired by
the video."** The owner's phrasing was a deliberate nudge away from a
literal reproduction — re-read `SplashLattice`/`SplashScreen` with that in
mind and added three things the reference frame itself doesn't have,
rather than just re-confirming the existing match:
- A second, smaller girih rosette layer counter-rotating against the
  first (`_paintRosette`, called twice with different radius/angle/point-
  count) — a real girih mandala is traditionally built from overlapping
  polygons, not one flat ring, so this reads closer to the genre the
  reference is itself drawing on rather than to the reference frame
  literally.
- A huge, very soft echo of **this app's own icon-crescent silhouette**
  breathing in the backdrop — the exact two-arc construction
  `icon_full.svg` uses, just enormous, blurred, and low-opacity, tucked
  into a back corner (`_paintCrescentEcho`, `BlendMode.dstOut` cutout
  rather than a combined `Path`, since this only needed a one-off soft
  cutout). Ties the backdrop to the app's own new icon (P3-38 above)
  instead of being generic atmosphere.
- A staggered entrance: the video's own splash frame is static —
  everything present in frame one. Added a second, one-shot
  `AnimationController` (`_intro`, 900ms) driving three overlapping
  `Interval`s so the badge scales+fades in first (`Curves.easeOutBack`),
  the app name rises+fades in a beat behind it, and the tagline trails
  last — each via a small reusable `_RiseIn` (fade + upward settle)
  wrapper. Reduced motion (system setting or the in-app toggle) skips this
  and the badge/text simply appear fully formed, same honesty rule the
  backdrop's own looping animation already followed.

**A real timing-investigation, not a bug, worth recording:** confirming
the entrance animation visually by screenshotting mid-splash proved
genuinely difficult — `adb shell am start`'s own cold-start latency to
Flutter's first frame varied between roughly 0.3s and 2s+ run to run on
this AVD, so fixed-delay screenshot polling kept landing either on the
native pre-Flutter icon or already past the splash, never inside its
~1.9s live window. Confirmed the *timing logic itself* was correct first
via instrumented `debugPrint(DateTime.now())` calls through `flutter run`
(`initState` → `_proceed` measured at 1932ms against a coded 1900ms hold,
well within normal `Future.delayed` scheduling overhead — temporarily
added, verified, then removed before shipping), then confirmed the
*visual result* by temporarily extending the hold to 9 seconds for one
screenshot (reverted to 1900ms immediately after) rather than continuing
to gamble on timing. That screenshot also caught a real, separate mistake
along the way: `TaskStop` on a background `flutter run` session doesn't
reliably kill the app process on the device (`flutter run`'s own "detach"
semantics leave it running) — several `adb shell am start` calls were
silently resuming that stale, already-past-splash process instead of
cold-launching the newly installed APK, printing an easy-to-miss "Activity
not started, intent has been delivered to currently running top-most
instance" warning each time. Confirmed via `adb shell "ps -A" | grep
rafeeq` before relying on any subsequent launch again — an `am
force-stop` first is now the safer habit after any `flutter run` session
on this project, not just before a fresh install.

`flutter analyze` clean, `flutter test` 15/15. **Live-verified on
`emulator-5554`:** the fully-settled splash (screenshotted via the
temporary extended hold, confirming the real animation's *end state* since
the live 1.9s window couldn't be reliably screenshotted) shows both
lattice layers, the crescent echo's soft gold glow bleeding through the
girih lines, scattered twinkling stars, and the badge/name/tagline all in
their final settled position — confirmed the real 1900ms build still
correctly proceeds to onboarding/Home afterward, unaffected by the
temporary-hold detour.

**Live-verified on `emulator-5554`:** this AVD's actual system locale is
`en-US` (`adb shell getprop ro.product.locale`) — a fresh install (after
`adb uninstall`) opened the whole app in **English** by default, no
locale ever chosen: Home screen showed "Welcome" / "Quran Khatma" /
"Sunnah of the Surahs (Day & Night)" / "Hadith of the Day", LTR-mirrored
bottom nav (Home on the *left* this time, correctly following LTR), dates
in English ("Sep 3, 2026"). The location permission dialog itself also
read "Allow **Rafeeq Al-Darb** to access this device's location" —
confirming the manifest's `@string/app_name` resolved correctly (and
picked up the corrected hyphenated spelling, not the old hardcoded one).
**Note for future sessions on this AVD:** because `saveLocale: true`
persists the auto-detected choice, a fresh install here will keep opening
in English (matching this AVD's real system locale) unless the app's own
language switcher is used — that's the fix working as intended, not a
regression from the rest of this session's Arabic-default testing.

## P3-39 — Round-4 feedback: literal splash video, keystore blocker dropped, cloud cleanup ✅ DONE, live-verified

Owner's message this round was explicit and different in kind from
P3-38's "inspired by" follow-up: **"new video to use as splash screen ...
and new icon also,"** with the actual files placed at `E:\New folder` (a
10s/720×1280/24fps MP4 and a high-quality circular icon-badge PNG), plus
two unrelated asks — drop the release-keystore blocker (personal-use app,
no public release planned for now) and delete unused
Cloudflare/Firebase/GitHub resources.

**Splash video — used literally, not reinterpreted.** Unlike the P3-38
video (a mood reference the owner explicitly said to draw *inspiration*
from), this one already carries the app's own exact name
(`رَفِيقُ الدَّرْبِ`) and tagline baked into its final frame — reviewed all
20 extracted frames (`design_refs/gemini_splash_video/frames/`) and
confirmed it's a custom-made splash for this app, not a generic or
competitor asset, so per the owner's literal instruction it's played
as-is rather than re-skinned. Copied to
`assets/branding/splash_intro.mp4` (3.2MB, already covered by the
`assets/branding/` wildcard in `pubspec.yaml`) and wired into
`SplashScreen` via `video_player` (already a dependency, same
muted/cover-fit pattern `AdhanFullScreenScreen` established): plays once,
muted, `BoxFit.cover` via `FittedBox`+`SizedBox`, and calls `_proceed()`
when playback reaches its end (`VideoPlayerController` listener comparing
`position` against `duration`), with a `duration + 2s` `Future.delayed`
safety net in case the completion event is ever missed. A tap anywhere
skips straight past it — the owner didn't ask for this, but a 10-second
clip with no way to skip would be a real annoyance on every cold start,
so it was added as an honest engineering call, not scope creep for its
own sake. The original hand-built girih-lattice + glow-badge design
(`SplashLattice`, `_GlowBadge`, both kept unchanged) is still very much
alive as the fallback shown while the video decodes (typically 1-3s on
this AVD) and if it ever fails to load on some device/codec combination —
verified in one live run, the load actually did fail momentarily and the
lattice/badge/name/tagline rendered correctly in its place before the
video caught up, exactly as designed. Reduced-motion users (system
setting or the in-app toggle) skip both the video and the fallback
entrance animation entirely, unchanged from P3-20/P3-38.

**Icon — the owner's exact photo, unedited (course-corrected live).** The
first attempt at this misread the ask: treated the owner's newest icon
photo (`E:\New folder\1788536019972.png`) as a *reference* and touched up
the existing hand-drawn SVG mark (added a bezel ring, then a metallic
highlight stroke + gold page medallions) rather than using the photo
itself. The owner corrected this directly — "use the ai generated exactly
do not edit it please" — twice, after also flagging that a batch of other
files in `E:\New folder` (4 WhatsApp screenshots + a WhatsApp screen
recording) had been missed entirely on the first pass. Investigating that
recording (a real 24s screen capture of installing/opening an app named
"Rafeeq AlDarb") resolved the ambiguity: it shows the *old* mosque-icon
splash still appearing — a bug report the owner was showing, not new
splash footage to play — and the owner then explicitly confirmed the AI
photo is the real icon and the earlier gemini video is the real splash
video; only the icon *implementation* needed to change, not the video.

Corrected implementation: the SVG-based pipeline (`icon_full.svg` /
`icon_fg.svg` / `icon_bg.svg`) is no longer what generates the launcher
icon. The photo itself, square-cropped to just its circular badge
(dropping the "Rafeeq" wordmark printed below it in the source file,
which was never part of the icon) with **zero other processing** — no
recolor, no recomposite, no added ring — is now `app_icon.png` and
`app_icon_foreground.png` directly; `pubspec.yaml`'s
`adaptive_icon_background` is a plain solid color (`#071625`, the app's
own night-navy) rather than a second synthesized image, so there is
nothing in the shipped icon's visible art besides the owner's own
unedited pixels. `assets/branding/app_mark.png` (the splash badge) is the
same crop, so the in-app badge matches the launcher icon exactly. The SVG
files are kept only as prior source history / a reproducible fallback,
documented as such in `assets/icon/src/README.md` — not the live
pipeline anymore.

**A real crop bug found live, right after shipping.** The first crop
(`(0,0,896,896)`, a plain top-square guess) cut off the bottom of the
circle — the owner caught it immediately from the shipped APK ("you
corped the icon wrongly"). Root cause: the circle isn't actually centered
in the top square of the 896×1181 source photo (it's centered around
`(448, 528)`, not `(448, 448)`) — confirmed precisely by overlaying a
100px coordinate grid on the source image and reading the true circle
bounds off it, rather than guessing again. Fixed by cropping
`(0, 80, 896, 976)`, centered on the circle's real position. **Live-verified
on `emulator-5554`** both times: the first (wrong) crop and the corrected
one, so the fix itself — not just the concept — was confirmed against the
actual home-screen launcher icon and the splash badge, both showing the
full circle with even margins, the exact photo pixels, "EST. 1445" text
and all, not a redrawn approximation.

**Khatma-card redesign (P3-6) — reference received, not yet built.** The
four real competing-app "ختمة" screenshots the owner finally sent
(`design_refs/khatma_app_ref/`, unblocking P3-6 after being stuck all
session for lack of exactly this reference) are saved and reviewed, but
building the actual redesign is tracked as open work below, not silently
dropped — it's a genuinely large feature (a richer daily-portion model
with explicit start/end ranges, plus a whole "ختمة جديدة" creation
wizard), deliberately left for a following session rather than rushed in
alongside everything else this round.

**Keystore blocker dropped.** Every earlier mention of "needs a release
keystore before a real store submission" across `NEXT_SESSION_PROMPT.md`
and the Phase 2 handover docs is no longer a blocker: the owner confirmed
this app is for his own personal use only for now, so there is no public
release to gate on a keystore. Debug/local APK builds (the only kind this
project has ever shipped) need no keystore at all.

**Cloud cleanup — actually executed, not just recommended.** The old
Cloudflare R2 bucket `rafeeq-aldarb-data` (flagged "do not reuse" in
`HOSTING.md` §7 since the session that discovered the contamination) was
listed fresh before touching anything: **254,971 objects, 10.66GB,
newest object dated 2026‑08‑27** — unchanged since the original
investigation, confirmed still unused by the running app (`rafeeq-content`
is the real bucket `AppConfig.contentBaseUrl` points at). Owner confirmed
deletion explicitly given the size; deleted via `scripts/.env`'s existing
R2 credentials (`boto3`, paginated `delete_objects` in 1000-key batches,
then `delete_bucket`) — **all 254,971 objects removed, zero errors,
bucket gone.** Also found and removed `rafeeq_app/.github/workflows/build.yml`
— a GitHub Actions CI config that had genuinely never run once, since
neither this repo nor `rafeeq_app` (which turned out to have its own
nested, remote-less `.git`) has ever had a GitHub remote configured.
`google-services.json` (`rafeeq_app/android/app/`) was found but
deliberately **not** deleted — it's real, but already correctly gitignored
and already documented in `HOSTING.md` as intentionally kept for a future
group-khatma feature that would reuse this same Firebase project rather
than provision a new one; deleting a zero-cost local file to satisfy a
blanket "delete if unused" reading would just create rework later for no
actual cleanup benefit, so this one judgment call is flagged here rather
than silently overridden.

`flutter analyze` clean, `flutter test` 15/15. **Live-verified on
`emulator-5554`** across several fresh cold-starts: confirmed the exact
sequence — fallback lattice+badge visible immediately, the real video
(cloudscape, lightning, the ornate crescent+Quran medallion, gold sparkle
swirl, closing name+tagline card) takes over within a few seconds once
decoded, and playback reaching its end correctly navigates on to
onboarding/Home, matching the ~10s clip length. Also caught and fixed an
unrelated environment issue while debugging build slowness: a
`flutter run` session left over from **two days earlier** in this same
project (the exact `TaskStop`-doesn't-kill-the-process gotcha documented
under P3-38, but this time the leak was on the *host* build tooling, not
the on-device app) was silently burning real CPU the whole time,
independently slowing down every Gradle build in the meantime — killed via
`Stop-Process`, after which a normal debug build returned to its expected
~40s.

## Status table addition

| # | Task | Status |
|---|---|---|
| P3-20 | Splash screen, restyled (new art) | ✅ **done, live-verified** — native splash icon + animated Flutter `SplashScreen` (girih lattice, glow badge, our own mark); a real AAPT2 build bug (`--` in an XML comment) found+fixed along the way |
| P3-21 | First-run mushaf pick+download onboarding (real 5 editions) | ✅ **done, live-verified** — edition picker + real download reused from Downloads, essential recitation download reused from P3-27, onboarding correctly skipped on relaunch; a real hardcoded-RTL bidi bug found+fixed live |
| P3-22 | Home: animated interactive prayer card (frame-verified target) | 🔶 built, analyze/test clean; fallback path live-verified, **populated path blocked on this emulator's location fix** (see notes) |
| P3-23 | Icon replacement round 2 | ✅ **resolved — owner confirmed the P3-1 icon**, sent the exact same `ref_icon_installed.jpg` back as confirmation (byte-identical), not a new reference; no change needed |
| P3-24 | Book download button → cancel state while downloading | ✅ **done, live-verified** |
| P3-25 | Downloads overview rows jump to their own tab | ✅ **done, live-verified** |
| P3-26 | Persistent prayer notification still reported absent | **blocked on live device** (see P3-13/P3-19) |
| P3-27 | "Download full recitation" card under the reciter picker | ✅ **done, live-verified** |
| P3-28 | Mushaf edition thumbnails | queued, **needs a per-edition licence/sourcing pass first** (see the QuranFlash warning above) |
| P3-29 | Book text reader nav/visual redesign | ✅ **both parts done, live-verified** — nav (swipe + fast-jump slider, a real `SelectionArea`-vs-`GestureDetector` bug found+fixed) and visual (Shamela-style 6-icon toolbar row + paper theme, all 6 actions live-tested; a real `AppBar.automaticallyImplyActions` gotcha found+fixed along the way) |
| P3-30 | "Azkar/Tasbeeh still old" | ✅ **confirmed resolved by the owner** — sent real-device screenshots of both, byte-identical to the earlier `ref_azkar_hub.jpg`/`ref_tasbeeh.jpg` reference images, confirming the shipped redesigns match |
| P3-31 | ~20-source تفسير download section | queued, **needs a research/licence pass first**, same rigor as every other content source |
| P3-32 | Ayah-end marker misaligned in text mode | ✅ **done, live-verified** — `PlaceholderAlignment.middle` → `.baseline` |
| P3-33 | Tafsir tab → single dropdown + inline download | 🔶 dropdown ✅ **done, live-verified**; inline download intentionally deferred — no real per-source download mechanism exists yet, see **P3-31** |
| P3-34 | Text mode: scroll/speed control + toolbar icon redesign+captions+animation | 🔶 toolbar redesign ✅ **done, live-verified**; scroll re-confirmed fine (not regressed); "speed control" **needs owner clarification** — unclear what it refers to |
| P3-35 | Ayah card: single play/stop toggle button | ✅ **done, live-verified** |
| P3-36 | Home: hadith reroll shouldn't scroll the page | ✅ **done, live-verified** — root cause was the card collapsing to a spinner mid-reroll, not a scroll bug at all |
| P3-37 | App display name follows device system language on first run | ✅ **done, live-verified** |
| P3-38 | Round-3: app icon v2, Azkar/Tasbeeh split into separate bottom-nav tabs, splash+app-store frames | ✅ **done, live-verified** — icon rebuilt as fresh vector art from a real reference photo (a real XML double-hyphen bug in `icon_fg.svg` found+fixed live, twice); Azkar/Tasbeeh now 7 separate bottom-nav tabs, both confirmed working independently |
| P3-39 | Round-4: literal splash video, keystore blocker dropped, cloud cleanup | ✅ **done, live-verified** — the owner's own 10s splash video now plays for real on cold start (muted, tap-to-skip, lattice/badge fallback while it decodes or if it ever fails), release-keystore no longer tracked as a blocker (personal-use app), old contaminated R2 bucket confirmed unused / no Firebase integration exists to clean up |
