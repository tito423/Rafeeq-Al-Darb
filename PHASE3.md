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
| P3‑3 | RGB theme restyle toward the tasbeeh reference's palette | queued — see notes |
| P3‑4 | Home screen redesign (RGB info card, per-card Islamic pattern bg, interactive prayer card, hadith/khatma/continue-reading cards) | 🔶 header card ✅ done + live-verified; per-card patterns + animated/interactive prayer card still open (animated prayer card superseded by round-2 **P3-22**, see below) |
| P3‑5 | **Login / accounts — architecture decision** | ✅ **answered: optional** (guest mode stays default, sign-in adds sync) — not yet built |
| P3‑6 | Khatma card bugs + redesign | 🔶 nav bug fixed, undo added, duplicate label removed; full visual redesign still open |
| P3‑7 | Adhan: confirmed real bugs + feature requests | 🔶 auto-play-on-select DONE; bug half **blocked on live device/logcat** (see P3‑19 for a real, concrete Android-14 lead found by code review) |
| P3‑8 | Mushaf reader: confirmed real bugs + feature requests | queued, some unblocked now |
| P3‑9 | Search & tafsir correctness bugs | 🔶 both search bugs fixed (فاسقين dagger-alif bug + نشورا/منشورا word-boundary bug); tafsir-ayah-link + non-Hafs-gating still open |
| P3‑10 | "معاني الكلمات" tab — remove unless a real source is found | ✅ done — tab removed |
| P3‑11 | Azkar redesign (remove intro, swipe nav, grid hub) | ✅ **done, live-verified on emulator** — المقدمة filtered, swipe nav, and the grid-hub redesign (2-column card grid, all 133 real sections after المقدمة, each card icon-matched by keyword) all shipped and confirmed on-device |
| P3‑12 | Tasbeeh redesign to match reference | ✅ **done, live-verified on emulator** — matches `ref_tasbeeh.jpg` closely |
| P3‑13 | Persistent prayer notification — confirmed real bug + "must not be dismissible" | **blocked on live device/logcat** — a dead second implementation found + removed along the way, see P3‑19 |
| P3‑14 | Settings: Russian layout bug, French locale | 🔶 Russian bug ✅ fixed (was a Khatma-card layout bug, not a Settings screen bug — see below); French still open |
| P3‑15 | Library: slow reader, page-nav redesign, مكتبتي split, catalog scope | 🔶 catalog +3 books DONE, مكتبتي split DONE; reader speed + page-nav redesign still open |
| P3‑16 | New "الصلاة" bottom-nav tab incl. professional Qibla compass | queued, unblocked (feeds P3‑4) |
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

## P3‑3 — RGB theme restyle

Owner: "خلي ثيم التطبيق rgb قريب للثيم اللي انت شايف في صورة المسبحة" (make
the RGB theme close to the theme in the tasbeeh reference image). Looking at
`design_refs/ref_tasbeeh.jpg`: a near-black background, a soft emerald/teal
glowing ring around the counter circle, small scattered star-dots, warm gold/
purple/teal/blue pill buttons for the four dhikr choices — calmer and darker
than the current `rgb_backdrop.dart` (which leans brighter neon teal/violet/
gold aurora). Plan: keep the existing seam (`AppTheme.rgb()` +
`RgbScaffoldBackground`/`_RgbPainter`, §5.6 of `HANDOVER.md`) but tone the
palette darker/calmer and make the "glow ring" motif (seen around the
tasbeeh counter and echoed faintly in the Home reference's cards) a
recurring accent rather than a full aurora wash. Not started.

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

**Still open:** per-card calm Islamic-pattern backgrounds (app-wide, not
just Home), the animated/interactive prayer-times card + live countdown
clock (`ref_home.jpg`'s `HH:MM:SS` + "متبقي 1 ساعة و 7 دقيقة" pill), the
ornamental "حديث شريف" card framing, the "متابعة القراءة" continue-reading
card (doesn't exist yet as its own card — currently folded into the Khatma
card's "اقرأ اليوم").

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
- No pinch-to-zoom in text **or** image mode.
- Paging feels like it re-fetches per page rather than reading the local
  cache — re-verify `MushafPageService`'s disk-cache hit path; the owner
  flagged this as high priority.
- Missing: a bottom surah-name scroll strip for fast jump-navigation.
- Missing: captions under the Quran-tab toolbar icons.
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
- **Still open:** tafsir not linked to the right ayahs (a real lookup/data
  mismatch, separate from the two fixes above) and tafsir/translation
  gating for non-Hafs riwayat editions (`MushafEdition.sciencesAvailableFor`
  — re-check the gating message logic).

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

- Book (image PDF) reader is **very slow** — profile `SfPdfViewer` usage,
  check for unnecessary rebuilds/full-file loads vs. lazy paging. Still open.
- Page navigation redesign: scroll + a fast jump strip, refreshed visual
  design, add pinch-zoom (echoes P3‑8's mushaf zoom ask — consider sharing
  a zoom-wrapper widget between the two readers if the code ends up
  similar). Still open.
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

## P3‑16 — New "الصلاة" (Prayer) bottom-nav tab

Consolidates what's scattered today (Adhan settings, P2‑6's notification
toggle, reminders) into one tab, **plus a new, visually polished Qibla
compass** — a real compass using the device magnetometer + location, "روعه
بصريا... باحترافية شديدة جدا" (owner was explicit this should look
genuinely professional, not a placeholder arrow). `design_refs/ref_home.jpg`
and `ref_tasbeeh.jpg`'s bottom nav both already show a "الصلاة" tab slot
between المسبحة and القرآن, matching where this should sit. Feeds P3‑4 (the
Home prayer card should navigate here on tap).

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

## P3-20 — Splash screen + early screens, rebuilt in the old style (new artwork)

Native Android splash (`launch_background.xml`/theme, not a Flutter route —
same mechanism this project already uses) styled like the video: a dark
navy field, a slow radial geometric star lattice (girih-style, echoes
`rgb_backdrop.dart`'s own lattice technique — reuse that approach, not a
new one), a glowing gold circular badge holding **our own P3-1 crescent+
book mark** (not the old mosque icon), "رفيق الدرب" in `AmiriQuran` below
it, tagline "زاد المسلم اليومي ومصحف القلوب" (already `app.tagline`'s
spirit — confirm wording matches or update the key) in gold. Not started.

## P3-21 — First-run onboarding: pick + download a mushaf edition (real 5, not 17)

Ties directly into the already-tracked **P3-8 G4/G5** (mushaf edition
picker + mandatory-feeling first download) — build it as the video shows
*structurally* (a dedicated onboarding screen, a prominent "تحميل المصحف
كاملاً الآن" action, a closing "ابدأ رحلتك الإيمانية 🚀" CTA) but scoped to
this project's real 5 editions, each labelled by riwayah, no fabricated
cover art. Not started.

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

## P3-25 — Downloads "نظرة عامة" rows should jump to their own section

Tapping a category row (e.g. "الكتب") in the overview tab should switch the
`DownloadsScreen`'s `TabController` to that category's own tab, not just
show a static summary. Not started.

## P3-26 — Persistent prayer notification — owner still reports it absent

Repeated again in this message. P3-13's investigation this session found
and removed a real dead second implementation and confirmed the live
`prayer_status_notification.dart` path matches what was emulator-verified
working before — **still genuinely needs the real device** to diagnose
further; nothing new to try without it. Keep flagging until a real-device
logcat session happens.

## P3-27 — Recitation downloads: a small "download full recitation" card

In التلاوات downloads, after picking a reciter, show a small card directly
under the picker offering to download that reciter's **entire** recitation
in one action (today: presumably per-surah only within the reader — verify
current behaviour before building). Not started.

## P3-28 — Mushaf edition thumbnails on their cards

Owner wants a cover thumbnail per mushaf edition card. **Must be an
originally-produced or clearly-licensed image per edition** (e.g. a
generated cover using this project's own palette/typography, or a
verified-PD/CC0 scan) — **not** sourced by searching for "the" cover image
of each edition online without checking, which is exactly the path that
produced the QuranFlash contamination flagged above. Not started; needs a
sourcing pass with the same rigor §5.7/P2-4 already established, per
edition, before any image ships.

## P3-29 — Book text reader: nav part ✅ DONE, live-verified; visual part still open

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

**Still open, visual redesign only:** the owner sent a reference image of
al-Maktaba al-Shamela's own reader (light paper-toned background, a 6-icon
top toolbar, a bottom bar with a page-number box + "الصفحة" + book icon +
"الجزء" + progress bar) with "استخدم نفس التصميم اجمل وارقى لكن بنفس
الثيماتنا" (adapt its layout quality, keep our own theme/colours, not a
literal skin) — that image wasn't saved to `design_refs/` before this
session's context was summarized, so the *exact* pixel design isn't
in hand; the description above is what was actually seen and can guide a
build, but ask the owner to resend the image before matching it precisely
rather than guessing further.

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

## P3-33 — Ayah sciences sheet: remove multi-tafsir compare, redesign tafsir tab as a dropdown

Reverses part of P2-8 #3 (multi-tafsir compare view) — owner doesn't like
it. New ask: the tafsir tab should show **one dropdown** to pick a source;
if the picked source isn't downloaded yet, show a download button /
shortcut next to the dropdown instead of the text, and once downloaded it
becomes available in place. Ties into **P3-31**'s bigger tafsir-download
section — likely the same underlying mechanism (a tafsir source is either
bundled, downloaded, or offered for download inline). Not started.

## P3-34 — Text-mode mushaf: no scroll, no speed control; toolbar icons need a redesign + captions + animation

Extends the already-tracked P3-8 (bottom jump-strip, pinch-zoom) and G3
(icon captions): owner specifically flags **no scrolling at all** in text
mode currently (re-verify — `mushaf_text_page.dart` should already be
`SingleChildScrollView`-based per `HANDOVER.md` §7's earlier fix; if it
regressed, that's a real bug to find) plus wanting a scroll-speed control,
and the toolbar icons need a visual refresh + a caption under each +
animation on interaction. Not started.

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

## P3-37 — App display name follows the device's system language, not just the app's own locale setting

On first install, before the user picks anything, the OS-level app name
("Rafeeq AlDarb" in the launcher, notifications, etc. — Android's
`android:label`) should reflect the **device's** system language (detect
once at install/first-run: Arabic device → "رفيق الدرب" as the *initial*
in-app locale selection, English device → "Rafeeq AlDarb", etc.) rather
than defaulting to a fixed value. Note: Android's launcher label
(`AndroidManifest.xml`'s `android:label`) is a single static string per
locale via `res/values-<lang>/strings.xml` resource qualifiers — Android
*does* already support this natively (multiple `strings.xml` per locale
folder, picked by the OS's own language, independent of in-app
`easy_localization` state) — check whether that's already wired before
assuming it needs new code; the in-app **first-run locale default** (which
language `easy_localization` starts in, shown top of a dropdown as
"detected") is the part that's more likely actually missing. Not started.

## Status table addition

| # | Task | Status |
|---|---|---|
| P3-20 | Splash screen + early onboarding screens, restyled (new art) | queued, unblocked |
| P3-21 | First-run mushaf pick+download onboarding (real 5 editions) | queued, unblocked (extends P3-8 G4/G5) |
| P3-22 | Home: animated interactive prayer card (frame-verified target) | 🔶 built, analyze/test clean; fallback path live-verified, **populated path blocked on this emulator's location fix** (see notes) |
| P3-23 | Icon replacement round 2 | **blocked on owner's reference image** |
| P3-24 | Book download button → cancel state while downloading | ✅ **done, live-verified** |
| P3-25 | Downloads overview rows jump to their own tab | queued, unblocked |
| P3-26 | Persistent prayer notification still reported absent | **blocked on live device** (see P3-13/P3-19) |
| P3-27 | "Download full recitation" card under the reciter picker | queued, unblocked |
| P3-28 | Mushaf edition thumbnails | queued, **needs a per-edition licence/sourcing pass first** (see the QuranFlash warning above) |
| P3-29 | Book text reader nav/visual redesign | 🔶 nav part ✅ **done, live-verified** (swipe + fast-jump slider, a real `SelectionArea`-vs-`GestureDetector` bug found+fixed along the way); visual part still open — **ask the owner to resend the Shamela reference image** |
| P3-30 | "Azkar/Tasbeeh still old" | likely stale — **ask the owner to re-check on the batch-2+ APK** before rebuilding |
| P3-31 | ~20-source تفسير download section | queued, **needs a research/licence pass first**, same rigor as every other content source |
| P3-32 | Ayah-end marker misaligned in text mode | ✅ **done, live-verified** — `PlaceholderAlignment.middle` → `.baseline` |
| P3-33 | Tafsir tab → single dropdown + inline download | queued, unblocked, ties to P3-31 |
| P3-34 | Text mode: scroll/speed control + toolbar icon redesign+captions+animation | queued, unblocked (re-verify scroll didn't regress) |
| P3-35 | Ayah card: single play/stop toggle button | ✅ **done, live-verified** |
| P3-36 | Home: hadith reroll shouldn't scroll the page | ✅ **done, live-verified** — root cause was the card collapsing to a spinner mid-reroll, not a scroll bug at all |
| P3-37 | App display name follows device system language on first run | queued, unblocked |
