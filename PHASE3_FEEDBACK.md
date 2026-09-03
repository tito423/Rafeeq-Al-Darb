# PHASE 3 FEEDBACK (raw source) — see `PHASE3.md` for the working task list

**This file is the verbatim record of the owner's first big feedback message
only.** Two more messages followed the same day: (1) an app-icon reference
image + a request to restyle the RGB theme toward the tasbeeh reference's
look, (2) four reference screenshots (tasbeeh, Azkar hub, Home, and the icon
installed) with "take the design of the rest of the images and build
typical/similar ones." All three messages are now organized together as
numbered, working tasks in **`PHASE3.md`** — read that file first; come back
to this one only for the owner's exact original wording on an item.
Reference images live in `design_refs/` (`ref_tasbeeh.jpg`, `ref_azkar_hub.jpg`,
`ref_home.jpg`, `ref_icon_installed.jpg`).

---

# PHASE 3 — Owner real-device feedback (2026-09-03)

**Source:** the owner installed the debug APK built this session
(`p2-7-test-apk-2026-09-03` on `tito423/rafeeq-api`) on his real phone and
sent one long message of everything he found, in his own words, in one pass.
**This file is the verbatim backlog, organized so nothing gets lost** — do
not start building from memory of the chat; read this file, and update it
(check items off, add findings) the same way `PHASE2.md` was worked through.

**Two items here are especially important:** #P7 and #P6 are **confirmed
real bugs on a real device**, not the emulator limitation `PHASE2.md`/
`NEXT_SESSION_PROMPT.md` suspected — P2‑7's full-screen intent genuinely does
not fire, and P2‑6's persistent notification genuinely does not appear. This
resolves the open question from the last handover: it is real code, not an
emulator artifact, and needs real debugging (ideally live `adb logcat` while
reproducing on the connected phone).

**Do not build blind on the items marked 🖼️ needs image** — the owner said
he'll send reference screenshots/photos for these; wait for them or ask
again rather than guessing a design.

---

## A. Architecture decision needed before touching this (ask first)

- **A1 — Home card + login.** Owner wants the Home header ("رفيق الدرب" /
  "صباح الخير رفيق الدرب") replaced by a fixed RGB card (same in every
  theme) showing Hijri date (far right) / "مرحبا بك يا `<username>`" (center)
  / Gregorian date (far left). This requires **user accounts** — his words:
  "لازم في بداية التطبيق تسجيل الدخول عشان بيانات المستخدم تتحفظ" (login
  must happen at the start of the app so user data persists) — for khatma
  progress, azkar state, and settings to be "his."
  **This reverses a deliberate, documented architecture decision**
  (`HANDOVER.md` STAGE 7: "guest mode is the only mode," zero auth code,
  by design) — not a small UI tweak. It also lines up with the P2‑8 #12
  decision already made this session (real Google Sign-In, approved) but
  goes further: #12 only needed accounts for *group khatma*; this asks for
  accounts to gate the *entire app* at first launch.
  **Open question for the owner:** is login **mandatory** at first launch
  (no using the app at all before signing in), or **optional** (guest mode
  still works exactly as today, but signing in adds the personalized
  card + cross-device sync)? This changes the whole onboarding flow and is
  worth one explicit answer before any code.
- **A2 — Library scope.** "المكتبة مفيش فيها الا خمس كتب... عايزك تنزلهم
  كلهم بشكل الشاملة" (only 5 books, download them all, Shamela-style).
  Al-Maktaba al-Shamela indexes on the order of **thousands** of titles.
  Needs a scoping answer: a much larger curated list (tens to a couple
  hundred titles, still individually licence-checked like the existing 5),
  or something closer to a full mirror (a very different, much bigger
  scraping/storage project, and every title still needs the same PD/licence
  check §5.7 already requires — this would take a long time to do honestly,
  one title at a time, not a bulk import)? Needs a target count or a
  category list from the owner before scripting a scraper.

## B. Waiting on owner-supplied images (🖼️) before building

- **B1** 🖼️ Prayer-times card — owner wants it "تفاعلي" (interactive),
  animated, RGB in every theme; a reference image is coming.
- **B2** 🖼️ Khatma card redesign — reference is another app called "ختمة".
- **B3** 🖼️ Tasbeeh (digital counter) redesign — reference image coming.
- **B4** 🖼️ Settings → Russian locale — "كارثة" (a real bug/crash), screenshot
  coming to show exactly what's wrong.

## C. Confirmed real bugs (real device, not emulator) — high priority

- **P7 — Adhan full-screen still does not render on a real device.**
  Pressing "تجربة" (test): a notification appears, its **buttons don't
  work** (Stop/Mute do nothing), and the **full-screen karaoke/video screen
  never appears at all**. This is the same mechanism `NEXT_SESSION_PROMPT.md`
  flagged as "if it fails on a real device too, this is now a real bug, not
  an emulator limit — trace `adhan_navigation.dart`'s `openAdhanFromPayload`
  with live `adb logcat`." **Next step: get the phone connected via USB with
  USB-debugging on, reproduce, and read the actual logcat output at the
  moment of the tap** — guessing without logs isn't worth it a second time.
- **P6 — Persistent prayer status notification does not appear at all**
  on the real device ("الاشعار الثابت بوقت الصلاة القادمة مش شغال يا
  معلم"). Also: **when swiped away it must not be removable** — Android
  should not be able to kill it; it should behave like a true ongoing
  notification that reappears. (Current code sets `ongoing`/`autoCancel:
  false`; either that isn't taking effect on this OS version, or the
  channel/notification isn't being posted at all on this device — needs the
  same live-logcat treatment as P7.)
- **Khatma card → "افتح المصحف" does nothing** — taps do not open the
  reader; the app just falls back to the Home screen. Real navigation bug.
- **Mushaf reader (any mode: text/image/Sunan as-Suwar single-surah) has no
  working back button.** An error indicator shows top-right on open, and
  using the phone's own back gesture **exits the entire app** instead of
  just closing the reader — this is a real, severe navigation bug (likely a
  missing `PopScope`/route-stack issue, possibly related to how
  `AdhanFullScreenScreen`'s `PopScope(canPop:false)` bug was fixed before —
  check for the same class of mistake here).
- **Adhan test/selection audio doesn't stop the previous one.** Playing an
  adhan preview, then picking a different one while the first is still
  playing, should stop/silence the first and play the new one — currently
  both can end up overlapping or the first doesn't stop.
- **Search: substring match instead of exact/word match.** Searching
  "نشورا" returns ayahs containing "منشورا" (matches inside a longer word).
  Needs word-boundary-aware matching, not `LIKE '%term%'` as-is.
- **Search: "فاسقين" doesn't return a correct result at all** — needs the
  normalization path checked for correctness on real vocalized/undiacritized
  input (this is the same `arabic_normalize.dart` path Stage 6 built —
  re-verify it against real queries, not just the emulator's inability to
  type Arabic, which is what blocked testing it before).
- **Tafsir not correctly linked to the right ayahs** — a real data/lookup
  mismatch, not just "unavailable for non-Hafs" (see D below, which is the
  separate non-Hafs-numbering issue).
- **Mushaf paging looks like it re-fetches per page instead of using the
  local cache** — "حسيته بيحملها تقريبا لانه شغال من api" (feels like it's
  loading from the API each time). Re-check `MushafPageService`'s disk-cache
  hit path; the owner is explicit this is high priority: pages must be
  cached and read locally once downloaded, every time after.
- **Book (image PDF) reader is very slow** ("بطيء جدًا جدًا جدًا").

## D. Known/expected gaps, now flagged by the owner as needing real fixes

- **D1 — Tafsir/translation for non-Hafs riwayat editions** needs fixing
  (`اظبط`) — re-check `MushafEdition.sciencesAvailableFor` and whether the
  gating message is showing where it shouldn't, or real content is missing
  where it should exist.
- **D2 — "معاني الكلمات" tab**: remove the current English-gloss version
  entirely UNLESS a real Arabic *gharib al-Qur'an* source is found and
  wired in properly. `PHASE2_RESEARCH.md`'s word-meanings section already
  found one real PD candidate (al-Rāghib al-Iṣfahānī's *al-Mufradat*, root-
  indexed, needs a matching pipeline against `word_grammar.root`) — either
  finish that pipeline or delete the tab; do not ship the English-gloss
  stopgap as "معاني الكلمات" any longer, the owner was explicit about this
  before and is repeating it now.

## E. UI/UX requests — Home & general

- **E1** RGB-styled, theme-aware calm Islamic-pattern background on every
  card app-wide (not just Home).
- **E2** New bottom-nav tab **"الصلاة"** (Prayer) — consolidates: prayer
  time settings, reminders/alerts (today spread across Adhan settings +
  the P2‑6 toggle), **and a new, visually polished Qibla-compass tab**
  ("باحترافية شديدة جدا... روعه بصريا") — a real compass using the device's
  magnetometer + location, not a static arrow.
- **E3** Next-prayer display should be animated/interactive with a live
  seconds countdown, polished visual design — this elevates the existing
  Home prayer card, doesn't just move it.

## F. Khatma card

- **F1** Fix the duplicated "ختمة جديدة" label (appears twice — once below,
  once inside/on the button).
- **F2** Add an **undo** for "قرأت اليوم" (mark-today's-reading), in case of
  an accidental tap.
- **F3** (redesign — see B2)

## G. Mushaf reader (all modes)

- **G1** Bottom scroll strip tied to surah names for fast jump-navigation.
- **G2** Pinch-to-zoom missing in **both** text mode and image mode.
- **G3** Captions/labels under the Quran-tab toolbar icons explaining what
  each one does.
- **G4** First time opening the Quran tab: prompt the user to pick a mushaf
  edition, download it immediately, store in the local DB — "و أي حاجة
  تتحمل" (and the same for anything else that needs downloading).
- **G5** First app install: prompt to pick + download an **image mushaf
  edition** and a **recitation** — both flagged "أساسيين" (essential),
  i.e. part of first-run onboarding, not left for the user to discover.
- **G6** Verify whether the thematic-search per-ayah play button streams or
  caches locally, and make it cache like the rest of `AyahAudioService`.

## H. Settings

- **H1** Russian locale bug/crash (see B4, waiting on screenshot).
- **H2** French is listed as a supported language but isn't actually wired
  in properly — fix it for real (re-check `main.dart` `supportedLocales` and
  the language picker against actual `fr.json` presence/parity — Phase 2's
  own locale set was ar/en/es/ru/pt; French was never one of the 5, so this
  needs scoping: is this a 6th locale to add from scratch, full parity
  translation work like P2‑3, or did the owner mean something already
  partially there?).

## I. Azkar

- **I1** Remove the intro/"المقدمة" section entirely.
- **I2** Remove the bottom arrow navigation buttons; swipe instead, in the
  direction matching the app's current language (RTL for Arabic: swipe
  toward start = next item, etc.).
- **I3** Tasbeeh redesign (see B3).

## J. Adhan

- **J1** New setting: let the user choose whether the adhan alert should be
  **full-screen regardless of lock state** (today it's presumably
  lock-screen-only via `fullScreenIntent`) — i.e. also full-screen when the
  phone is unlocked/in-hand.
- **J2** Stop/Mute buttons on the adhan alert notification don't work — real
  bug (see P7 above, same investigation).
- **J3** Owner will supply **10 of his own adhan audio files** — remove
  every currently-bundled adhan sound, he doesn't like any of them.
- **J4** Picking an adhan in the list should **auto-play immediately** as a
  preview, not require a separate play tap.
- **J5** Add a dedicated **preview button for the adhan VIDEO** clips (today
  only audio has a preview, per the existing code).
- **J6** Redesign the "طريقة العرض" (audio/video) and "الأذان الافتراضي"
  (default adhan) pickers as a nice card with a dropdown; additionally, let
  the user choose **how** picker UIs present across the app in general —
  popup/dropdown-style vs. full-screen picker-style — as a preference.

## K. Downloads / Library

- **K1** Persistent prayer notification must not be dismissible by a shade
  swipe — should always come back (see P6).
- **K2** Book (PDF) reader page navigation is bad — replace with scroll +
  a fast jump strip; refresh the visual design; add pinch-zoom.
- **K3** "مكتبتي" should split into two clearly separate sub-sections —
  **مصور** and **نصي** — instead of both edition names stacked together
  confusingly under one entry.
- **K4** Library catalog expansion (see A2 — needs a scoping answer first).

---

## Suggested next steps (not yet started, pending the owner's answers above)

1. Get the phone connected to this PC over USB (owner has it in hand right
   now) and pull live `adb logcat` while reproducing **P7** and **P6** —
   highest-value single next action, since guessing at these twice already
   didn't work.
2. Answer **A1** (mandatory vs optional login) and **A2** (library scope) —
   both change the shape of a lot of downstream work.
3. Send the **B1–B4** reference images/screenshots.
4. Once P7/P6 are actually understood, fix the clear, self-contained bugs
   that need no design input and no owner answer first: khatma "افتح
   المصحف" nav bug, mushaf reader back-button/PopScope bug, search
   substring-match bug, adhan-overlap-on-reselect bug, mushaf page caching.
