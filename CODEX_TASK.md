# Task brief — the Hajj/Umrah guide and the tajweed «استماع» button

You are working on **Rafiq Al-Darb / رفيق الدرب**, a personal, sideloaded
Android Islamic app in Flutter (`rafeeq_app/`). The owner writes in Egyptian
Arabic; reply to him in Arabic. Code, comments and commit messages stay in
English.

**Read `CLAUDE.md` first — it is binding**, especially §1.1 (nothing fake),
§1.2 (religious content), §1.3 (nothing is done until it has been run on a
device and seen) and §3 (the traps this project has already paid for).

---

## 0. Before you touch anything: the restore point

The owner asked for this work to be undoable. Do not disturb:

| | |
|---|---|
| `known-good/v3.51.0` | a branch that must never move |
| `backup-2026-09-21c`, `v3.51.0` | tags on the same commit |
| `../Rafeeq-Backups/Rafeeq-Al-Darb-2026-09-21.bundle` | 693,194,105 B, complete history, verified |
| `RESTORE.md` | how to come back |

Work on `master` or a branch of your own. **Never force-push `master`
without `--force-with-lease`, and never delete or move those refs.**

---

## 1. The Hajj & Umrah guide — five faults he found

Everything below lives in two files:

* `rafeeq_app/lib/features/hajj/data/hajj_guide.dart` — the model and the
  chapter list
* `rafeeq_app/lib/features/hajj/presentation/hajj_screen.dart` — the screen
* widgets: `journey_map.dart`, `tawaf_counter.dart`, `sai_counter.dart`,
  `jamarat_counter.dart`

### How it works today

`hajjSteps` is a list of `HajjStep`, each one a **page/paragraph range into
an-Nawawi's «الإيضاح في مناسك الحج والعمرة»** (book id
`al_idah_fi_manasik_al_hajj_wal_umrah`, Shamela 96232). The screen cuts the
book with the app's own reader and shows the slice. Each step carries:

* `tracks` — `{hajj}`, `{umrah}` or `_both`
* `rite` — `HajjRite.journey | tawaf | sai | jamarat`, which is what puts the
  animated map or a counter on that step; **null means no visual at all**
* `dayKey` — the day label under the title

`hajjStepsFor(track)` filters by track, and for Umrah moves the `umrah`
step to the front.

### 1.1 The Umrah tab opens on «الباب الرابع»

> «العمرة اول تاب فيها بادئ بكلمة الباب الرابع ده شئ سئ»

The `umrah` step is the slice `fromPage: 378 … toPage: 387`, and
an-Nawawi's own text there begins «الباب الرابع / في العمرة وفيه مسائل».
Moving that chapter to the front (which an earlier session did on purpose,
because the Umrah track used to have nothing of its own) exposed the book's
internal numbering as the first words a reader sees.

**Do not rewrite an-Nawawi's text** (CLAUDE.md §1.2 — the text is the
source's, not ours). Fix the presentation instead: the step's own title is
already «العمرة», so the body should not repeat the chapter heading. The
tajweed screens solve exactly this problem — see
`jazariyyahBare` / `tamhidBare` in the tajweed feature, which drop a leading
paragraph that merely repeats the lesson's own title. **Read trap #47 in
`CLAUDE.md` before you copy that pattern**: both of those normalisers once
returned the empty string for every Arabic input and silently ate whole
lessons, and the tests could not see it because they compared two empty
strings. Whatever you write, first assert the normaliser returns something.

### 1.2 The last two chapters do not belong on the Umrah track

> «اخر تابين حج الصبي ووصايا للحاج مش مناسبة»

`child` (حج الصبي) and `counsel` (وصايا للحاج) are declared `tracks: _both`,
so they appear at the end of the **Umrah** list too. حج الصبي on an Umrah
track is simply wrong. Decide with the owner whether `counsel` is general
enough to keep; `child` is not.

### 1.3 العمرة appears inside the Hajj track as well

> «والعمرة نفسها موجودة في قسم الحج»

The `umrah` step is `_both`, so it is item 15 of the Hajj list AND the first
tab of the Umrah list. A reader on the Hajj track meets a chapter that has
its own track. Either scope it to `{umrah}` or make its appearance in the
Hajj list a pointer to that track rather than a repeat of the same text.

### 1.4 The Kaaba animation does not run on the Umrah tab

> «والانيمشن بتاع الكعبة في العمرة مابتشتغل»

`journey_map.dart` is attached through `rite`. The `umrah` step declares
**no `rite`**, so the map is not built at all — what he sees is the static
header illustration. Umrah's own rites are طواف and سعي; consider
`HajjRite.tawaf` for it, or give the Umrah track its own short map
(إحرام → طواف → سعي → حلق). Whatever you choose, **open it on a device and
watch it move** — a `rite` that builds the widget but leaves the controller
stopped looks identical to no animation in a screenshot.

### 1.5 The section wants tidying generally

> «نسق القسم ده وظبطه»

Take the two tracks as a whole: what a person doing Umrah needs, in order,
and what a person doing Hajj needs, in order, with nothing from the other
track in between.

---

## 2. The «استماع» button on the tajweed pages sounds bad

> «في زر استماع في صفحة التجويد جربته ووحش اوي وشكله هيبقى سئ جدا في
> التجويد كله»

* The button is `ListenTextButton`
  (`rafeeq_app/lib/features/library/presentation/widgets/listen_text_button.dart`),
  used by `jazariyyah_level_screen.dart:246`, `tamhid_level_screen.dart:243`,
  `tuhfa_level_screen.dart:266` and `hajj_screen.dart:363`.
* It speaks through `BookSpeaker`
  (`rafeeq_app/lib/features/library/data/book_speaker.dart`), which wraps
  **`FlutterTts` — the phone's own TTS engine**, cutting the passage on
  Arabic sentence marks at `_maxChunk = 3500`.
* It was deliberately enabled on tajweed lessons **only where the passage is
  ≥ 80 % vowelled** — and that is exactly the text a generic Android engine
  reads worst, because it tries to pronounce every حركة. The mutoon are
  *verse*, meant to be chanted, not read out by a screen reader.

Three honest directions, in the order I would try them:

1. **Do not offer it where it cannot sound right.** A silent absence is
   better than a bad recitation of ابن الجزري. This is the smallest change
   and needs no new content.
2. **Route it through the app's own voice.** The project already ships a
   downloadable neural voice — `OpenVoice`
   (`rafeeq_app/lib/features/library/data/tts/open_voice.dart`), 310 MB of
   ONNX on R2 under `tts/open_ar_v1/`. Compare it against the device engine
   on the same passage before deciding.
3. **Record the mutoon properly.** The right answer for verse, and the
   expensive one. If you go here, CLAUDE.md §1.1 applies in full: no entry
   in a catalogue before its audio resolves on the public endpoint.

**Whatever you do, listen to it.** The owner did, which is why this is on
the list.

---

## 3. Not a fault

> «صورة المستوى التاني متن الجزرية ده عادي»

He looked at the level-two header and it is fine. Leave it.

---

## 4. House rules that will catch you out

These have each cost this project real time. The full list is `CLAUDE.md` §3.

* **Nothing is done until it has been run on a device and seen.**
  `flutter analyze` and `flutter test` passing means it compiles.
* **A missing translation key renders as the key itself** (trap #8). It
  shipped to the owner's phone twice in one day («tutorial.title» on a
  card). `flutter test test/literal_translation_keys_test.dart` catches it.
  A key must be added to **all 7** locale files or
  `translation_parity_test` fails.
* **`adb install -r` fails silently** when the device holds a build signed
  with a different key: `INSTALL_FAILED_UPDATE_INCOMPATIBLE` goes to stderr
  and any `| tail` swallows it. Uninstall first, and read the output. This
  produced two false "verifications" in one session.
* **Do not navigate the emulator by guessing coordinates.**
  `adb shell uiautomator dump /sdcard/ui.xml` gives every element's
  `content-desc` and `bounds`.
* **Never reach for SQLite FTS5** (trap #1) and never load a whole corpus in
  one query (trap #4).
* **Do not publish a release** unless the owner asks, and build it only with
  `build_github_release.bat` (trap #41 — the release is signed outside
  Gradle, with a key lineage).
* **Report measured numbers, and say plainly what you have not seen.**

## 5. The definition of done

1. `cd rafeeq_app && flutter analyze lib test` → **No issues found**
2. `flutter test` → all pass (453 at the time of writing)
3. Run it on `emulator-5554` or a phone and **see** each change
4. `HANDOVER.md` updated
5. Committed and pushed
