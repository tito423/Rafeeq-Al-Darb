

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

## P3-24 — Book download button should flip to a cancel state while downloading

`library_screen.dart` / `download_manager.dart` — when a book (image or
text) is downloading, the action button should read/act as "إلغاء" (cancel)
instead of staying a static "تنزيل". Not started — check whether
`DownloadManager` already exposes a `cancel(id)` the UI just isn't wired to
(the Mushaf/Recitation download tiles already have working cancel buttons
per P2-5 — reuse that pattern here rather than inventing a new one).

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

## P3-29 — Book text reader: still has old arrow-nav, no swipe/quick-scroll-bar

`book_text_reader_screen.dart` wasn't touched this round (P3-15's "page
navigation redesign" item, still open) — owner re-confirms on a freshly
downloaded book: arrows still there, no swipe, no fast-jump strip. A new
reference is coming ("هارفعلك صورة للمكتبة الشاملة" — Shamela's own reader,
"استخدم نفس التصميم اجمل وارقى لكن بنفس الثيماتنا" — adapt its layout
quality, keep our own theme/colours, not a literal skin). **Blocked on that
reference image** for the visual redesign; the swipe+scroll-bar navigation
change itself is unblocked and can proceed independently (same technique as
`azkar_section_screen.dart`'s new swipe handling, P3-11).

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

## P3-32 — Text-mode mushaf: ayah-end marker sits too low, needs alignment fix

`mushaf_text_page.dart`'s end-of-ayah ornament (the small numbered marker)
renders visually low relative to the text baseline — a real, fixable CSS/
layout-alignment bug. Not started.

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

## P3-35 — Ayah card: one play/stop toggle button, not two separate buttons

When the ayah-sciences card/sheet shows playback controls, collapse
play + stop into a single button that flips state (matches the existing
tasbeeh circle / khatma pattern of one affordance that toggles). Not
started.

## P3-36 — Home: changing the daily-hadith card should not scroll the page

`daily_hadith_card.dart`'s "reroll" button currently seems to cause the
whole Home `ListView` to jump/scroll to the top when pressed — should stay
put, only the card's own content should update. Real, fixable bug once
reproduced; not started.

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
| P3-24 | Book download button → cancel state while downloading | queued, unblocked |
| P3-25 | Downloads overview rows jump to their own tab | queued, unblocked |
| P3-26 | Persistent prayer notification still reported absent | **blocked on live device** (see P3-13/P3-19) |
| P3-27 | "Download full recitation" card under the reciter picker | queued, unblocked |
| P3-28 | Mushaf edition thumbnails | queued, **needs a per-edition licence/sourcing pass first** (see the QuranFlash warning above) |
| P3-29 | Book text reader nav/visual redesign | 🔶 nav part unblocked; visual part **blocked on owner's Shamela-app reference image** |
| P3-30 | "Azkar/Tasbeeh still old" | likely stale — **ask the owner to re-check on the batch-2+ APK** before rebuilding |
| P3-31 | ~20-source تفسير download section | queued, **needs a research/licence pass first**, same rigor as every other content source |
| P3-32 | Ayah-end marker misaligned in text mode | queued, unblocked |
| P3-33 | Tafsir tab → single dropdown + inline download | queued, unblocked, ties to P3-31 |
| P3-34 | Text mode: scroll/speed control + toolbar icon redesign+captions+animation | queued, unblocked (re-verify scroll didn't regress) |
| P3-35 | Ayah card: single play/stop toggle button | queued, unblocked |
| P3-36 | Home: hadith reroll shouldn't scroll the page | queued, unblocked |
| P3-37 | App display name follows device system language on first run | queued, unblocked |
