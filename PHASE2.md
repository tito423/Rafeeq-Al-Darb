# PHASE 2 — Owner expansion request (prompt for the executing agent)

**Written 2026-09-02, from the owner's own words. This file is a build prompt.
Follow it the same way the pipeline was run: one stage at a time, verified on a
real running app, checkpointed after every meaningful edit.**

---

## 0. Before you touch anything

Run and read, in this order:

```
git -C "E:\My Projects\Rafiq-Al-Darb" log --oneline -15
git -C "E:\My Projects\Rafiq-Al-Darb" status --short
.\cp.bat /s              # from PowerShell or cmd — NOT Git Bash
```

Then read completely:

1. `HANDOVER.md` — **§3 hard rules**, **§5 decisions you must not undo**,
   **§7 verification tables + open small-bug list**, **§11 mistakes already made
   on this project**. The "Current work in progress" block at the top tells you
   whether a stage is live.
2. `WORK_QUEUE.md` — the Phase 1 backlog and its rules of engagement.
3. `RAFEEQ_PIPELINE.md` — the 20 completed tasks (T1–T20).
4. This file.

**Continue from your colleagues' work — do not restart it.** Phase 1 (T1–T20)
is done and live-verified on the emulator.

**As of 2026-09-02, P2‑1, P2‑2 and P2‑3 are COMPLETE and emulator-verified**
(see the ✅ blocks in each section below; `flutter analyze` clean, `flutter
test` 13/13, last checkpoint `ec15d06`):
- **P2‑1** — all 6 bugs fixed; the launcher icon was designed in-house
  (`rafeeq_app/assets/icon/src/`).
- **P2‑2** — 4 themes (`theme_controller.dart`, `app_theme.dart` `rgb()`,
  `rgb_backdrop.dart`), animated RGB backdrop, persisted.
- **P2‑3** — `es` / `ru` / `pt` locales (224 keys each), 5-way parity test,
  `const AppShell` locale-refresh bug fixed.

**Start at P2‑4** and go in order. Do the two owner add-ons noted in **P2‑5**
(every download → a live progress notification) and the new **P2‑6**
(persistent next-prayer / Hijri / countdown notification).

### Non-negotiable rules (from `HANDOVER.md` §3 — repeated because they bind you)

| # | Rule |
|---|------|
| 1 | **Zero mock / placeholder data.** No fake catalog rows, no hardcoded "downloaded" ticks, no invented text. Missing data → an honest empty state. |
| 2 | **Nothing from QuranFlash.** Its data and assets are off-limits (`HANDOVER.md` §5.1). You may study its *UX ideas* only. |
| 3 | **Never report unverified work as done.** Say exactly what you ran on a device and what you did not. |
| 4 | **Offline-first.** Anything downloaded must work with the network off. |
| 5 | **No secrets in git.** `.env`, keystores, `google-services.json`, `serviceAccountKey.json` stay gitignored. |
| 6 | **Translation-key parity across ALL locales.** Phase 2 takes this from `ar`/`en` (2) to `ar`/`en`/`es`/`ru`/`pt` (5). Adding a key to one locale and not the others is a bug. Update this rule's count in `HANDOVER.md` when P2‑3 lands. |

### How to work

- **Checkpoint constantly.** After every meaningful edit:
  `.\cp.bat "what you just did"` (PowerShell/cmd). When a stage is done:
  `.\cp.bat "..." -Done`. A session that dies right after a checkpoint loses
  nothing.
- **If you feel the session is about to end**, stop mid-feature and spend the
  last turns updating `HANDOVER.md` (the WIP block + §7), `WORK_QUEUE.md`, and
  this file's stage checkboxes with the *exact* last state and the next
  concrete step. Do not leave a half-written non-compiling file without a note
  saying so (that already happened once — `library_screen.dart`, commit
  `df1be4c`).
- **`flutter analyze` after every stage. Then run it on the emulator**
  (`emulator-5554` is usually up; it is slow, wait after launch). analyze clean
  ≠ works. Acceptance criteria must be met on the running app.
- **Verify on a real Android phone at least once** before Phase 2 is called
  done — everything so far is emulator-only.
- **Stop and ask the owner** at any point marked **OWNER-BLOCKER** below, or any
  step needing a credential / keystore / console login only he has. Do not
  build half a workaround around a real external blocker — report it.
- The owner is **learning to program and will study this codebase afterward.**
  Favour clear, conventional, documented code over cleverness. Match the
  surrounding style.

---

## The ten stages

| Stage | Title | Depends on | Owner-blocked? |
|---|---|---|---|
| P2‑1 | Small-bug sweep | — | ✅ done |
| P2‑2 | Theme system: 4 themes (system / light / dark / **RGB**) + extensible registry | — | ✅ done |
| P2‑3 | Localization: add **Spanish, Russian, Portuguese** (full coverage) | — | ✅ done |
| P2‑4 | Library redesign (home entry, 3 sub-tabs, "My Library") + catalog expansion | P2‑2, P2‑3 | partial (al-Jaziri licensing) |
| P2‑5 | Professional download manager (unified, pause/resume, storage view) **+ every download shows a live progress notification with a progress bar** | P2‑2, P2‑3 | no |
| **P2‑6** | **Persistent prayer notification** — ongoing status-bar notification: next prayer, Hijri date, live countdown; professional, with the app icon | P2‑2 | no |
| P2‑7 | Professional Adhan: **audio-or-video** choice, video composite, up to **30** adhans | P2‑5 | **yes** (video source/licensing) |
| P2‑8 | Competitor feature mix (Sakinah, Ayat, QuranFlash, Khatmah) — research → propose → build | P2‑2..P2‑5 | check-in required |
| P2‑9 | Hosting & cost guardrails (Cloudflare R2 / Firebase / GitHub) | — | **yes** (console access) |
| P2‑10 | Lightweight / fast / secure / maintainable pass + release prep | all above | **yes** (release keystore) |

Do them in order. P2‑2 and P2‑3 were foundational (they touch every screen) and
are done. P2‑6 depends only on P2‑2 — it can be slotted earlier if you prefer.

---

## P2‑1 — Small-bug sweep

**Goal:** clear every open bug in `HANDOVER.md` §7's "Bugs found but NOT fixed"
list so it stops rotting.

**Start from these files:**
- `lib/features/quran/presentation/widgets/mushaf_text_page.dart` *(2 fixes already applied)*
- `lib/features/quran/presentation/screens/quran_screen.dart` *(reader-mode persistence already applied)*
- `lib/core/services/mushaf_page_service.dart` + `lib/features/downloads/presentation/widgets/download_tile.dart` + `lib/features/downloads/presentation/screens/downloads_screen.dart`
- `lib/features/quran/presentation/widgets/ayah_sciences_sheet.dart` (the i'rab tab, `_IrabTab`)
- `rafeeq_app/pubspec.yaml` (`flutter_launcher_icons`) + `assets/icon/`
- new: `lib/core/utils/buckwalter.dart` + `test/buckwalter_test.dart`

**Do:**

| # | Bug | Fix |
|---|---|---|
| 1.1 ✅ | Text-mode surah header shows `سُورَة سُورَةُ الفاتحة` (doubled) | DB `name_ar` already contains "سُورَةُ …" — render it directly. **Done.** |
| 1.2 ✅ | Stray `﴿ ﴾` under the last ayah in text mode | Removed the trailing decorative `Text`. **Done.** |
| 1.3 ✅ | Reader mode (text/image) not persisted — always starts in text | Persist `_mode` to `SharedPreferences` on toggle, restore in `initState`. **Done.** |
| 1.4 ✅ | **Mushaf download stops when you leave the Mushafs tab** (highest priority — breaks offline-first; open since STAGE 0) | **DONE, emulator-verified.** `MushafPageService` now owns a `PrefetchProgress` (`ChangeNotifier`) per edition; the job is `unawaited` on the singleton and `_MushafDownloadTile` re-attaches to it in `initState`. `// P2‑5` note left on `PrefetchProgress`. Verified live: 3 → 27 → 39 → 51 across a tab switch, tile kept the progress bar. P2‑5 folds this into the unified manager. |
| 1.5 ✅ | Launcher icon is a square JPG, no alpha / no adaptive shape | **DONE — icon designed in-house (owner said "design it yourself").** New emblem: rub‑el‑hizb guiding star + a receding path, in the app's teal/gold palette. Source SVGs + regen instructions in `rafeeq_app/assets/icon/src/`. Rendered via headless Chrome → `app_icon.png` / `app_icon_foreground.png` / `app_icon_background.png`; `flutter_launcher_icons` config updated (adaptive fg/bg, `background_color_ios`); `dart run flutter_launcher_icons` produced `mipmap-anydpi-v26/ic_launcher.xml` (16% inset). Old `app_icon.jpg` deleted and `assets/icon/` removed from the Flutter bundle (build-time only — saves ~0.9 MB install). Verified on the emulator app drawer: proper adaptive icon, masks to a circle, branded mark. |
| 1.6 ✅ | I'rab tab shows Buckwalter transliteration (`Hmd`, `rbb`, `r~aHoma\`n`) for root/lemma instead of Arabic | **DONE, emulator-verified + unit-tested (11/11).** `word_grammar.root` / `.lemma` are stored in Buckwalter (verified: `Hmd`, `rbb`, `{som`, `r~aHoma\`n`). Added `lib/core/utils/buckwalter.dart` — a `buckwalterToArabic(String)` using the standard Tim Buckwalter map (`'`→ء `|`→آ `>`→أ `&`→ؤ `<`→إ `}`→ئ `A`→ا `b`→ب `p`→ة `t`→ت `v`→ث `j`→ج `H`→ح `x`→خ `d`→د `*`→ذ `r`→ر `z`→ز `s`→س `$`→ش `S`→ص `D`→ض `T`→ط `Z`→ظ `E`→ع `g`→غ `f`→ف `q`→ق `k`→ك `l`→ل `m`→م `n`→ن `h`→ه `w`→و `Y`→ى `y`→ي `F`→ً `N`→ٌ `K`→ٍ `a`→َ `u`→ُ `i`→ِ `~`→ّ `o`→ْ `` ` ``→ٰ `{`→ٱ `_`→ـ). Apply it to `w.root` and `w.lemma` in `_IrabTab` (the token is already Arabic — leave it). Cover with `test/buckwalter_test.dart` (`Hmd`→`حمد`, `rbb`→`ربب`, `r~aHoma\`n`→`رَّحمٰن`, round-trip a couple of real rows). Note in `HANDOVER.md` §7 that roots are now transliterated for display. |

**Acceptance — met on the emulator (`emulator-5554`, 2026-09-02):** header
reads once; no `﴿ ﴾`; image mode survived `am force-stop` + relaunch; a mushaf
download kept running across a Downloads-tab switch and the tile re-attached;
i'rab for 1:1 shows الجذر: سمو / الكلمة: ٱسْم. `flutter analyze` clean,
`flutter test` 11/11.

**Status: P2‑1 is COMPLETE** (1.1–1.6 all done, emulator-verified; icon
designed in-house). Next stage: P2‑2 (theme system).

---

## P2‑2 — Theme system: system / light / dark / RGB, extensible

**Goal:** four themes covering the **entire** app, selectable in Settings,
persisted, with an **RGB theme that has a tasteful animated Islamic-geometric
background** — and a registry so a fifth theme is one entry, not a refactor
(the owner noted Sakinah lets users add themes).

**Start from these files:**
- `lib/app/rafeeq_app.dart` (`ThemeModeNotifier` / `themeModeProvider` / `MaterialApp`)
- `lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart` (the theme `SegmentedButton`)
- `lib/main.dart`
- new: `lib/core/theme/theme_registry.dart`, `lib/core/theme/theme_controller.dart`,
  `lib/core/theme/rgb_backdrop.dart` (the animated painter)

**Do:**
- Replace the raw `ThemeMode` state with a `ThemeVariant { system, light, dark, rgb }`
  controller. Persist under a **new** key `theme_variant_v2`; migrate an existing
  `theme_mode_v1` value on first run.
- `theme_registry.dart`: `class AppThemeSpec { id, labelKey, ThemeData data, ThemeMode systemMode, Widget? backdropBuilder }` and `const List<AppThemeSpec> kThemes`.
  Ship 4. Adding a 5th = append one `AppThemeSpec`.
- `MaterialApp` uses the resolved spec: `theme` / `darkTheme` / `themeMode` for
  system/light/dark; for `rgb`, a dedicated dark-based `ThemeData` (neon accent
  on near-black, AA contrast for all body text) plus `backdropBuilder` painted
  behind every screen (wrap `AppShell`'s body / a global `Stack` under the
  `Navigator`, not per-screen).
- **RGB backdrop:** one `AnimationController` (12–20 s loop), a `CustomPainter`
  drawing a slow aurora gradient + a low-opacity 8-point-star / girih
  tessellation, wrapped in `RepaintBoundary`. Must:
  - hold 60 fps on the emulator (re-check on a real phone),
  - stop animating when `MediaQuery.disableAnimations` is true,
  - have a Settings toggle `settings.motion_effects` (default on) that freezes it,
  - never reduce text contrast below WCAG AA.
- Audit every screen that hardcodes a colour (`grep -rn "AppColors\.\|Color(0x" lib/`)
  — they must read from `Theme.of(context)` so all four themes look right. The
  mushaf glyph recolour (`srcIn` filter, `mushaf_page_view.dart`) already keys
  off `theme.brightness`; make sure `rgb` maps to a sensible ink.
- Settings: swap the 3-way `SegmentedButton` for a 4-option control (segmented
  is fine for 4) with localized labels + a small live preview swatch each.

**Acceptance (emulator):** switch through all 4 themes in Settings → every tab
(Home, Quran text + image, Azkar, Library, Settings, Adhan, Downloads, sheets)
re-renders correctly, no unreadable text, no white flash in RGB; kill & relaunch
→ same theme; RGB animates smoothly and freezes when motion effects are off;
"system" follows the OS light/dark toggle.

### ✅ P2‑2 DONE (2026-09-02, emulator-verified)

Built slightly differently from the sketch above — simpler, same result:

- **`lib/core/theme/theme_controller.dart`** — `enum ThemeVariant {system,light,dark,rgb}`
  (carries its own `labelKey` + `icon`), `ThemeController` persists
  `theme_variant_v2` and migrates `theme_mode_v1` once. Also
  `MotionEffectsController` → `motion_effects_v1` (default on). No separate
  registry file — the enum + the `switch` in `RafeeqApp` IS the seam; a 5th
  theme is one enum case + one `AppTheme.xxx()` + one `switch` arm.
- **`lib/core/theme/app_theme.dart`** — added `AppTheme.rgb()`: dark, electric-
  teal accent (`#22E0C6`), **transparent scaffold**, ~90%-opaque cards/sheets,
  dark-scrim app bar (new optional `appBarColor` param on `_build`).
- **`lib/core/theme/rgb_backdrop.dart`** — `RgbScaffoldBackground` (a
  `ConsumerWidget`, reads `motionEffectsProvider` + `MediaQuery.maybeDisableAnimationsOf`)
  wraps the navigator via `MaterialApp.builder` **only** when variant == rgb.
  `_RgbPainter`: near-black base + 3 drifting radial colour fields (teal/violet/
  gold) on Lissajous paths + a faint **rub‑el‑hizb 8‑point-star lattice**
  (`Path.combine` of two squares) slowly counter-rotating + a top/bottom
  vignette for app-bar legibility. `RepaintBoundary`, `shouldRepaint` gated on
  `t`. Motion off (toggle or OS reduce-motion) → still frame, controller stopped.
- **`lib/app/rafeeq_app.dart`** — removed `ThemeModeNotifier`; `RafeeqApp` now
  resolves `ThemeVariant` → `(light, dark, mode)` + conditional `builder`.
- **`settings_screen.dart`** — 4-segment `SegmentedButton<ThemeVariant>`
  (fits, no overflow); the motion-effects `SwitchListTile` shows only for RGB.
- Translations: `settings.rgb` / `settings.motion_effects` / `.._desc` added to
  ar + en (parity 224/224).

Verified on `emulator-5554`: dark (migrated default), **RGB** (animated
lattice + aurora, neon accent, all text readable over the motion — Home /
Quran text / Settings spot-checked), light; theme **persisted** across
`am force-stop` (RGB survived once given ~5 s to flush the async write); motion
toggle present & persisted; `flutter analyze` clean, `flutter test` 11/11.
Not separately shot: "system" following a live OS light/dark flip (it only
picks light/dark, both verified), and every last sheet under RGB.

**Checkpoint** each sub-step; `-Done` when the acceptance list passes.

---

## P2‑3 — Localization: Spanish, Russian, Portuguese

**Goal:** `es`, `ru`, `pt` added to the app, **covering every string**, at full
key parity with `ar`.

**Start from these files:**
- `rafeeq_app/assets/translations/ar.json`, `en.json` → add `es.json`, `ru.json`, `pt.json`
- `lib/main.dart` (`EasyLocalization` `supportedLocales`, `fallbackLocale`)
- `lib/features/settings/presentation/screens/settings_screen.dart` (language control)
- `lib/app/rafeeq_app.dart` (already forwards `context.supportedLocales`)

**Do:**
- Copy every key from `ar.json` into the three new files with **real, correct
  translations** — not machine-mangled output, not English placeholders. UI
  chrome strings are short and standard; translate them properly. Religious
  *content* that is deliberately Arabic in `en.json` (du'a text, etc.) follows
  the same policy in the new files.
- `main.dart`: `supportedLocales` → `[ar, en, es, ru, pt]`; keep `fallbackLocale: ar`.
- Settings: the 2-way `SegmentedButton` can't hold 5 — use a `DropdownButton` /
  `ListTile` + radio sheet. Localize each language's name in its own script
  (العربية / English / Español / Русский / Português).
- `es`/`ru`/`pt` are LTR — verify no layout assumes RTL outside `ar`. Check the
  Quran/Adhan/Hadith screens (they mix RTL content into an LTR shell).
- Add a tiny `test/translation_parity_test.dart` that asserts all 5 files have
  identical key sets (fails CI if someone adds a key to one only). Update
  `HANDOVER.md` §3 rule 6 with the new count.

**Acceptance (emulator):** pick each of the 5 languages → the whole app (nav,
Home, Settings, Quran sheets, Adhan settings, Library, Downloads, errors, empty
states) shows in that language, no raw `some.key` strings; `flutter test` parity
test passes.

### ✅ P2‑3 DONE (2026-09-02, emulator-verified)

- `assets/translations/{es,ru,pt}.json` — all **224 keys**, real human-quality
  translations (Islamic terms follow each language's convention: es *Corán/
  adhán/Wudú*, ru *Коран/азан/вуду*, pt *Alcorão/adhan/Wudu*). Built from
  `en.json`'s exact structure by a one-off script (kept in the scratchpad).
- `main.dart` `supportedLocales` → `[ar, en, es, ru, pt]`, `fallbackLocale: ar`.
- `settings_screen.dart` — language picker is now a **`Wrap` of `ChoiceChip`**
  (5, each labelled in its own script via a `_languageNames` const); the theme
  picker was **also** converted from `SegmentedButton` to a `ChoiceChip` `Wrap`
  because 4 segments + longer translated words clipped ("Siste​ma").
- **Bug found & fixed:** `RafeeqApp` passed `const AppShell()` as `home`, so a
  `MaterialApp` rebuild after `context.setLocale` never re-ran `AppShell.build`
  and the bottom-nav labels stayed in the old language. Now
  `AppShell(key: ValueKey(context.locale.languageCode))` — the shell refreshes
  fully on a language change (also gives a clean RTL↔LTR flip).
- `test/translation_parity_test.dart` — identical-key-set + no-empty-value
  checks across all 5 files. `flutter test` = **13/13**.
- Verified live on `emulator-5554`: **Spanish** (Settings + Library, LTR),
  **Russian** (Home, full Cyrillic, LTR), back to **Arabic** (RTL restored,
  nav order flipped back). `flutter analyze` clean.

**Left ar/en-only on purpose:** the hand-authored Dart content —
`new_muslim/data/guide_content.dart` (fiqh of wudu/salah, pillars, ‘aqidah)
and `adhan/data/adhan_text.dart` (the adhan words). Auto-translating
religious teaching into 3 more languages without a native/scholarly review
would violate the "no unverified content" rule. Flagged for the owner: needs
real translators if es/ru/pt coverage of that screen is wanted.

---

## P2‑4 — Library redesign + catalog expansion

**Goal:** the layout the owner described, reachable from Home, plus more real
books.

**Start from these files:**
- `lib/features/library/data/book_catalog.dart` (`LibraryBook`, the 4 titles)
- `lib/features/library/presentation/screens/library_screen.dart`
- `lib/features/library/presentation/screens/book_reader_screen.dart`
- `lib/features/home/presentation/screens/home_screen.dart` (add the entry card)
- `lib/app/shell/app_shell.dart` (Library is bottom-nav slot 3 — keep it, it can host the same screen)
- `lib/core/services/download_manager.dart`
- new: `lib/features/library/data/book_category.dart`,
  `lib/features/library/data/my_library_store.dart`

**Do:**
- **Model:** `LibraryBook` gains `category` (`enum BookCategory` — settle the
  list from the catalog you build, e.g. `hadith, fiqh, aqidah, tafsir, seerah,
  tazkiyah, adab, quranSciences`), `authorAr` / `authorEn`, and a
  Arabic-collation-safe `sortKey`.
- **Home:** a prominent "المكتبة" card (icon + subtitle) → `Navigator.push` the
  full `LibraryScreen`. (`HomeScreen(onNavigate:)` currently switches bottom
  tabs — either push directly or route through the shell; keep the bottom-nav
  Library tab working too.)
- **`LibraryScreen` top tabs:** `الكتب المتوفرة` and `الحديث` (the existing
  hadith hub — do not disturb it).
- **Inside `الكتب المتوفرة`, three sub-tabs:**
  1. `كل الكتب` — every catalog book, **alphabetical** by `sortKey`.
  2. `التصنيفات` — grouped by `BookCategory` (section headers or a
     category → list drill-down).
  3. `مكتبتي` — **only downloaded books**. Each row: title, **its category
     shown under the title**, and a `قراءة` button + a `حذف` button. `حذف`
     removes the file and its registry entry and frees the space.
- **`my_library_store.dart`:** a persisted registry of downloaded books
  `{ bookId, filePath, sizeBytes, downloadedAt }` (SharedPreferences JSON or a
  small on-disk index). The catalog list reads it to show "downloaded" state
  honestly (no hardcoded ticks).
- **Catalog expansion** — add real **public-domain** titles, each with a
  `downloadUrl` **verified by a real `curl -L` GET**: HTTP 200,
  `Content-Type: application/pdf`, and record the exact `Content-Length` in
  `approxSizeBytes` (the Phase-1 guesses were wrong — see `HANDOVER.md` §7's
  STAGE 2 note). Owner's requested authors: **Ibn Taymiyyah**, **al-Hakim
  al-Tirmidhi**, **Ibn Abi al-Dunya** (many short treatises — pick a few whole
  ones), and fill categories for the existing 4. Prefer archive.org or
  al-Maktaba al-Shamela. A modern *tahqiq* can carry its own copyright even when
  the classical text is PD — pick clean editions.
  - **OWNER-BLOCKER:** **al-Jaziri, *al-Fiqh ʿalā al-Madhāhib al-Arbaʿa* (1941)**
    is **not** public-domain by author death — do a licensing check and **do not
    ship it until the owner clears it**. Leave a note, not an entry.
- If a URL can't be verified, it does not go in the catalog (rule 1).

**Acceptance (emulator):** Home → المكتبة card opens the screen; `كل الكتب` is
alphabetical; `التصنيفات` groups correctly; download a new title → it appears in
`مكتبتي` with its category under the name, `قراءة` opens the real PDF
(`SfPdfViewer`), airplane mode → still opens, `حذف` removes it and the space is
freed; hadith hub still works.

---

## P2‑5 — Professional download manager

**Goal:** one polished, unified downloads hub; every heavy asset is on-demand;
progress survives navigation; the user can see and reclaim storage.

**Start from these files:**
- `lib/core/services/download_manager.dart` (dio stream + resume + notifications)
- `lib/core/services/mushaf_page_service.dart` (`prefetchEdition` — root of the P2‑1.4 bug)
- `lib/core/services/ayah_audio_service.dart` (`downloadSurah`)
- `lib/features/downloads/presentation/screens/downloads_screen.dart`
- `lib/features/downloads/presentation/widgets/download_tile.dart`
- `lib/features/downloads/data/reciters_provider.dart`
- new: `lib/features/downloads/data/downloads_controller.dart` (the central job registry)

**Do:**
- **Central job registry** (`downloads_controller.dart`, a Riverpod provider):
  every download — mushaf edition, per-surah recitation, `hadith.zip`, a book
  PDF, adhan video — is a `DownloadJob { id, kind, title, totalBytes,
  receivedBytes, state }` where `state ∈ {queued, running, paused, done,
  failed, canceled}`. The manager owns the jobs; screens/tiles only *observe*
  the provider. This **root-fixes P2‑1.4**: leaving a tab can't stop a job it
  no longer drives.
- **`DownloadManager`:** add `pause` / `resume` / `cancel` (dio `CancelToken` +
  HTTP `Range` resume — partial-file resume already exists for mushaf pages,
  generalize it).
- **Owner add-on — every download shows a live progress notification.** Any
  `DownloadJob` that starts (mushaf edition, per-surah recitation, `hadith.zip`,
  a book PDF, the adhan video) posts an Android notification via
  `flutter_local_notifications` with: the app icon, the item's real name, a
  determinate **progress bar** (`showProgress: true, maxProgress, progress`),
  and a `%` / `MB of MB` line — updated as bytes arrive (throttle to ~1/sec so
  it doesn't spam). It clears itself on completion (or flips to a short
  "downloaded" that auto-dismisses) and on cancel. One notification per job,
  grouped under a "Downloads" channel. `hadith.zip` already does a basic
  version of this — make it the shared path for all job kinds, not a per-caller
  reimplementation. Tapping the notification opens the unified `DownloadsScreen`.
- **Unified `DownloadsScreen`:** sections `المصاحف · التلاوات · الحديث · الكتب ·
  الأذان (فيديو)`. Each item shows size, a real progress bar, and
  contextual actions (download / pause / resume / cancel / delete-to-free).
- **Storage view:** total used by app downloads + per-category breakdown +
  a "تفريغ" (free space) action per category and overall. Read real file sizes
  from disk, not estimates.
- **Keep the install light:** nothing heavy added to `pubspec.yaml` `assets:`.
  Confirm `flutter build apk --release --split-per-abi` base size does not grow
  (compare to the Phase-1 figures in `HANDOVER.md` §7 STAGE 8).

**Acceptance (emulator):** queue two downloads → both show progress; navigate
away and back → still running; **each download shows a notification with a live
progress bar + the app icon, and it clears on finish/cancel**; pause one → it
stops and resumes from where it was (verify received bytes don't reset); cancel
→ partial file removed; storage view shows real numbers and "free space"
actually deletes; airplane-mode replay of everything downloaded still works.

---

## P2‑6 — Persistent prayer notification (ongoing status-bar card)

**Goal (owner's words):** a **fixed notification in the status bar** showing the
**next prayer**, the **Hijri date**, and a **live countdown** to that prayer.
"احترافي مع أيقونة التطبيق" — it must look polished and carry the app icon.

**Start from these files:**
- `lib/core/services/adhan_alarm_service.dart` (owns `flutter_local_notifications`,
  channels, the app-icon notification setup)
- `lib/features/home/data/prayer_controller.dart` (location → `PrayerTimesService`
  → the five prayer times; this is where "next prayer" is already computed)
- `lib/core/services/prayer_times_service.dart`, `lib/core/models/prayer_times.dart`
- `lib/features/adhan/data/adhan_settings_provider.dart` (add the on/off toggle)
- `lib/features/adhan/presentation/screens/adhan_settings_screen.dart` (the toggle UI)
- `hijri` package — already in `pubspec.yaml`; use it for the Hijri date
- `android/app/src/main/AndroidManifest.xml` (permissions already cover
  `POST_NOTIFICATIONS`; no foreground-service permission unless you go that route)
- new: `lib/core/services/prayer_status_notification.dart`

**Do:**
- **An ongoing, non-dismissible notification** (`ongoing: true`,
  `autoCancel: false`, low priority so it sits quietly, `showWhen: false`,
  `category: CategoryStatus`). Content:
  - **title:** next prayer name + its clock time — e.g. `العصر ‏· 15:42`
  - **body / big-text:** Hijri date (`hijri` pkg, localized digits) + the
    countdown — e.g. `٨ ربيع الآخر ١٤٤٧ — باقٍ ٠١:١٧:٤٥`
  - **largeIcon / smallIcon:** the app icon (`@mipmap/ic_launcher` /
    a monochrome `@drawable` small icon — add one if the launcher icon
    doesn't downscale cleanly to a status-bar glyph).
  - a subtle progress bar of "how far through the current interval" is a nice
    touch (`showProgress`, indeterminate off) — optional.
- **Keep it fresh.** The countdown must tick down. Options, pick the simplest
  that survives the app being backgrounded/killed:
  1. Re-post the notification every 60 s from a periodic `zonedSchedule` /
     `AndroidAlarmManager`-style repeat, recomputing text each time (minute
     resolution on the countdown is fine — `باقٍ ١ س ١٧ د`).
  2. Or a real foreground service (heavier; needs
     `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` on API 34+ and a
     Play policy declaration — avoid unless (1) proves unreliable).
  Recompute "next prayer" at each tick so it rolls over correctly (after Isha →
  tomorrow's Fajr; refresh the day's times at midnight / on the first tick of a
  new day).
- **Toggle in Adhan settings** — `prayer.persistent_notification` /
  `..._desc`, persisted, default **off** (opt-in — an always-on notification is
  a strong choice to make for the user). When off, cancel the notification.
- **Locale-aware** — all 5 languages; Arabic-Indic digits when locale is `ar`.
  Add the keys to every locale (parity test will enforce it).
- **Offline-first** — it must keep working with no network: prayer times come
  from the last successful `PrayerTimesService` fetch (already cached for the
  Home screen) or the device's last known location; if there is genuinely no
  data yet, show an honest "enable location" one-liner instead of fake times.
- Wire it into `main.dart` startup (post/refresh on launch if the toggle is on)
  and into `PrayerController` (re-post when the times get recalculated after a
  location change).

**Acceptance (real device preferred; emulator OK for the visual):** turn the
toggle on → a persistent notification appears with the app icon, the correct
next prayer + time, the real Hijri date, and a countdown that visibly decreases
minute to minute; it survives swiping the notification shade and an app
restart; after a prayer time passes it rolls to the next prayer (and Isha →
Fajr next day); turning the toggle off removes it; airplane mode → still shows
(cached times), no fake data.

---

## P2‑7 — Professional Adhan: audio-or-video, composite, up to 30

**Goal:** when choosing an adhan the user picks **صوت** or **فيديو**; video mode
plays the chosen adhan **audio** over a beautiful looping Islamic-scenery
**video**, composited at playback time; the app ships light and supports **up to
30** adhans (built-in + imported).

**Start from these files:**
- `lib/features/adhan/` — `presentation/screens/adhan_settings_screen.dart`,
  `presentation/screens/adhan_full_screen_screen.dart`,
  `data/adhan_settings_provider.dart`, `data/adhan_catalog_provider.dart`,
  `data/adhan_scheduler.dart`, `data/adhan_text.dart`
- `lib/core/services/adhan_alarm_service.dart`, `adhan_catalog_service.dart`, `adhan_uri_bridge.dart`
- `lib/core/models/adhan_option.dart`, `adhan_mode.dart`
- `assets/data/catalogs/adhans.json` (10 built-in: `azan1..azan10`)
- `assets/audio/adhan/azan*.mp3` + `android/app/src/main/res/raw/azan*.mp3`
- `android/app/src/main/kotlin/.../MainActivity.kt` (`contentUriForFile` bridge)
- `rafeeq_app/pubspec.yaml` — add `video_player`
- new: `lib/features/adhan/presentation/screens/adhan_video_screen.dart`

**Do:**
- **Per-adhan / per-prayer presentation mode:** extend the settings model with
  `AdhanPresentation { audioOnly, video }`. UI in `adhan_settings_screen.dart`:
  after picking an adhan, a clear `صوت | فيديو` choice with a real preview of
  each.
- **Composite, do NOT mux:** one (or a few) **muted** background video
  asset(s) + the existing tagged `just_audio` adhan playback, started together
  and kept in sync in `adhan_video_screen.dart` (`video_player` looped & muted
  behind the karaoke text from `adhan_text.dart`). Bundling 30 pre-rendered
  videos would break "ship light" — keep it one video × many audios.
- **Video asset is downloadable, not bundled** — register it as a
  `DownloadJob` (P2‑5), `الأذان (فيديو)` section. First selection of video mode
  prompts the ~few-MB download.
- **Honest limitation to document:** the background alarm sound that fires when
  the app is **killed** goes through Android's notification-sound API
  (`RawResourceAndroidNotificationSound`) and **cannot show video**. Video is
  the foreground / full-screen-intent experience (device on). Say this plainly
  in `HANDOVER.md` and the UI (a one-line note under the فيديو option).
- **Up to 30 adhans:** find the current custom-adhan cap
  (`adhan_settings_provider` / `adhan_catalog_provider`) and raise the ceiling
  to 30 total. Keep every imported file validated as real audio (existing
  `file_picker` + `contentUriForFile` path). Honest labels — no invented
  reciter names (the 10 built-ins stay "أذان 1".."أذان 10", see WORK_QUEUE
  STAGE 1).
- Fix the `adhans.json` mojibake while you're here (`head -c` shows a
  double-encoding artifact around `azan8`).

**OWNER-BLOCKER — video source.** Before building the video screen, get the
owner to approve a source for the background clip(s). Propose CC0 options
(Pexels / Pixabay / Coverr mosque / Kaaba / skyline footage — verify each
clip's licence) or an owned/commissioned clip. **Do not scrape YouTube or any
app.** No clip → build the audio path, stub the video button disabled with an
honest "coming soon" and say so.

**Acceptance (real device preferred; emulator for the UI):** pick فيديو for
Dhuhr → the video downloads once → set the time 2 min ahead, lock the phone →
adhan fires; with the screen on, the full-screen view shows the looping video
behind synced karaoke text and the chosen audio; صوت-only still behaves exactly
as Phase-1 verified; import adhans up to 30, the 31st is refused with a clear
message; per-prayer mode survives an app restart.

---

## P2‑8 — Competitor feature mix

**Goal:** study **Sakinah (سكينتي)**, **Ayat (آيات / KSU)**, **QuranFlash (قرآن
فلاش)**, **Khatmah (ختمة)**; propose a concrete shortlist; build the subset the
owner approves.

**Do:**
- Research each app (store listings, official sites, reviews, screenshots) and
  write `PHASE2_RESEARCH.md`: a table of `feature · which app(s) · what it does ·
  build effort (S/M/L) · fit for Rafiq · data source needed`.
- Likely candidates (illustrative — the owner picks):
  - **Khatma / completion planner** ("ختمة"): daily reading target, progress
    ring, streak, reminders, multiple concurrent khatmas. Pure local state over
    the existing page/juz data — no new content needed.
  - **Bookmarks + "resume last read"** across mushaf / hadith / books (page
    persistence exists; generalize to named bookmarks).
  - **Memorization loop**: repeat an ayah / range N times with a gap (builds on
    `AyahAudioService`).
  - **Prayer tracker**, **dua collections**, **share ayah as image**,
    reading fonts / line spacing.
- **Check in with the owner on the shortlist before building.** Then build the
  approved items as their own mini-stages, each verified, each checkpointed.
- **Rule 2 stands:** ideas/UX only from QuranFlash — zero data, zero assets,
  zero scraping. Everything backed by real data or an honest empty state.

**Acceptance:** `PHASE2_RESEARCH.md` exists with the table; the owner-approved
features work on the emulator against real data with no mock content.

---

## P2‑9 — Hosting & cost guardrails (Cloudflare R2 / Firebase / GitHub)

**Goal:** a written hosting plan the owner can act on, the client wired to
whatever he provisions, and **nothing that can cost money**.

**OWNER-BLOCKER:** an agent session cannot log into his Cloudflare, Firebase, or
GitHub. This stage produces `HOSTING.md` + client wiring; the owner does the
console steps.

**Do:**
- Write `HOSTING.md`:
  - **What content exists and its size** — mushaf SVGs per edition, `hadith.zip`
    (~17 MB), book PDFs (catalog), adhan video (P2‑6), translations.
  - **Recommendation: keep everything on Cloudflare R2 + GitHub raw (pinned
    commits).** R2 free tier = 10 GB storage, 10 M Class-A + 1 M Class-B
    ops/month, **zero egress fees** — the right home for static content.
    GitHub raw is fine for pinned dev use but **is not a CDN** — mirror to R2
    before public launch (already flagged `HANDOVER.md` §5.5).
  - **Do NOT enable Firebase Blaze or anything requiring a card.** The app has
    no auth and no sync today, so Firebase earns nothing. If a real dynamic
    need ever appears, Firestore's free tier (1 GiB, 50 k reads/day) is the
    ceiling — design to stay under it.
  - How to check usage: R2 dashboard metrics; GitHub has no raw-bandwidth
    billing but treat it as best-effort.
- Client wiring: confirm `lib/core/config/app_config.dart` points every remote
  URL at a stable host; make the mushaf base overridable
  (`--dart-define=RAFEEQ_MUSHAF_BASE=…`, already supported) and add the same
  seam for `contentBaseUrl` if missing.
- Re-flag: **rotate the exposed Cloudflare R2 API token** (`HANDOVER.md` §9) —
  owner action.

**Acceptance:** `HOSTING.md` reviewed by the owner; `AppConfig` has no host
that will bill; a build with the mushaf base override still works.

---

## P2‑10 — Lightweight / fast / secure / maintainable pass + release prep

**Goal:** the qualities the owner asked for, since he will study this codebase.

**Do:**
- **Size:** `flutter build apk --release --analyze-size`; remove unused assets;
  confirm the on-demand model (no heavy DB/media in `pubspec` `assets:` that
  could be downloaded instead). Target ≤ the Phase-1 release size, ideally less.
- **Speed:** check paging/scroll on a real low-end phone; if the mushaf SVG
  parse janks, precompile to `vector_graphics` `.vec` (**not** raster —
  `HANDOVER.md` §5.2). Profile the RGB backdrop.
- **Security:** re-confirm `AppConfig` secret-free; `.gitignore` still covers
  `.env` / keystores / `google-services.json`; no new cleartext URLs;
  `flutter analyze` clean.
- **Maintainability (for study):** doc-comment every public class/method added
  in Phase 2; keep the `core/` vs `features/` split; delete dead code; add a
  short `ARCHITECTURE.md` (layers, state management, where data comes from).
- **Usability:** every screen has loading / empty / error+retry states; back
  navigation is sane; large-text and RTL/LTR both hold in all 5 locales.
- `flutter test` green (including the new parity + buckwalter tests).
- **OWNER-BLOCKER:** real release keystore — the build still signs with the
  debug key (`android/app/build.gradle.kts` `// TODO`). The owner must supply
  the keystore/alias/passwords; no agent generates one.

**Acceptance:** release APK builds and runs on a real phone; size documented and
not larger than Phase 1; analyze + test clean; the architecture doc exists.

---

## Owner-blockers, collected

| Stage | Needs the owner to… |
|---|---|
| ~~P2‑1.5~~ | ~~logo PNG~~ — resolved: icon designed in-house |
| P2‑4 | clear the licence on al-Jaziri's *al-Fiqh ʿalā al-Madhāhib al-Arbaʿa* (1941) before it ships |
| P2‑7 | approve/provide a licence-clean background video for the video-adhan |
| P2‑8 | pick the competitor-feature shortlist before it's built |
| P2‑9 | do the Cloudflare / Firebase / GitHub console steps; rotate the R2 token — an agent session **cannot** log into these accounts (no passwords/OAuth/account-settings, even with the owner's say-so) |
| P2‑10 | provide the real release keystore (alias + passwords) |

Everything else in Phase 2 is buildable without him — go.
