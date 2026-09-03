# PHASE 3 — Real-device feedback pass (owner, 2026-09-03)

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
| P3‑4 | Home screen redesign (RGB info card, per-card Islamic pattern bg, interactive prayer card, hadith/khatma/continue-reading cards) | queued, blocked in part by P3‑5 |
| P3‑5 | **Login / accounts — architecture decision** | **blocked on owner: mandatory vs optional** |
| P3‑6 | Khatma card bugs + redesign | 🔶 nav bug fixed, undo added, duplicate label removed; full visual redesign still open |
| P3‑7 | Adhan: confirmed real bugs + feature requests | 🔶 auto-play-on-select DONE; bug half **blocked on live device/logcat** (see P3‑19 for a real, concrete Android-14 lead found by code review) |
| P3‑8 | Mushaf reader: confirmed real bugs + feature requests | queued, some unblocked now |
| P3‑9 | Search & tafsir correctness bugs | 🔶 both search bugs fixed (فاسقين dagger-alif bug + نشورا/منشورا word-boundary bug); tafsir-ayah-link + non-Hafs-gating still open |
| P3‑10 | "معاني الكلمات" tab — remove unless a real source is found | ✅ done — tab removed |
| P3‑11 | Azkar redesign (remove intro, swipe nav, grid hub) | 🔶 intro filtered + swipe nav DONE; grid-hub visual redesign to match reference still open |
| P3‑12 | Tasbeeh redesign to match reference | queued, unblocked |
| P3‑13 | Persistent prayer notification — confirmed real bug + "must not be dismissible" | **blocked on live device/logcat** — a dead second implementation found + removed along the way, see P3‑19 |
| P3‑14 | Settings: Russian bug (screenshot still owed), French locale | partially blocked (screenshot) |
| P3‑15 | Library: slow reader, page-nav redesign, مكتبتي split, catalog scope | 🔶 catalog +3 books DONE, مكتبتي split DONE; reader speed + page-nav redesign still open |
| P3‑16 | New "الصلاة" bottom-nav tab incl. professional Qibla compass | queued, unblocked (feeds P3‑4) |
| P3‑17 | R2 hosting migration | ✅ done this session, see `HOSTING.md` — rotate token / old-bucket decision still open |
| P3‑18 | P2‑8 items already approved (#11 app-lock, #12 group khatma w/ real sign-in) | queued, **#12 folds into P3‑5** |
| P3‑19 | Dead native notification code found + removed; Android-14 full-screen-intent permission gap found | ✅ cleanup done; the permission-prompt card itself not yet built |

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

**Blocked in part:** the "مرحبا بك يا `<username>`" piece needs P3‑5
resolved first (there is no username to show without accounts). Everything
else (date row, calm card backgrounds, hadith-card ornamentation, prayer
chips) can proceed independently.

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

**Confirmed real bug:** no working back button in the reader — an error
indicator shows top-right on open, and the phone's back gesture **exits the
whole app** instead of closing the reader (very likely the same class of
mistake the `AdhanFullScreenScreen` `PopScope(canPop:false)` bug was, per
`HANDOVER.md` STAGE 1 — check there first for the pattern).

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

## P3‑11 — Azkar redesign

- Remove the "المقدمة" (intro) section entirely.
- Remove the bottom arrow navigation buttons; navigate by **swipe**, in the
  direction matching the app's current language (RTL for Arabic).
- `design_refs/ref_azkar_hub.jpg` is the reference for the hub screen's
  look — a grid of dhikr-category cards (أذكار المساء / الصباح / التسبيح
  والتحميد / أذكار النوم / أدعية قرآنية / الاستغفار) with a featured
  "current time of day" card on top and a subtitle "من حصن المسلم وكتب
  السنة" — close to what Rafiq's own Azkar hub already has conceptually
  (134 real sections, sourced), this is mainly a visual-layer redesign, not
  new content.

## P3‑12 — Tasbeeh redesign

`design_refs/ref_tasbeeh.jpg` is the reference: a big glowing circular
counter (dark card, teal glow ring, large Arabic-Indic digit, "اضغط
للتسبيح" hint), 4 colored pill buttons above for the four standard dhikr
(different color per one — gold/violet/green/blue), a round count reset
button below, "عدد الجولات" (rounds) counter, a "المجموع" total chip
top-left, a trash/clear icon top-right. Existing `تسبيح` feature (STAGE 3,
33/100/1000 targets) has the real data/logic already — this is a visual
redesign matching this reference, and ties into P3‑2's rename.

## P3‑13 — Persistent prayer status notification

**Confirmed real bugs, need live device/logcat:**
- Doesn't appear at all on the real device ("مش شغال يا معلم").
- When swiped away from the shade, it must **not** be removable — should
  behave as a true always-on notification Android can't casually dismiss
  (current code already sets `ongoing`/`autoCancel:false` — either that
  isn't taking effect on this OS version, or the notification isn't being
  posted at all; same investigation as P3‑7).

## P3‑14 — Settings

- **Russian locale bug/"catastrophe"** — screenshot still owed by the
  owner; don't guess at this one, wait for it.
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
Not yet built: a check (`NotificationManager.canUseFullScreenIntent()`) +
a settings card prompting the user to grant it, mirroring the existing
battery-optimization-exemption card's pattern. Worth doing regardless of
whether it turns out to be *the* cause here — it's a real gap either way
on a modern Android target.

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
