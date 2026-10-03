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

Status: 001 (al-Fatiha) written + checked against al-Da'as only. Not wired into the app.
