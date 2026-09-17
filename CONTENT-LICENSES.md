# CONTENT-LICENSES — where every text in رفيق الدرب comes from, and what is known about the right to ship it

**Started 2026-09-17.** This file is the project's record of provenance. It
exists because the app **redistributes** content — it rehosts text on its own
R2 bucket and ships it inside an APK — and redistribution is a different act
from reading.

## What this file is, and is not

It is a record of **what was measured and when**, so that any claim in it can
be re-checked. Every number here was produced by a script in `scripts/` that
can be run again.

It is **not a legal opinion**, and nothing in it should be read as one. Where
the position is unclear it says so. A definitive answer on copyright — and on
the sharʿī question of intellectual-property rights, on which contemporary
scholars differ — needs a lawyer or a scholar, not this repository.

Statuses used below describe **evidence**, not legality:

| status | meaning |
|---|---|
| `AUTHOR_LONG_DEAD` | the author died more than 50 years ago; the work itself is out of copyright under the rule this project works to |
| `STATED_LICENCE` | the source publishes a licence, and it is named here |
| `NO_LICENCE_STATED` | the source publishes no licence and grants nothing; whatever we take must stand on its own |
| `MODERN_MATERIAL_PRESENT` | a modern person's own work is inside what we ship |
| `NEEDS_REVIEW` | not settled; named here so it is not forgotten |

## The rule this project works to, and the law that says so

**Author's death + 50 years.** The project adopted this from Egyptian law. On
2026-09-17 the owner supplied the UAE statute — where he actually lives — and
it was read directly rather than summarised from a search result.

**مرسوم بقانون اتحادي رقم (38) لسنة 2021 في شأن حقوق المؤلف والحقوق المجاورة**
(the law he first sent, Federal Law 11/2021, is **industrial** property —
patents, industrial designs, integrated circuits — and has nothing to do with
books). Term: the author's life **and 50 years** from the first day of the
Gregorian year following his death.

Three of its provisions decide almost everything in this file, quoted from the
official gazette text, pages 430–431:

> **المادة (2)** … ١٢. المصنفات المشتقة، دون الإخلال بالحماية المقررة
> للمصنفات التي اشتقت منها.
> وتشمل الحماية **عنوان المصنف إذا كان مبتكراً**.

> **«المصنف المشتق»**: المصنف الذي يستمد أصله من مصنف سابق الوجود
> **كالترجمات**، ومجموعات المصنفات الأدبية والفنية … **ما دامت مبتكرة من حيث
> ترتيب أو اختيار محتوياتها**.

> **المادة (3)** لا تشمل الحماية ما يأتي: … ٤. **المصنفات التي آلت إلى الملك
> العام**.
> **ومع ذلك تتمتع مجموعات** ما ورد في البنود (2)، (3)، (4) من هذه المادة
> **بالحماية إذا تميز جمعها أو ترتيبها أو أي مجهود فيها بالابتكار**.

So, in the law's own words rather than by inference:

1. **an-Nawawi's text is free.** A work in the public domain is excluded from
   protection outright — Article 3(4).
2. **A COLLECTION of free works is not free**, if its gathering, its
   arrangement, or any effort in it is marked by innovation — the sentence that
   immediately follows. That is exactly حصن المسلم: the supplications are
   prophetic and free, and **the selection and the arrangement are
   al-Qahtani's**. The law names this case; it was not a theory.
3. **A translation is a protected work in its own right**, «دون الإخلال
   بالحماية المقررة للمصنفات التي اشتقت منها» — the Qur'an being free does not
   make a translation of it free. This settles section 2 below.

What is still **not** answered, and is not being guessed at: whether a
muhaqqiq's critical apparatus over a public-domain matn is protected as a
derivative work or simply as his own writing. Under Article 2(1) his footnotes
are his own text either way, which is the ground today's filtering stands on.

None of this is legal advice, and the sharʿī question of intellectual-property
rights — on which contemporary scholars differ — is a separate matter for a
scholar.

The distinction that matters, and it is not a technicality:

* an-Nawawi died in 676 AH. Nothing anyone does to his text in 1994 makes his
  words theirs.
* But a muhaqqiq's **own additions** — his footnotes, his takhrij, his isnad
  criticism, his introduction, his indexes — are his own work, and they are
  recent.

So the question that decides the risk is not «is the book old?» and not «is it
on Shamela?». It is: **is the modern editor's apparatus inside the file we
actually ship?** That is measurable, and it has now been measured.

---

## 1. المكتبة الشاملة — the library's 249 books

### What Shamela itself says — read on 2026-09-17, not remembered

| checked | result |
|---|---|
| `https://shamela.ws/robots.txt` | **HTTP 404** — no crawl rules are published at all |
| `https://shamela.ws/page/terms` | **404** |
| `https://shamela.ws/page/rights` | **404** |
| `https://shamela.ws/page/license` | **404** |
| «حول المشروع» (a modal on every page) | «مشروع مجاني لا يهدف للربح **ولا يتلقى مقابل من المؤلفين نظير نشر كتبهم**» |
| `https://shamela.ws/page/contribute` | «المكتبة الشاملة مشروع مجاني لا يهدف للربح وجميع المساهمات توجه للمصاريف التشغيلية من **صف وتدقيق للكتب** ونحو ذلك» |
| `https://shamela.ws/page/download` | the whole library is offered as a free data folder for Windows, macOS and Linux |

Two conclusions, and only two:

1. **Nothing prohibits reading the site.** There is no robots.txt to violate,
   no terms to breach, no access control, no paywall, and what
   `scripts/build_book_text.py` fetches is material the project itself offers
   for free download. The crawler identifies itself with a real User-Agent and
   works at a low rate.
2. **Shamela grants nobody any redistribution right.** It says in its own words
   that it does not take payment from authors for publishing their books — it
   does not claim to hold rights and it does not pass any on. So
   «المصدر: المكتبة الشاملة» on a card settles nothing.

Status: **`NO_LICENCE_STATED`.** Whatever we ship has to stand on the age of
what is in it.

### What is actually inside the 249 files we host — measured 2026-09-17

`py -3 scripts/audit_editor_apparatus.py` fetched **all 249** catalogued books
**from this project's own bucket** (so Shamela was not touched), read each
book's own edition card for the muhaqqiq and his death year, and counted the
paragraphs carrying his apparatus.

The signature is the one the azkar work had to learn by reading real pages: the
decisive mark is a paragraph **closing** with `(*)`, not one opening with
`(١)`. Requiring the opening let through a footnote that began with `=`, the
continuation marker — 750 words of isnad criticism that read as the author's.

| what the book is | before | **after** |
|---|---|---|
| no editor named on the card at all | 71 | **71** |
| editor named, died before 1396 AH | 4 | **4** |
| editor is modern, and NONE of his apparatus is in the file we ship | 126 | **173** |
| **editor is modern, and his apparatus IS in the file we ship** | **48** | **0** |
| | 249 | **248** |

**The «after» column is the state as of 2026-09-17, and it is measured, not
intended** — `audit_editor_apparatus.py` was run again over all 248 books after
the work below and returned **zero** in the row that matters.

### What was done to the 48

`scripts/strip_editor_apparatus.py` removes the apparatus and then measures
whether a book is still there. The number that decides it is **where the empty
pages fall**, not how many there are: a blank run at the **front** means the
editor's own introduction is gone and the author's book now starts where he
starts, which is the intended result; a run **inside** the book means it has
been gutted. `juz_bay_ummahat_al_awlad` loses 24 consecutive pages and keeps
82.7 % of its text, and those two numbers only make sense together once you
know the 24 are his front matter.

* **47 books were filtered and re-uploaded.** 34 of them keep ≥ 95 % of their
  text with no interior gap at all. The files went back over the same R2 keys,
  gzip with no `Content-Encoding` as standing policy requires, and
  `sizeBytes` and `pages` were rewritten in `book_catalog.dart` from **the
  bucket's own readback**, never from what the upload intended to send.
* **1 book was removed**, because filtering could not save it — see below.

**Verified, not assumed:** re-running the azkar extractor against the newly
filtered `al_adhkar_nawawi` produces the same 338 chapters and 1,392
paragraphs as before, with all 22 curated checksums still matching and **«0
footnotes dropped»** — they are already gone. Two independently written
filters agreeing to the byte is the strongest evidence available here. And on
the emulator, al-Adhkar opens on page 3 with an-Nawawi's own muqaddima and
**without** al-Arna'ut's footnote that used to sit on that page.

### The one book that had to go

**`al_ijaz_fi_sharh_sunan_abi_dawud`.** Filtering leaves **47.7 %** of the
text, **83 empty pages inside the book** and a run of **20** consecutive blanks;
the printing's own page 51 is a row of dots because that whole leaf is
footnote; and the pages that do survive still speak in the editor's voice —
«النسخة التي اعتمدناها في التحقيق». The file is أبو عبيدة مشهور بن حسن آل
سلمان's reconstruction from a manuscript, Dar al-Athariyyah 2007, and **he is
alive**. Removed from the catalogue and from the bucket on 2026-09-17, the way
the v3.29.0 purge sent the other 23. an-Nawawi keeps his other fifteen titles.

### Still open on the library

**The source label on a filtered book still names the muhaqqiq** — «تحقيق عبد
القادر الأرنؤوط» — which is true about where the text came from, but a reader
could take it to mean his edition is what they are getting. The honest form is
to say the text is that printing's **with the editor's notes removed**. That
wants one flag on `TextEdition` and one translated line in the reader, in all
seven locales, not 47 hand-edited labels.

~~**An already-downloaded book is not refreshed.**~~ **Fixed 2026-09-17.**
It was the defect that would have made all of the above pointless for the one
person who uses this app: `book_meta` carried no version, so a device holding a
pre-filter copy would have kept the editor's apparatus for ever while the card
said «تمّ التنزيل» — true and useless.

`isBookDownloaded` now compares the local file's byte length with the
catalogue's `sizeBytes`, which is measured from the bucket on every upload and
is never a number anybody types. A mismatch reads as «not downloaded», so the
book offers itself again.

That check is only as good as the catalogue, so the catalogue was checked
first: `py -3 scripts/verify_catalog_sizes.py` over all 248 books found **two
that had drifted** — `mawaiz_ibn_al_jawzi_al_yaqutah` by 7 bytes and
`bustan_al_arifin` by 14 — and both were corrected from the bucket's own
readback. It now reports **0 mismatches over 248**. (The first version of that
script reported five false ones, because R2 answers a plain `HEAD` for some
objects with no `Content-Length` at all; it uses a one-byte range GET and reads
`Content-Range` instead.)

### What it looked like before, for the record

The full pre-fix report, per book, with the editor named and the share of the
text that was his, is `scripts/_editor_apparatus_report.txt`. The worst:

| book | share of the file that is the editor's | editor |
|---|---|---|
| `al_ijaz_fi_sharh_sunan_abi_dawud` | **46.5 %** | أبو عبيدة مشهور بن حسن آل سلمان — **alive** |
| `masalah_fil_kanais` | 30.8 % | علي بن عبد العزيز الشبل |
| `amar_al_ayan` | 17.4 % | د. محمود محمد الطناحي |
| `al_adhkar_nawawi` | 17.0 % | عبد القادر الأرنؤوط (d. 1425 AH / 2004) |
| `qaidah_jalilah_fil_tawassul_wal_wasilah` | 11.4 % | ربيع بن هادي عمير المدخلي |
| `al_jami_fi_amthal_al_quran` | 10.5 % | الشيخ مصطفى العدوي — **alive** |

Status as of 2026-09-17: **resolved — 47 filtered, 1 removed, and the audit
re-run returns 0.**

### Books already removed on rights grounds

* **v3.29.0** removed **23** books whose authors are living or recently dead —
  al-Albani, Ibn Baz, an-Nadwi, al-Ghazali, al-Mubarakfuri, Khalid Muhammad
  Khalid, al-Qarni — and their files were deleted from the bucket.
  `scripts/_r2_purge.txt` is the record.
* **2026-09-17** removed **4** more that the purge had missed because they were
  catalogued under the classical author's name while containing only
  al-Albani's own takhrij: `tahqiq_riyad_al_salihin_lil_albani`,
  `tahqiq_al_iman`, `takhrij_al_kalim_al_tayyib`,
  `tahqiq_al_ihtijaj_bil_qadar`. Each was read before it was deleted.
  `scripts/_r2_dupe_purge.txt` is the record, and they can be rebuilt from
  Shamela 512, 264, 327 and the al-Ihtijaj id if that decision is reversed.
* **«رجال حول الرسول»** is deliberately absent although it was asked for by
  name: خالد محمد خالد died in 1996.

---

## 2. The Qur'an

| source | what it provides | status |
|---|---|---|
| quran.com / KFQC | the ʿUthmani text and page layout | `AUTHOR_LONG_DEAD` — the Qur'an is nobody's property. **`NEEDS_REVIEW`** for the *typesetting* of a specific printing, which is a publisher's work |
| api.alquran.cloud | **45** translations | **`STATED_LICENCE` — resolved 2026-09-17, see below** |
| quranpedia / quran-svg | the `hafs_kfqc` SVG glyph layer | **`NEEDS_REVIEW`** |

### The translations — settled, and three corrections to this document

An earlier draft of this file called the translations «the clearest unexamined
gap» and said nobody had recorded who translated each or under what terms.
**That was wrong on three counts, and each was found by looking at the repo
rather than recalling it.**

1. **The translator is recorded for every one.**
   `assets/data/catalogs/quran_translations.json` holds **45** entries — not
   47 — each with `lang`, `native_name`, `edition`, `translator`, `gz_bytes`,
   `ayahs`, `bundled`. Saheeh International, Julio Cortés, Muhammad
   Hamidullah, Besim Korkut, Ivan Hrbek, Bubenheim & Elyas, and so on.
2. **The translator is shown to the reader**, not just stored:
   `translation_tab.dart` renders him as the subtitle under every translation
   block.
3. **The upstream terms were readable and now have been read.**
   alquran.cloud's terms and conditions, read 2026-09-17: the Qur'an text may
   be reproduced, embedded, stored and displayed freely **for any
   non-commercial purpose**; «Translations are contributed by their
   rights-holders or sourced from public-domain editions. Each is delivered
   with its edition identifier intact»; and when republishing a translation you
   must **«attribute the translator by name»**. The text must not be altered or
   commingled with non-Qur'anic material in a way that could be mistaken for
   the Qur'an itself.

So the three conditions are the three things the app already does: it is free
and carries no advertising at all, it keeps each `edition` identifier verbatim,
and it prints the translator's name under his translation. **Compliant, and it
was compliant before this audit started** — which is worth writing down as
plainly as a defect would have been.

Under UAE law a translation *is* a protected derivative work (Article 2(12) and
the definition of المصنف المشتق, quoted at the top of this file). That is
exactly why the upstream permission matters, and why it was read rather than
assumed.

## 3. The mushaf page images — 6 printings

| printing | source item | licence recorded | status |
|---|---|---|---|
| مصحف قطر | archive.org `QuranMushafQatar` | **CC BY-NC-SA 3.0** | `STATED_LICENCE` — and it is *why* this one was chosen |
| المصحف المذهّب (Smart Mushaf) | archive.org `smartmushaf` | **CC BY-NC-ND** | **`NEEDS_REVIEW` — see the ND note below** |
| مصحف دولة الكويت | archive.org `HQ23…MushafDolatUlKuwait…`, Ministry of Awqaf | none recorded | **`NEEDS_REVIEW`** |
| مصحف المدينة — الطبعة الليلية | archive.org `QuranMadina35685363568hNight` | none recorded | **`NEEDS_REVIEW`** |
| مصحف التجويد الملوّن | Dar al-Ma'rifa colour-coded printing | none recorded | **`NEEDS_REVIEW`** |
| `hafs_kfqc` — مصحف المدينة، رواية حفص | quranpedia / quran-svg glyph layer | none recorded | **`NEEDS_REVIEW`** |

**All six were re-read from `https://archive.org/metadata/<id>` on 2026-09-17**,
and every one now carries `source`, `license` and `license_note` **inside
`editions.json` itself**. `test/mushaf_provenance_test.dart` fails the build if
a printing is added without them. «none stated» is a permitted value; an empty
one is not.

**The ND question, answered.** `madinah_gold` is `CC BY-NC-ND 4.0`.

* **NC** — satisfied. This app is free, refuses advertising on purpose, and
  sells nothing.
* **BY** — satisfied. «المصحف المذهّب (Smart Mushaf)» is credited on the
  Sources screen with a link to its item.
* **ND** — `r2_upload_mushaf_printings.py` takes the item's numbered JPEGs
  **as they are** and downscales them to 1200 px wide, because at ~800 KB a
  page the original set is ~490 MB and the screen it is going to is barely
  1080 px across. **No crop, no recolour, no recomposition.** Under the
  definition this file quotes at the top, a مصنف مشتق is one «مبتكرة من حيث
  ترتيب أو اختيار محتوياتها» — a resize adds nothing to arrangement or
  selection. An earlier draft of this document said the pipeline «trims the
  scan margin»; it does that for the **cover** thumbnails, not for the pages.

And the item's own description, which the uploader wrote in bold and
underlined, matters more than the licence code he attached to it:

> **The creator does not own the content.** The creator basically used the
> vector pages of the Qur'an already available in the internet and added colors
> and borders for visual purposes.

So what he could license at all is the colouring and the borders. That is not a
reason to ignore his terms, and they are not being ignored — it is a reason to
stop treating this as the file's most urgent open question. **Still not a legal
opinion.**

The two editions that state **no** licence — `tajweed_color` (creator recorded
as «dar al-ma'rifa, Beirut, Lebanon») and `madinah_night` (no creator, no
rights statement at all) — plus `kuwait`, are recorded as stating none, which
is the honest value. Reading their printed front and back matter, the way the
Taj Company scan was rejected (CLAUDE.md trap #18), is what would settle them.

The six were read out of `assets/data/mushaf/editions.json` on 2026-09-17, not
recalled: `hafs_kfqc`, `tajweed_color`, `madinah_gold`, `qatar`, `kuwait`,
`madinah_night`, 604 pages each. **مصحف الشمرلي is not among them** — an
earlier note claimed it was.

**`editions.json` carries no `source` and no `license` field for any edition.**
So the app has nowhere that records which scan a printing came from. That is a
gap in the data, not only in this document.

The precedent that governs this section is already written down as CLAUDE.md
trap #18: **a free scan is not automatically free to rehost.** The Taj Company
16-line mushaf was rejected precisely because its own last page prints «جملہ
حقوق محفوظ» and a copyright warning, although archive.org served it freely.
That judgement was made once, by rendering the back matter and reading it. It
has not been made for the five printings above.

## 4. Hadith

**What `hadith.db` actually ships — read from the bundled file on 2026-09-17,
not assumed.** The `hadiths` table has exactly these columns:

```
id, book_id, chapter_no, number_in_book, arabic, narrator_en, text_en, grade, grader
```

**There is no footnote, takhrij or hamesh column at all.** So whatever an
editor's apparatus a crawl had to read in order to build this database, none
of it reaches a device. That matters for مسند أحمد: the Risalah printing is
شعيب الأرنؤوط's (d. 1438 AH / 2016), and his footnotes had to be parsed to find
where each hadith ends — but they are not stored and not shipped.

| source | what it provides | status |
|---|---|---|
| sunnah.com — via `huggingface.co/datasets/meeAtif/hadith_datasets` | the per-hadith gradings | **`STATED_LICENCE` — MIT**, recorded in `scripts/build_hadith_db.py`'s own header |
| sunnah.com | the nine collections' matn | `AUTHOR_LONG_DEAD` |
| Shamela — مسند أحمد، ط الرسالة | Musnad Ahmad's matn | `AUTHOR_LONG_DEAD` for the matn; the editor's footnotes are **not** shipped (see above) |
| Shamela — سنن الدارمي ت حسين أسد | Sunan al-Darimi's matn | same shape; **`NEEDS_REVIEW`** only to confirm no apparatus leaked in |
| hadeethenc.com | 3,574 hadiths in 7 languages, with explanations and glossaries | **`STATED_LICENCE` — its terms were read on 2026-09-10**, before a byte was uploaded, and they permit it. See below |

**hadeethenc.com — a fourth correction to this document.** An earlier draft
said its terms «have never been read». They had been, on 2026-09-10, and the
reasoning is written into `AppConfig.hadeethEncUrl`'s own doc comment: the
publisher's «الشروط والسياسات» permits downloading and republishing the
translations on conditions — no modification, addition or deletion; clear
credit to the publisher and the source; the version number; and no advertising
unbefitting the content. The app modifies nothing, credits the source on the
collection screen, on every hadith and on the Sources screen, and carries no
advertising at all. That session cited CLAUDE.md trap #18 as its reason for
reading the terms first. Recording it here so the record is in one place.

**Gradings are a separate matter and are handled correctly.** Saying «صححه
الألباني» is a statement of fact about a hadith and is what CLAUDE.md §1.2
requires — a grading must name its grader. It is not a reproduction of his
book. Counted live in the bundled `hadith.db` on 2026-09-17: **45,219 rows
carry a `grade`, and 45,219 carry a `grader` — the two numbers are equal, so
not one grading in the database is anonymous.**

## 5. Everything else

| source | what it provides | status |
|---|---|---|
| everyayah.com, cdn.islamic.network, mp3quran.net | recitations | **`NEEDS_REVIEW`** — a recitation is a performance with a living reciter |
| Wikimedia Commons | images | per-file licences; the Commons search already filters for public domain, and its User-Agent rule is CLAUDE.md trap #38 |
| Wikimedia `onthisday` feed | the Gregorian day feed in 6 languages | CC BY-SA, Wikipedia's own licence |
| Arabic Wikipedia per-Hijri-day pages | 5,747 Hijri events | CC BY-SA |
| api.aladhan.com | prayer times | computed values, not copyrightable content |
| YouTube | dawah channel links | links only, nothing rehosted |
| الأذكار للنووي (`quran_sciences.db`) | **18 chapters, 48 supplications** | `AUTHOR_LONG_DEAD` — **replaced 2026-09-17**, see below |
| the quote of the day | 58 quotes from 4 books | `AUTHOR_LONG_DEAD` — rebuilt in v3.29.0 after the discovery that 284 of the previous 352 came from «لا تحزن», whose author is alive |
| the Hajj guide | an-Nawawi's «الإيضاح» | `AUTHOR_LONG_DEAD` — re-sourced in v3.29.0 off Ibn Baz's manual |
| the tajweed course | al-Jamzuri and Ibn al-Jazari | `AUTHOR_LONG_DEAD` — re-sourced in v3.28.0 off two modern books |

---

## Open list, in the order it should be worked

1. ~~The 48 books whose files carry a modern editor's apparatus.~~ **Done
   2026-09-17**: 47 filtered, 1 removed, audit re-run returns 0. And both of
   its follow-ups are done too — a filtered book now says so in the reader in
   seven languages, and a device holding a pre-filter copy is told to download
   it again.
2. ~~The 47 Qur'an translations.~~ **Done 2026-09-17** — and they turned out
   to be 45, each with its translator recorded *and shown*, under upstream
   terms that permit exactly this. Nothing to fix.
3. ~~`madinah_gold`'s ND clause.~~ **Answered 2026-09-17** — NC and BY are
   satisfied, the pipeline only downscales, and the uploader states he does not
   own the content.
4. ~~Add `source` and `license` fields to `editions.json`.~~ **Done
   2026-09-17**, for all six, from the items' own metadata, held by
   `test/mushaf_provenance_test.dart`.
5. ~~hadeethenc.com's terms.~~ **They were read on 2026-09-10**, before
   anything was uploaded, and they permit it.
6. **`tajweed_color`, `madinah_night` and `kuwait` state no licence.** Render
   their printed front and back matter and read it, the way the Taj Company
   scan was rejected on exactly that evidence (CLAUDE.md trap #18). This is now
   the only open item on the mushaf side.
7. **The recitations** on everyayah.com, cdn.islamic.network and mp3quran.net.
8. ~~The azkar corpus.~~ **Done 2026-09-17.** See below.

---

## The azkar — replaced, and why it was the clearest case in this file

The feature was built on **«حصن المسلم» by سعيد بن علي بن وهف القحطاني**
(d. 1439 AH / 2018). That was not inferred: his name was **inside the bundled
database**, in `azkar_items` row 2's footnote — «الؤلف: سعيد بن علي بن وهف
القحطاني», the typo the source's own.

The supplications in it are prophetic and free. What was his is the
**selection, the arrangement, the 134 chapter titles and the takhrij** — and
Article 3 of the UAE law names precisely that:

> ومع ذلك تتمتع **مجموعات** ما ورد في البنود (2)، (3)، (4) من هذه المادة
> **بالحماية إذا تميز جمعها أو ترتيبها أو أي مجهود فيها بالابتكار**.

A collection of free works is protected when its gathering is innovative. There
was no reading of that sentence under which shipping his selection was fine.

**What replaced it.** an-Nawawi (d. 676 AH), «الأذكار». **48 supplications
across 18 chapters, hand-picked** — the owner's instruction was «انتقي أنا
بالإيد», after an automatic extractor was built and then rejected: al-Adhkar's
quotation marks are not a dua boundary («٣٧ - وروينا في " صحيح البخاري " عن
حذيفةَ …» puts the BOOK's name in quotes and the supplication outside them), so
a machine would have shipped a book title as a supplication.

**No Arabic was ever retyped.** `scripts/azkar_curated.json` holds *pointers* —
a chapter, a narration, and two short phrases locating where the supplication
starts and ends — and the text is sliced out of the extractor's own output at
build time with a frozen checksum, the same discipline the quotes corpus uses.
The muhaqqiq's apparatus (عبد القادر الأرنؤوط, d. 1425 AH) is filtered out
before any of it is read: 341 paragraphs of his, none of which reaches a
device.

**Three things this forced, each of which was its own defect:**

* `ruqyah_catalog.dart` addressed six supplications by row id, promising «a
  mis-typed id shows up as a missing dua, not a wrong one». That holds only
  while the table is never rebuilt. Ids are explicit now (1001–1005) and
  `test/ruqyah_duas_test.dart` pins the **text** each resolves to.
* One of those six — «أعوذ بكلمات الله التامات التي لا يجاوزهن بر ولا فاجر» —
  is **not in al-Adhkar**, zero hits across all 338 chapters. It is gone, not
  reconstructed.
* The chapter list and every chapter's app bar drew the database's **Arabic**
  heading directly, so an English or French reader saw an Arabic list. The 18
  titles are translation keys now, in all seven locales, and
  `test/azkar_section_titles_test.dart` fails on a missing key, on a non-Arabic
  locale still holding Arabic, and on a stale key for a chapter that no longer
  exists.

`sciences-v4` → `v5`, so every existing install re-copies the file instead of
keeping the old one.

## How to re-run the measurements in this file

```bash
py -3 scripts/audit_editor_apparatus.py
```

Nothing in this file should be updated from memory. Re-run, then edit.
