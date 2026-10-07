# Next session brief — 2026-10-08 ~02:00 Dubai

Read `CLAUDE.md` first (binding), then `TASK_FOLLOWUP.md` (its **Next step**
is the live truth), then this.

## Where things stand

- **Published: v3.81.0** (2026-10-07). `master` is well past it. The owner
  said **«متنشرش الا لما تخلص خالص»**: no release until everything below is
  done and seen.
- Verified 2026-10-08 ~02:00: `flutter analyze lib test` clean, 770 tests
  pass, hosted content answers 206 (hadith.zip, quiz bank, mushaf page,
  a translation, a book).

## Done on master since v3.81.0

| Item | Seen on device? |
|---|---|
| Quiz: 500 questions in en/fr/es/pt/ru/ur, bank version 5006, on R2 + content-mirror | **Yes** (fr, ru, ur) |
| Quiz answer letters per alphabet (A–D, А–Г, أ–د); quiz source line with English book names | **Yes** |
| Caravan game visuals: `caravan_scenery.dart` (sky, rays, clouds, hills, shaded dunes, shadows, dust, tassels) | **Yes** (Arabic) |
| Miqat card (Hajj) translated + ministry Arabic under it | No |
| Quote card: book/author in Latin script | No |
| Adhan names in 7 languages (`adhans.json` names + `common.lang_code`) | No |
| Makharij regions/places translated; app prose fixed to «الواو غير المدية» | No |
| Urdu «on this day» from ur.wikipedia (1,718 events, 63 empty days) | No |
| Kids stories: 355 caption lines x 6 languages, player shows them | **No — video would not play on the emulator (Avast, TRAPS 61)** |

## Next, in order

1. **Caravan game, leg 2** (owner: «كمل اللعبة … فيجوالي احمل واروع»).
   Madinah to the next city. The gate question and the arrival card's source
   come from the verified quiz bank (nothing invented); every new string in
   all 7 locales; same scenery layer. Keep each file under 800 lines.
2. **Device checks** for every «No» above, in a Latin locale and in Urdu.
   For the kids captions: turn Avast's shield off for the emulator, or check
   on a phone.
3. **Only then release 3.82.0** per CLAUDE.md §2.3: stop
   `RafeeqMirrorWatchdog` first (TRAPS 60), bump `pubspec` version, build
   with `build_github_release.bat`, delete v3.81.0 and its tag (keep v3.51.0
   and content-*), publish, verify the tag SHA equals HEAD, give the owner
   the release page and the direct APK link, restart the watchdog.

## Known, not fixed

- Urdu quiz source line mixes digit styles (author dates from catalogue
  `authorAr` are Arabic-Indic, the page number Western). Decide one style
  for ur app-wide.
- Sources screen keeps each source's own name (documented decision: a
  credit is not renamed); only the role line is translated.
