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

## 1. المكتبة الشاملة — the library's books (249 → 248 → 187 → 214)

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

> ### ⚠️ CORRECTION, the evening of 2026-09-17 — the «zero» above was wrong
>
> Every «audit re-run returns 0» on this page describes the **morning** run,
> and that run under-counted. `audit_editor_apparatus.py` decided whether a
> printing had a modern editor by matching **eleven** fixed label words on the
> edition card. A scan of every built book's card
> (`scripts/scan_edition_cards.py`) found the library's printings use
> **thirty-six** — «تعليق وتحقيق», «حققه وخرج أحاديثه» (5 books), «حققه وعلق
> عليه» (8 books), «دراسة وتحقيق» (5), «قدم له وحققه وعلق عليه», «جمعه ورتبه
> ووثق نصوصه وحققه», and more.
>
> And `verdict()` returned `NO_EDITOR_NAMED` **before it ever read the
> apparatus count**, so a book whose editor the regex missed *and* which
> carried apparatus was filed in the one bucket nobody re-reads. That is
> al-Adhkar's shape precisely: its apparatus rode in the body stream and the
> edition card was not what gave it away.
>
> Re-run with the detection widened from the observed labels, and with a new
> `APPARATUS_BUT_NO_EDITOR_NAMED` verdict so the dangerous case cannot hide in
> the safe bucket, the same 200-odd books produced:
>
> | | morning run | evening re-run |
> |---|---|---|
> | `MODERN_EDITOR_APPARATUS_PRESENT` | 0 | **5** |
> | `APPARATUS_BUT_NO_EDITOR_NAMED` | (did not exist) | **7** |
>
> **Twelve books, not zero.** Eleven were filtered and published; one —
> `tuhfat_at_talib` — was removed, because filtering left 45 empty pages and a
> 32-page run of nothing, which is the verdict `al_ijaz` got that morning.
> After that, the audit returns **0 and 0** on the widened detection. That is
> the number to quote.
>
> The worst of the twelve is set out under **«الإيضاح» and the Hajj screen**
> below. Nothing above this box was deleted: the record of what was believed,
> and on what evidence, is the point of this file.

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

Status as of 2026-09-17: **47 filtered, 1 removed in the morning; then the
detection was found to be too narrow and 12 more books were found that
evening — 11 filtered, 1 removed. See the correction box above.**

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

### The ayah text and its font — replaced 2026-09-25

**Correction to the row above:** the bundled `quran_local.db` text was NOT
quran.com's. It was Tanzil Uthmani 1.0.x, byte-identical to
api.alquran.cloud's `quran-uthmani` (checked 2026-09-25, 18:31 compared
codepoint by codepoint). Against the King Fahd Complex (KFGQPC) text it
carried 6,643 legacy tanween+small-meem pairs (drawn by Amiri Quran as a
false iqlab meem — the owner's 18:31 «عدنٍ») and 5 real differences: 12:39,
12:41 «يَٰصَىٰحِبَىِ» (an extra ى), 2:181, 8:6, 13:37 «بَعْدَمَا» joined.

Now: **KFGQPC hafsData v18** (the Complex's developer text of the Madinah
printing), written verbatim by `scripts/build_quran_text_kfgqpc.py`, which
refuses to write unless two independent copies agree on all 6,236 ayahs
(a pinned public mirror of the Complex package, and quran.com's
`qpc_hafs`) — they did, 6,236 of 6,236.

Drawn with **KFGQPC HAFS Uthmanic Script v0.18**, bundled unmodified as
`assets/fonts/KFGQPC-HAFS-Uthmanic-Script-v18.ttf` (sha256 a0636e68…cbec3a).
Its licence, read from the font's own name table (IDs 0, 13) and shipped
beside it as `assets/fonts/KFGQPC-HAFS-LICENSE.txt`: «Permission is hereby
granted, Free of Cost … the rights to Use, Copy, Distribute», on condition
the font is not sold, modified, altered, translated, reverse engineered.
`STATED_LICENCE` for a free app that ships the file unchanged. The
Complex's site (fonts.qurancomplex.gov.sa) refused connections from this
machine on 2026-09-25 (ECONNREFUSED), so the file came from the mirror; the
licence text inside it is the Complex's own.

### The i'rab — «إعراب القرآن الكريم» للدعاس وحميدان والقاسم (2026-09-26)

Replaces the Quranic Arabic Corpus word labels (`word_grammar`, dropped on
the owner's «لو منتش متأكد مليون المية متحطهومش», 2026-09-25).

| | |
|---|---|
| Work | «إعراب القرآن الكريم» |
| Authors | أحمد عبيد الدعاس، أحمد محمد حميدان، إسماعيل محمود القاسم — **modern** authors |
| Edition | دار النمير (دمشق) ودار الفارابي، الطبعة الأولى ١٤٢٥ هـ / ٢٠٠٤ م — read off the printed title and copyright pages (Shamela's card says «دار المنير»; the print wins) |
| Copyright page | «جميع الحقوق محفوظة … إلا بإذن خطي من الناشرين» |
| Source | Shamela 23584 (fetched 2026-09-25), 3,639 sections |
| Checked against | the printed edition (archive.org `i3rb-krn-d3s`, 3 vols, used to VERIFY, not rehosted): 54,434 eight-word chunks; the 27 sections Shamela damaged transcribed from the print by eye (`scripts/irab_daas_print_transcriptions.json`) |
| Changed | 6 Qur'an quotes corrected to the mushaf, each seen on the Madinah page and the print (`scripts/irab_daas_quran_corrections.json`, evidence in `scripts/evidence/`); nothing else in the authors' text |
| Shipped | `irab_daas`, `irab_daas_refs` in `quran_sciences.db`, R2 `sciences/v2/quran_sciences.zip` (32,146,462 B) + GitHub `content-mirror` |
| Rights | **Not cleared.** Shamela text, shipped on the owner's Shamela ruling (2026-09-22, below) and his choice of this book (2026-09-25). Credited on the Sources screen and in the tab's header. |

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

### The three printings that state no licence — answered 2026-09-17

Open item 6 asked for their **printed front and back matter** to be rendered
and read, the way the Taj Company scan was rejected on exactly that evidence
(CLAUDE.md trap #18: its own last page prints «جملہ حقوق محفوظ» plus a
copyright warning naming Taj Company Ltd).

**That was done, and the answer is that there is no such matter to read.**
Page 1 and page 604 of all three were fetched from our own bucket and looked
at:

| printing | page 1 | page 604 |
|---|---|---|
| `tajweed_color` | سورة الفاتحة in its illuminated frame | الإخلاص · الفلق · الناس |
| `kuwait` | سورة الفاتحة, illuminated opening | الإخلاص · الفلق · الناس |
| `madinah_night` | سورة الفاتحة, night ground | الإخلاص · الفلق · الناس |

**What we host is the 604 Qur'anic leaves and nothing else** — no title page,
no imprint, no copyright page, no colophon. Whatever the publishers print on
those pages, it is not in the set this app redistributes. That is the opposite
of the Taj finding, and it is the reason those two cases end differently.

**And their archive.org items carry no rights statement either**, which was
checked through the metadata API rather than by eye:

```
quraan-colored                  creator  «dar al-m`arifa, Beirut, Lebnon»
                                (no licenseurl, no rights field)
QuranMadina35685363568hNight    (no creator, no licenseurl, no rights field)
```

**Status: `NO_LICENCE_STATED`, and now measured rather than assumed.** What
stands behind them is the same argument as the library's books, with one
honest difference stated plainly:

* the Qur'anic text is nobody's property;
* the **typesetting and illumination of a particular printing can be**, and
  unlike a book's text there is no way to filter a publisher's frame out of
  a page image the way an editor's footnotes were filtered out of a book;
* so these three rest on the absence of any claim — no rights statement on
  the item, no copyright page in what is hosted — and not on a grant.

That is weaker than مصحف قطر, which was chosen precisely because its item
**states CC BY-NC-SA 3.0**, and weaker than `hafs_kfqc`, whose polygons are
CC0. It is recorded here at its real strength rather than at the strength one
would like it to have.

---

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

### The recitations — answered 2026-09-17, and the answer is about hosting

Open item 7 listed everyayah.com, cdn.islamic.network and mp3quran.net as
unexamined. The examination turned on one question, and it is not what the
three sites say in their terms:

> **Does this app REHOST any recitation, or does it only point the reader's
> own device at the origin?**

Measured against the bucket rather than assumed — `list_objects_v2` on three
prefixes:

```
quran/audio/     0 objects
recitations/     0 objects
audio/           0 objects
```

**Nothing. Not one file.** Every recitation the app plays or saves is fetched
by the reader's own device straight from the origin: `everyayah.com/data/…`
for per-ayah files, `cdn.islamic.network/quran/audio/…` for the ayah player,
`mp3quran.net` for whole-surah downloads. The download engine hands the URL to
Android's own downloader; nothing passes through this project's servers.

That is a different position from the library's books, and the difference is
the whole point. A book on R2 is **redistributed by us** — which is why 43 of
them carry `editorNotesRemoved` and why every one was audited. A recitation is
**streamed or downloaded by the reader from the publisher's own server**,
which is what a browser or a podcast app does. We are not a link in the
copying chain.

What the three sites state, read on 2026-09-17:

| | |
|---|---|
| `everyayah.com` | 200; **no robots.txt** (404); the site offers the files as a public dataset for exactly this use |
| `cdn.islamic.network` | 403 on the bare host — it is a CDN, not a site; the audio paths answer 200 |
| `mp3quran.net` | 301 to its own site; it publishes a **public API** (`/api/v3`) that this app uses as intended |

Status: **`LINKED_NOT_REHOSTED`.** No permission is needed to point a device
at a public URL, and none is claimed here.

#### Changed 2026-09-23 — five recitation sets ARE rehosted now, by the owner's decision

The paragraph above was true when written and is **no longer true for five
sets**. Recitation went silent on the owner's phone (157 of the 175 listed
reciters answered 403 on `cdn.islamic.network` and had no other source), and
he asked for a copy on the project's own bucket to be the primary source,
with the public origins as the fallback:

> «ارفع عندي على ال r2 المعيقلي والعفاسي … وخليهم كلهم الاساس للتشغيل
> والتحميل والباقيين احتياطي» — then, on being shown the sizes: «ارفع
> المرتل بس … بحيث ان الحجم الكامل للرفع لايتجاوز ٦ جيجا».

The rights question was put to him before any upload, in those words, and
the decision to rehost is his. What was checked, so the record is honest
about what is and is not known:

| source | what it states about reuse, read 2026-09-23 |
|---|---|
| `everyayah.com` (home page and `/data/` index) | **no licence, no terms, no copyright line** — `NO_LICENCE_STATED` |
| `mp3quran.net` (`/ar`, and its public API v3) | **no licence or terms found on the page**; the API is public and documented — `NO_LICENCE_STATED` |

What is on the bucket, all murattal, Hafs — measured byte-exact before upload
(everyayah's directory index; mp3quran's `Content-Length` on all 114):

| prefix | reciter | from | size |
|---|---|---|---|
| `recitations/ayah/Alafasy_128kbps/` | مشاري العفاسي | everyayah | 1.72 GB, 6,236 files |
| `recitations/ayah/MaherAlMuaiqly128kbps/` | ماهر المعيقلي | everyayah | 1.21 GB, 6,236 files |
| `recitations/ayah/Minshawy_Murattal_128kbps/` | محمد صديق المنشاوي | everyayah | 1.67 GB, 6,236 files |
| `recitations/surah/basit_murattal/` | عبد الباسط عبد الصمد | mp3quran moshaf 53 | 0.45 GB, 114 files |
| `recitations/surah/maher_murattal/` | ماهر المعيقلي | mp3quran moshaf 102 | 0.71 GB, 114 files |

Nothing is re-encoded, trimmed, renamed inside, or compressed: the bytes on
R2 are the bytes the origin serves (each upload is read back and must match
the downloaded length). Status for these five: **`REHOSTED_NO_LICENCE_STATED`,
owner's decision 2026-09-23.** Every other reciter is still streamed from its
origin exactly as described above. Uploaded by
`scripts/r2_mirror_recitations.py`.

**The one exception, stated so it is not mistaken for the rule:** the ruqyah
recordings under `ruqyah/` on the bucket **are** rehosted, and sit under the
same argument as the mushaf scans rather than this one.

Corrected 2026-09-18. This paragraph said «the five», and `list_objects_v2`
on `ruqyah/` returns **six**, every byte size matching the catalogue:

```
ruqyah/abkar.mp3          108,436,721   archive.org
ruqyah/afasy.mp3           60,462,176   archive.org
ruqyah/ajami.mp3           90,244,212   archive.org
ruqyah/muaiqly.mp3         54,721,861   archive.org
ruqyah/sudais.mp3          41,576,448   archive.org
ruqyah/tarteel_hadi.m4a    38,858,921   supplied by the owner
```

The sixth is **not** from the Internet Archive. `ruqyah_catalog.dart` records
it as supplied by the owner from his own library; its embedded title tag reads
«ضع سماعة الرأس وأسترخي ( رقية شرعية )», the file names no reciter, and the
app claims none — its card says the reciter is not named in the source.

Two things were wrong because of that miscount, and both are fixed. The
Ruqyah screen's intro read «خمس تلاوات كاملة» — five — above six cards, in all
seven languages; it now takes `ruqyahRecordings.length` through a plural key,
so the sentence is counted rather than written. And the footer said the
recordings come from the Internet Archive full stop, which was a blanket claim
covering a file that did not come from there; it now reads «from the Internet
Archive (archive.org) unless a card says otherwise», which is true whatever
the list grows to.

---

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

1. ~~The books whose files carry a modern editor's apparatus.~~ **Done
   2026-09-17, in two rounds**: 47 filtered and 1 removed in the morning;
   then the audit's own editor detection was found to know 11 label forms
   where the library uses 36, and a re-run found 12 more — 11 filtered, 1
   removed. The widened audit now returns 0. And both of
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
6. ~~`tajweed_color`, `madinah_night` and `kuwait` state no licence.~~
   **Answered 2026-09-17** — their front and back matter was rendered and
   read, and there is none: what we host is the 604 Qur'anic leaves with no
   title page, imprint or colophon, and their archive.org items carry no
   rights field either. See the section above. They remain
   `NO_LICENCE_STATED`, recorded at their real strength.
7. ~~The recitations on everyayah.com, cdn.islamic.network and mp3quran.net.~~
   **Answered 2026-09-17** — none of them is rehosted: the bucket holds ZERO
   recitation objects and every file is fetched by the reader device from the
   origin. `LINKED_NOT_REHOSTED`. See the section above.
8. ~~The azkar corpus.~~ **Done 2026-09-17.** See below.

---

## The 2026-09-17 curation pass — seven names out, 27 books in

This one is **not a rights decision**. It is the owner's editorial choice about
what his own app teaches, and it is recorded here because it moved 88 books and
because the reasoning for the one thing that was *kept* is a rights-and-honesty
argument that the next session must not quietly undo.

### What he asked for

> «فيه حوار جامد سالت فيه احد الشيوخ بيقول ان ابن باز وابن عثيمين وابن تيمية
> وابن جبرين وابن عبدالوهاب والالباني فيهم حوار تشدد شوية وانا بصراحة مش عايز
> اختلاف، ده تطبيق يعلم الناس دينها ويقربها من ربنا فبلاش. فاحذفهم كلهم
> والقرني معاهم. … اي حاجة ابن باز داخل فيها شيلها يعني مش تخلي له اي حاجة في
> مصادرنا.»

### What each name actually owned — measured before anything was deleted

Every spelling of every name (with and without «ابن»/«بن», plus the Latin
transliterations) was searched across `lib/`, `assets/`, `scripts/` and both
bundled databases.

| name | what the app actually attributed to him | action |
|---|---|---|
| **ابن تيمية** | **60 of the 248 library books** (24%), plus Ibn al-Qayyim's «أسماء مؤلفات شيخ الإسلام ابن تيمية», which is an index *of* those 60 | all 61 removed, catalogue and bucket |
| **الألباني** | **4,898 hadith gradings** in `hadiths.grader`, i.e. nearly all of Sunan Abi Dawud | **gradings kept** — see below |
| **ابن باز** | one row on the Sources screen | corrected (it was also stale) |
| **العثيمين** | nothing | — |
| **ابن جبرين** | nothing | — |
| **ابن عبد الوهاب** | nothing | — |
| **عائض القرني** | nothing | — |

Two of those zeros needed checking rather than assuming:

* «القرني» appears **96 times** in `tafseer_texts`. Read in place, every one of
  them is **أويس القرني**, the Tābiʿī — a different man by seven centuries.
  Nothing was touched.
* «بن عبد الوهاب» appears in `hadiths.arabic` and `hadiths.narrator_en`. Those
  are narrators in isnads, not Muhammad ibn ʿAbd al-Wahhāb. Nothing was touched.

The general principle: a classical text that *narrates through* a man, or a
tafsir that *mentions* him, is not the app endorsing him. What matters is where
**Rafeeq itself** presents a name as an authority — a book on its shelf, a
source on its Sources screen, a grading in its hadith column.

### Why al-Albani's 4,898 gradings stayed

This was put to the owner with the number, and he chose to keep them.

A grading is **isnād criticism attributed to a named critic in a named
edition** — which is exactly what CLAUDE.md §1.2 *requires*: «A hadith grading
must come from a named scholar in a named edition, and the app must show whose
it is. `grade` without `grader` is not acceptable.»

The three alternatives all made the app worse:

* strip the name and keep «صحيح/ضعيف» → the app states a verdict with no source,
  which §1.2 forbids outright;
* strip the grading too → 4,898 hadiths read «الدرجة: غير مذكورة», a real loss
  to the reader;
* find another critic for Sunan Abi Dawud → possible, not free, and not asked
  for.

So: his name survives **only** in the `grader` column, and nowhere else in the
app — no books, no links, no descriptions.

### The Ibn Baz row was stale as well as unwanted

`sources_catalog.dart` credited «التحقيق والإيضاح — ابن باز»
(`shamela.ws/book/31235`) for the Hajj guide. But the guide had already been
moved off that book onto **النووي's «الإيضاح في مناسك الحج والعمرة»** when the
rights question was settled, and `hajj.source` was rewritten in all seven
locales at the time — the Sources screen was simply never updated. **The app
was naming a book it reads no word from.** Corrected to
`shamela.ws/book/96232`, which answered HTTP 200 on 2026-09-17.

### The 61 removed books

`scripts/removed_taymiyyah_ids.json` holds the list.
`scripts/r2_delete_taymiyyah_books.py` deleted the objects **after** the
catalogue was committed, refusing to run while any id was still catalogued —
because the safe failure of a half-finished run is files nobody points at, not
cards pointing at files that are gone. It HEAD-checked each object before and
after: **61 of 61 deleted, 3,573,738 bytes freed.**

The library went **248 → 187**, and the count of books flagged
`editorNotesRemoved` went **47 → 29**, because 18 of the filtered books were
his. `test/editor_notes_removed_test.dart` pins both numbers deliberately, so
neither can move again without someone explaining it here.

### The channels and the sites

Channels **22 → 9**, sites **7 → 3 → 4**, and the 19 orphaned
`channels.desc_*` / `dawah.site_*` keys were deleted from all seven locale
files rather than left behind.

Two of the removed sites were **not** on his list: **`islamqa.info`** and
**`dorar.net`**. They were put to him because his own rule reached them — those
two are the largest online archives of exactly the fatwas he asked to be rid of
— and he chose to remove them and asked for replacements.

The three replacements were each **fetched before being written down** (§1.1),
and the name on each card is the site's own `<title>`:

| site | answered | its own title | «ابن باز/العثيمين/الألباني» on the landing page |
|---|---|---|---|
| `dar-alifta.org/ar` | 200, 179,961 B | فتاوي دار الإفتاء المصرية | 0 |
| `azhar.eg` | 200, 25,244 B | بوابة الأزهر الإلكترونية | 0 |
| `nabulsi.com` | 200, 223,087 B | موسوعة النابلسي للعلوم الإسلامية | 0 |

النابلسي is deliberate: his channel is one of the nine the owner kept.

**One inconsistency is his and is left as he asked it:** «قصة الإسلام» (د. راغب
السرجاني's site) was removed while **his channel was kept**. He was told.

### The 27 books added, and why these

> «عاوز اشهر وافضل الكتب في تنمية الذات واداب النفس واللي تقرب الناس من ربنا
> بمنهج وسطي معتدل … وتزودلي في المكتبة قسم وتسميه طالب العلم وتقلب الانترنت
> على الكتب المتدرجة اللي تعلم طالب العلم الشرعي المنهج الوسطي المعتدل بتدرج
> … وابعد كل البعد عن التشدد او ممن وصف به.»

The gap was measurable and large. The library held **99 tazkiyah books** and
**not one** by الغزالي، ابن رجب، الشاطبي، الماوردي، ابن حزم، المحاسبي، الخطيب
البغدادي or ابن عبد البر — a grep for each name over the whole catalogue
returned zero. It was almost entirely ابن أبي الدنيا and ابن الجوزي.

**Rights:** every author on the new list died between 204 AH and 911 AH. Under
UAE Federal Decree-Law 38/2021 the term is life + 50 years, so the underlying
texts are long out of copyright without argument. The editions are the usual
Shamela question — the builder drops `<div class="hamesh">`, and
`audit_editor_apparatus.py` is run over the new files exactly as it was over
the previous 248.

**Two editions were rejected on reading them, not on their titles:**

* `iqtida_al_ilm_al_amal` (Shamela 12985) — the only printing Shamela has of
  al-Khaṭīb's book is **al-Albani's edition**. The apparatus is dropped by the
  builder, but `sourceLabel` would still have to name the printing, and naming
  him is precisely what was just undone. Dropped; «جامع بيان العلم وفضله»
  covers the same ground.
* `maqasid_al_riayah` (Shamela 6875) — catalogued from its title as
  al-Muḥāsibī's. The **built file's own edition card** says
  **العز بن عبد السلام (ت ٦٦٠)**: it is his abridgement of al-Muḥāsibī's
  «الرعاية», not al-Muḥāsibī's book. The label was corrected and the book
  rebuilt. This is trap #17's family, caught only because the builder prints
  the edition card and somebody read it.

**One book is deliberately absent:** «الاعتصام» للشاطبي, while «الموافقات» is
in. He asked to stay far from تشدد; الموافقات is the مقاصد book, and الاعتصام
is the polemic. That is an editorial judgement and it is recorded so the next
session knows it was a choice and not an oversight.
---

## «الإيضاح» and the Hajj screen — the worst of the twelve

The Hajj guide prints an-Nawawi's «الإيضاح في مناسك الحج والعمرة» step by
step, under a caption that says exactly that. **Shamela has one printing of
it, and that printing is two books.** Its own edition card, which nobody had
read:

```
الكتاب: الإيضاح في مناسك الحج والعمرة
المؤلف: … النووي (ت ٦٧٦هـ)
وعليه: الإفصاح على مسائل الإيضاح على مذاهب الأئمة الأربعة وغيرهم
        لـ عبد الفتاح حسين رواه المكي
الناشر: دار البشائر الإسلامية، بيروت … الطبعة الثانية، ١٤١٤ هـ - ١٩٩٤ م
```

«**وعليه**» — a second author's complete commentary printed around the text,
not a footnote apparatus. 39.1% of the hosted file was his.

**Measured on the screen, before anything was changed.**
`scripts/measure_hajj_exposure.py` walks the nineteen steps the way
`hajj_screen.dart` slices them — same pages, same paragraph indexes — and
counts what it renders:

> Of **1,474** paragraphs shown across the nineteen steps, **280 (19.0%)**
> were عبد الفتاح حسين's, not an-Nawawi's.

That is §1.2 broken on its own terms, before any rights question: the screen
attributed one man's words to another.

**Why filtering alone would have made it worse.** `hajj_screen.dart` slices
with `p.printedPage == step.fromPage ? step.fromPara : 0` — by paragraph
**index inside a page**. Removing paragraphs renumbers every index, so
filtering without re-pointing would have left nineteen steps each beginning or
ending a few paragraphs out, and **nothing would have looked broken**: every
step would still render Arabic prose, just not the prose the boundary was set
on. Invisible, and on the rites of Hajj.

So `scripts/remap_hajj_bounds.py` re-points each boundary **by its own text**:
it reads the anchor paragraph out of the unfiltered file and finds it again in
the filtered one. The result:

* **no `from` boundary moved** — every step began on an-Nawawi;
* **twelve of the nineteen ENDED on one of his notes.** Each snaps *inwards*
  by one, to the last surviving an-Nawawi paragraph. Never outwards, which
  would put the commentator back.

One of those twelve closing anchors is literally his signature:
«قال جامع هذا التعليق المسمى (بالإفصاح عن مسائل الإيضاح)…».

**A measurement of mine that was wrong, and was not reported.** The first run
of the exposure script said 78.6%. The stripper also removes footnote markers
*inside* a surviving paragraph, so an exact-string test counted intact
paragraphs as deleted. Comparing on a marker-insensitive key gives 19.0%,
which is consistent with the 39.1% measured over the whole file. The wrong
number never left the machine; it is recorded here because the next person to
measure this will hit the same trap.
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

## Book read-aloud voice — decision recorded 2026-09-18

The owner chose sample **B**: the open FastPitch model by nipponjo
(`tts_arabic`, speaker 0, HiFi-GAN vocoder), because it gives لفظ الجلالة
its tafkhim and Google's engine does not (F2 of the vowel after the lam:
≈1232 Hz vs Google's ≈1450–1600; al-Minshawi ≈972 — see
`scripts/measure_jalala_tafkhim.py`).

What is known about the right to ship it, stated so it is not forgotten:
* Training data — Arabic Speech Corpus (Nawar Halabi): **CC BY 4.0**.
* Phonetiser (Buckwalter, from Halabi's Arabic-Phonetiser): **CC BY-NC 4.0**.
* The model weights: **no licence stated** anywhere in the repository or on
  Hugging Face.

Told this, the owner's answer was «التطبيق بالتبرع مش محتاج استئذان»: the app
is free and donation-supported, so he considers the NC terms met and asking
the author unnecessary. That is his decision as the publisher; it is recorded
here, with the facts, rather than argued again. If the app ever charges for
anything, the NC phonetiser has to be replaced.

## Interface fonts (added 2026-09-19)

`rafeeq_app/assets/fonts/google_fonts/` - Cairo, Tajawal, Almarai, IBM Plex
Sans Arabic, Noto Kufi Arabic, Changa, Alexandria, Amiri, Scheherazade New,
Noto Naskh Arabic, Lateef, Markazi Text, Reem Kufi, El Messiri, Aref Ruqaa.
Static TTFs from the Google Fonts CSS API (`scripts/fetch_app_fonts.py`).
All are **SIL Open Font License 1.1** (text in `OFL.txt` beside them), which
permits bundling and redistribution in an application. Risk: none known.

## 2026-09-22 — the owner's ruling on Shamela text, and the Jazariyyah شرح

**Ruling (the owner, 2026-09-22):** «اللي من الشاملة خد نصه … لو ينفع تاخد
النص التراثي تمام، منفعش خلاص مش بإيدينا» — library and course text may be
taken from Shamela. Where the classical author's text can be separated from a
modern editor's apparatus, it is (the existing filters stay); where it cannot,
the text ships as Shamela serves it. He also asked for **no bare mutun** in
the library (the explained book instead), and is considering a Play Store
build with **no library at all**, which is where this exposure lives.

**First use — `fath_rabb_al_bariyyah_sharh_al_jazariyyah`** (the شرح under
each lesson of the second tajweed level):

| | |
|---|---|
| Work | «فتح رب البرية شرح المقدمة الجزرية في علم التجويد» |
| Author | صفوت محمود سالم — a **modern** author |
| Edition | دار نور المكتبات، جدة، الطبعة الثانية ١٤٢٤ هـ / ٢٠٠٣ م, 137 pp. |
| Source | Shamela 21580, fetched 2026-09-22, 106 pages, `hamesh` dropped |
| Shipped | bundled asset + `books/text/…json` on R2, 55,442 B gzip, no `Content-Encoding` |
| Rights | **Not cleared.** Shipped on the owner's explicit ruling above. |

Chosen over 17065 «الروضة الندية» (محمود عبد المنعم العبد، المكتبة الأزهرية
٢٠٠١م — equally modern) because it explains in plain language, which was the
owner's criterion. The classical commentaries (القاري، الأنصاري، الأزهري،
ابن الناظم) are not in the 8,598-book Shamela index, and archive.org had no
licensed text edition of any of them.

## 2026-09-22 — library «المرحلة ١», and the named-notes ruling

**Phase 1 (18 in, 2 out).** Each book's Shamela card was read before upload
(`scripts/library_phase1.py --report`; cards in `scripts/library_phase1_out.txt`).
Refused: «توضيح المقاصد» (a Najdi author — «مش ناقصين تشدد»), and «الروض
المربع» printing 1679, whose card reads «ومعه حاشية … محمد بن صالح العثيمين»
and «تعليقات … عبدالرحمن بن ناصر السعدي» (the card adds that the e-text lacks
both; the owner's rule was to refuse such a card or take another printing).
Shipped instead: Rakaiz 147658 (1438هـ, ed. المشيقح والعيدان واليتامى), no
حاشية on its card. The bare الورقات and الآجرومية left the shelf for
المحلي's شرح (21547) and الحفظي's شرح. The Shamela hamesh is dropped at
build time, so `editorNotesRemoved` is true of all 18; `tidy()` also drops the
matn-over-sharh running heads, dot rows and orphan footnote numbers — layout
debris, never text.

**The named-notes ruling** («شيل أي حاجة لابن باز وابن عثيمين وابن جبرين وابن
عبد الوهاب والألباني إلا التخريج…»). Measured on all 213 hosted books as the
public endpoint served them: 111 al-Albani mentions are takhrij (kept — the
ruling's own exception); every «بن عبد الوهاب» is a classical narrator (no
mention of the Najdi in any book); «العثيمين» elsewhere is the historian-editor
عبد الرحمن بن سليمان. Five editor passages and one section came out, listed
with their reasons in `scripts/strip_named_notes.py`: al-Muwafaqat (three of
مشهور حسن's notes and the student-written biography of the editor), Ighathat
al-Lahfan (one footnote), Musnad Abi Bakr (one quotation). Not a word of any
author was touched.

## 2026-09-22 — «في المذاهب الأربعة» in the Hajj guide

«طورها من جديد بوسطية». Shamela's Hajj manuals were read by card: the modern
ones are الألباني (12090)، ابن عثيمين (21585)، القحطاني (96547)، العمري
(11096) — out on the standing rulings; the classical ones are al-Nawawi
(96232, already the guide) and Ibn Farhun (132974, Maliki only). The step text
stays al-Nawawi's; under each step now sits al-Jaziri's treatment of the same
rite, «الفقه على المذاهب الأربعة» (9849, ت ١٣٦٠هـ — out of copyright under
Egypt's life+50), which sets the four schools side by side. His schools'
positions are in his own hamesh, so `scripts/build_hajj_madhahib.py` keeps
the hamesh (the book builder drops it) and ties every note to its section by
the note's own number in the body: 49 notes, none unlinked, 147 school
statements. Pages crawled verbatim to `scripts/jaziri_raw/` (569-640).
