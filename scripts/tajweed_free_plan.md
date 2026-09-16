# The free-licence tajweed curriculum — plan of record

«استبدل بمصادر حرة، انا مش عاوز في التطبيق اي مشكلة لحقوق الملكية نهائيا».

## What is being replaced, and why

| Level | Was | Problem |
|---|---|---|
| 2 | تيسير أحكام التجويد | يحيى الغوثاني — **living author**, دار الغوثاني دمشق 2006, in print |
| 3 | غاية المريد | عطية قابل نصر, **d. 1424 AH / 2003** — still in copyright |

Level 1 (تحفة الأطفال + شرح الضبّاع) stays: الجمزوري d. after 1198 AH, الضبّاع
d. 1380 AH / 1961 — past life+50 in Egypt since 2011.

## The replacements — built and hosted 2026-09-16

All three fetched from Shamela by `build_book_text.py`, uploaded by
`r2_upload_book_text.py`, and read back from the public endpoint:

| id | book | author | died | pages | bytes on R2 |
|---|---|---|---|---|---|
| `al_muqaddimah_al_jazariyyah_matn` | المقدمة الجزرية | ابن الجزري | **833 AH** | 100 | 42,215 |
| `at_tamhid_fi_ilm_at_tajwid` | التمهيد في علم التجويد | ابن الجزري | **833 AH** | 174 | 59,020 |
| `at_tahdid_fi_al_itqan` | التحديد في الإتقان والتجويد | أبو عمرو الداني | **444 AH** | 112 | 39,587 |

Six and nine centuries dead. There is no copyright left to violate.

**But the printings are modern, and the editor's work is his.** Each of these
files carries the editor's apparatus as well as the author's text, and the
lessons must take only the author's:

* **الجزرية** — the نَّاظِم's text is TOC entries **18 to 35**, «مقدمة الناظم»
  (printed p53) through «[خاتمة]» (p97). Entries 0–17 are the editor's
  (مقدمة التحقيق، وصف النسخ، ترجمة الناظم، نماذج من المخطوطات) and entry 36 is
  his bibliography. **All excluded.**
* التمهيد and التحديد need the same cut, read off their own tables of contents
  before any range is written.

## The lesson plan

**Level 2 — المقدمة الجزرية**, 18 lessons, the nazim's own chapters in his own
order: مقدمة الناظم · مخارج الحروف · صفات الحروف · التجويد · الترقيقات ·
الراءات · اللامات · التحذيرات · الظاءات · التحذيرات · النون الساكنة والتنوين ·
المدات · الوقوف · المقطوع والموصول · التاءات · همزات الوصل · الوقف على أواخر
الكلم · خاتمة.

**Level 3 — التمهيد لابن الجزري**, his own prose explanation of the same
science, cut along its 43 TOC entries the way `build_ghayat_course.py` cut
غاية المريد — by script, against the real text, with a test.

التحديد للداني is the reference beside them, as تحفة الأطفال has
المقدمة الجزرية beside it today.

## The explanation for non-Arabic readers

Settled in conversation, and it is what makes the whole thing possible:
**copyright protects expression, not ideas** (TRIPS art. 9(2); 17 U.S.C.
§102(b)), and the fiqh position is the same — مجمع الفقه الإسلامي الدولي قرار
٤٣ (٥/٥) protects **حق المؤلف في مؤلَّفه**, not the science itself.

So the app writes **its own** explanation of each rule, in Arabic, translated
into all seven locales. Nothing is copied: not a sentence, not an arrangement,
not a diagram.

**The rule that makes this safe, and it is not optional:** every claim in that
explanation carries a citation to one of the free texts above — الجزرية by
line, التمهيد by page, التحفة by line. Our words, their authority, checkable by
anyone who reads Arabic. This is §1.2 applied: an explanation with no source
behind it does not ship, however well it reads.

The scientific review is the owner's, or a qualified reviewer's. Good drafting
is not a substitute for a scholar's eye.

## Order of work

1. ~~Build and host the three texts~~ — done.
2. Cut الجزرية into its 18 lessons by script (entries 18–35 only) + a test that
   every lesson opens on its own heading, the way `ghayat_course_test.dart`
   does.
3. Same for التمهيد.
4. Write the per-rule explanation with citations; translate into all 7 locales.
5. Retire `taysir_ahkam_at_tajwid` and `ghayat_al_murid`: out of the course, out
   of `book_catalog.dart`, off the bucket.
6. Re-run `compat_matrix.py`, then the release.
