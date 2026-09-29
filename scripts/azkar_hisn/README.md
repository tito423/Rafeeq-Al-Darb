# Hisn al-Muslim source (owner's order, 2026-09-29)

`hisn_elmuslim_asellam.json` is `hisn.json` from
<https://github.com/asellam/HisnElMuslim> (MIT), commit
`872764ca013116c905f7fc9c3dc972c27cd37d4a`, SHA-256
`b30a448ef40184b0422c40bd3c372bf2b25bfb5b0539fd3699e6b4fba9459d80`.

Why this copy and not the older `scripts/temp_phase1/hisn_almuslim.json`
(rn0x): its README says the text was typed from the printed edition (Dar
al-Sijillat) and compared with an internet copy by Levenshtein distance, and
every dhikr carries its own `Count` and `Reference`. The rn0x file keeps the
footnotes as a separate array whose length differs from the text array
(chapter «أذكار الصباح والمساء»: 25 texts, 35 notes), so a note cannot be
paired with its dhikr without guessing.

`../build_azkar_hisn.py` builds `rafeeq_app/assets/data/azkar.db` from it.
Every Qur'an passage quoted in braces is replaced by the mushaf's own words
(`quran_local.db`, Madinah text) after a word-by-word match.
