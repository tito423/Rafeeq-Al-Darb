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

## The rule this project works to

**Author's death + 50 years** (Egypt). It has always been applied to the
**author**. The measurement below is the first time it was also asked of the
**editor**, and that is the gap this file opens.

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

| what the book is | count |
|---|---|
| no editor named on the card at all | **71** |
| editor named, died before 1396 AH | **4** |
| **editor is modern, and NONE of his apparatus is in the file we ship** | **126** |
| **editor is modern, and his apparatus IS in the file we ship** | **48** |
| | **249** |

So **175 of 249 books carry nothing of any modern person's** — either no editor
was involved, or he is long dead, or the file holds the author's text and not
his notes. That is the useful half of the answer, and it was not known before.

**The 48 are the open list.** The full report, per book, with the editor named
and the share of the text that is his, is
`scripts/_editor_apparatus_report.txt`. The worst by a wide margin:

| book | share of the file that is the editor's | editor |
|---|---|---|
| `al_ijaz_fi_sharh_sunan_abi_dawud` | **46.5 %** | أبو عبيدة مشهور بن حسن آل سلمان — **alive** |
| `masalah_fil_kanais` | 30.8 % | علي بن عبد العزيز الشبل |
| `amar_al_ayan` | 17.4 % | د. محمود محمد الطناحي |
| `al_adhkar_nawawi` | 17.0 % | عبد القادر الأرنؤوط (d. 1425 AH / 2004) |
| `qaidah_jalilah_fil_tawassul_wal_wasilah` | 11.4 % | ربيع بن هادي عمير المدخلي |
| `al_jami_fi_amthal_al_quran` | 10.5 % | الشيخ مصطفى العدوي — **alive** |

Status: **`MODERN_MATERIAL_PRESENT` / `NEEDS_REVIEW` for those 48.**

**What is proposed, and not yet done:** the apparatus can be filtered out of
those files the same way `scripts/build_azkar_from_adhkar.py` already filters
it out of al-Adhkar — 341 of its paragraphs are al-Arna'ut's and none of them
reaches the azkar tables. That keeps the classical book and removes the modern
work, which is better for the app than deleting either. It has to be verified
book by book against pages read by hand before anything is re-uploaded,
because a filter that over-reaches deletes the author instead of the editor.

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
| api.alquran.cloud | translations | **`NEEDS_REVIEW`** — a translation has a living or recent translator; this has never been checked per language |
| quranpedia / quran-svg | the `hafs_kfqc` SVG glyph layer | **`NEEDS_REVIEW`** |

**The 47 translation files are the clearest unexamined gap in this document.**
A Qur'an translation is a modern work with a named translator. Nobody has
recorded, per language, who made it and under what terms.

## 3. The mushaf page images — 6 printings

| printing | source item | licence recorded | status |
|---|---|---|---|
| مصحف قطر | archive.org `QuranMushafQatar` | **CC BY-NC-SA 3.0** | `STATED_LICENCE` — and it is *why* this one was chosen |
| المصحف المذهّب (Smart Mushaf) | archive.org `smartmushaf` | **CC BY-NC-ND** | **`NEEDS_REVIEW` — see the ND note below** |
| مصحف دولة الكويت | archive.org `HQ23…MushafDolatUlKuwait…`, Ministry of Awqaf | none recorded | **`NEEDS_REVIEW`** |
| مصحف المدينة — الطبعة الليلية | archive.org `QuranMadina35685363568hNight` | none recorded | **`NEEDS_REVIEW`** |
| مصحف التجويد الملوّن | Dar al-Ma'rifa colour-coded printing | none recorded | **`NEEDS_REVIEW`** |
| `hafs_kfqc` — مصحف المدينة، رواية حفص | quranpedia / quran-svg glyph layer | none recorded | **`NEEDS_REVIEW`** |

**The ND problem, stated precisely so it is not lost.** `madinah_gold` is
recorded as **CC BY-NC-ND**. `NC` is satisfied — this app is free, refuses ads
on purpose, and sells nothing. `ND` is the open question: the pipeline
(`build_mushaf_from_pdf.py`) **renders each page out of the source PDF,
re-encodes it, and trims the scan margin**, and a cropped, re-encoded page may
count as a derivative. That needs an answer before the next release that
touches this edition. It is the kind of question a lawyer settles, not this
file.

The licences above were **recorded by earlier sessions when each edition was
added; they were not re-verified today.** The archive.org item ids are written
down so they can be.

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
| hadeethenc.com | 3,574 hadiths in 7 languages, with explanations and glossaries | **`NEEDS_REVIEW`** — a modern, living editorial project; its own terms have never been read. This is the one hadith source where the *modern* material (translations, explanations, word glossaries) is the point |

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
| حصن المسلم (`quran_sciences.db`) | 134 sections, 298 items | **`MODERN_MATERIAL_PRESENT`** — سعيد بن علي بن وهف القحطاني, d. 1439 AH / 2018. His name is inside the bundled database itself, in `azkar_items` row 2's footnote. **Being replaced**: see `scripts/azkar_curated.json` |
| the quote of the day | 58 quotes from 4 books | `AUTHOR_LONG_DEAD` — rebuilt in v3.29.0 after the discovery that 284 of the previous 352 came from «لا تحزن», whose author is alive |
| the Hajj guide | an-Nawawi's «الإيضاح» | `AUTHOR_LONG_DEAD` — re-sourced in v3.29.0 off Ibn Baz's manual |
| the tajweed course | al-Jamzuri and Ibn al-Jazari | `AUTHOR_LONG_DEAD` — re-sourced in v3.28.0 off two modern books |

---

## Open list, in the order it should be worked

1. **The 48 books whose files carry a modern editor's apparatus.** Filter it
   out the way the azkar extractor does, verified book by book. `al_ijaz_fi_
   sharh_sunan_abi_dawud` first: 46.5 % of that file is a living author's.
2. **The 47 Qur'an translations.** Who translated each, and under what terms.
   Not one has been recorded. This is the largest untouched area in the app.
3. **`madinah_gold`'s ND clause** — the one open question with a name and a
   deadline, because the rendering pipeline may be making a derivative.
4. **The four mushaf printings with no licence recorded.** Render the front and
   back matter and read it, as was done for the Taj Company scan — that scan
   was rejected on exactly this evidence (CLAUDE.md trap #18).
5. **Add `source` and `license` fields to `editions.json`**, so a printing
   cannot be added again without recording where it came from. Today those
   facts survive only in a session's memory file, which was found to be
   **wrong** on 2026-09-17 (it said nine printings ship; six do).
6. **hadeethenc.com's terms.** Its modern material — translations,
   explanations, 83k word glossaries — is the point of that feature, so this
   one cannot be answered by «the matn is old».
7. **The recitations** on everyayah.com, cdn.islamic.network and mp3quran.net.

## How to re-run the measurements in this file

```bash
py -3 scripts/audit_editor_apparatus.py
```

Nothing in this file should be updated from memory. Re-run, then edit.
