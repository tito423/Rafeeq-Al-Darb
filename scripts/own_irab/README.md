# Our own i'rab of the Qur'an (owner, 2026-10-03)

«اعرب انت وصحح لو انت غلطت بناء على الكتب، اعرب الكل واتاكد من مراجعته مع الكتب».
It is to REPLACE the displayed text of al-Da'as (rights), so the wording is ours;
the analysis must agree with named books, word by word.

One file per surah, `NNN.json`: `words` in mushaf order, each
`{a: ayah, w: the mushaf word (text_uthmani token), irab, check, alts?}`.

- `irab`: full school form - role, case, sign («مرفوع وعلامة رفعه الضمة
  المقدرة …»), hidden subject, what a jar-majrur attaches to, the mahall of
  a clause.
- `check` against al-Da'as (quran_sciences.db `irab_daas`, the section for the ayah):
  `agree` same analysis; `fuller` al-Da'as states less, nothing contradicted;
  `alt` al-Da'as (or another book) gives a second view -> `alts:[{book, text, page?}]`,
  shown named under ours; `fixed` ours was wrong and was corrected from `alts[0]`;
  `nosrc` no book found -> NOT shown, listed for the owner.
- Anything al-Da'as does not cover, or any `alt`, is then checked in al-Nahhas,
  al-Ukbari «التبيان», Makki «مشكل إعراب القرآن», al-Samin «الدر المصون» (Shamela),
  with page.
- Never change the mushaf word; `w` must equal the token of `text_uthmani`
  (a test should enforce it).

Status (2026-10-22): 001 and 026-114 written; each passes `check.py` and is exported to `rafeeq_app/assets/data/own_irab.json` (90 surahs, 3,311 ayahs, 30,337 words), which the app's i'rab tab shows. Next: 025, working backwards, in short codes.

2026-10-06: 098-101 (written by a Gemini session on 10-05) re-read word by word against al-Da'as: 100 needed nothing, 99 one fix, 101 seven fixes, and 098 had NO i'rab at all (every word marked «agree» with an empty text) - written from scratch (fill_098.py). Juz 'Amma done so far: 1 + 98-114. Remaining in Juz 'Amma: 78-97 (1,826 words, measured from quran_local.db).

Work sheet: `py -3 scripts/own_irab/show.py <surah>` prints each ayah's words, al-Da'as's section covering it (also multi-ayah sections) and our entries.

2026-10-06 (evening): JUZ 'AMMA COMPLETE - 1 + 78-114, every word written by hand against al-Da'as (show.py); every doubt chased in al-Jadwal (Safi) and Darwish via `books.py` (tafsir.app). Where both other books part from al-Da'as ours follows them and al-Da'as is shown under the word, named; where one book parts, ours follows al-Da'as and that book is named (`alts`: daas / jadwal / darwish). `export_app.py` -> rafeeq_app/assets/data/own_irab.json (the app's i'rab tab). gen_masaq.py output is NOT exported (gate.py: MASAQ's own data errors reach even its 'agree' words) - a draft only.

2026-10-22: short codes (`irab_dsl.py`). Writing the wording out in full cost ~88 Arabic characters a word and 51,967 words remain (002-029); at that rate the quota cannot finish. The analysis is unchanged (word by word against al-Da'as, doubts in al-Jadwal/Darwish); only the typing is shortened. `phrasebook.json` holds 229 clauses mined unchanged from 030-114 (81% of all clauses); `write_surah.write` expands each entry with `x()`, so `"mj:في,mud,tf:غلبت"` becomes the same text a hand-written entry had. `py -3 irab_dsl.py --test` re-encodes the 16,342 old words made only of phrasebook clauses and gets every one back identical. Codes: `phrasebook_sheet.txt`. Literal Arabic clauses still mix in freely. The phrasebook is frozen (re-mining would shift the codes).
