# Review of the disputed i'rab words against al-Samin «الدر المصون» (plan, 2026-11-11)

Owner: «اختار افضل وارخص طريقة وموديل يخلص القصة دي ... مش عاوز الكوتة تطير ع الفاضي».

## Size (measured 2026-11-11 from the 114 NNN.json)
- 77,430 words: 71,333 `agree`, 5,562 `alt`, 535 `fuller`. Disputed words fall in 3,274 ayahs.
- Already done with no model: `audit_vowels.py` (named case sign vs the mushaf vowel), 22 errors fixed (commit 830e6d5e).

## Why al-Samin (and Makki), not another base book
The classical books (al-Nahhas, Makki, al-'Ukbari, al-Samin, al-Kharrat's «المجتبى») parse only the
DIFFICULT words, so none can replace al-Da'as as the word-by-word base. They are the right judge
exactly where our three books disagree. al-Samin is the fullest record of the views and who held them.
tafsir.app serves it as `src=aldur-almasoon` and Makki as `src=makki` (`books.py` fetches by `src`;
`books_cache/` already holds some `aldur-almasoon_S_A.json`).

## Cost, from measured numbers
A Sonnet chunk writer (~300k tokens) cost ~1.7% of the weekly limit, so 1% ≈ 175k Sonnet tokens.
Sending every disputed ayah with its al-Samin text to Sonnet (~13M tokens) would cost ~70% of a week:
not acceptable. So the order is: Python first (free), then the cheapest model that can do the step,
and Sonnet only where a change might be made.

## Steps (in this order; checkpoint after each)
1. **Python, no model.** `samin_prefetch.py`: fetch `aldur-almasoon` (and `makki`) for the 3,274
   ayahs into `books_cache/` (skip cached). Then `samin_cut.py`: for each disputed word, cut the
   al-Samin paragraph that quotes that word (match on the bare letters of the token, ±1 sentence).
   No quote found means al-Samin is silent on the word: mark `samin: silent` and do not send it on.
2. **Priority list, Python.** Highest risk first: (a) the 535 `fuller` words (al-Da'as silent);
   (b) three-way splits (alt names two books); (c) words where we called al-Da'as a «slip»;
   (d) the rest. Process (a)-(c) fully. Do (d) only if quota is left.
3. **Haiku, classify only.** For each packet (token, ours, alt, al-Samin cut) answer one of:
   `SAMIN=OURS` / `SAMIN=ALT` / `SAMIN=OTHER` / `UNCLEAR`, plus a short quote. No edits.
   Packets in batches of ~40 per subagent; the output is a TSV in the scratch folder.
4. **Sonnet, decide.** Only `SAMIN=ALT`, `SAMIN=OTHER` and `UNCLEAR` go to Sonnet, which rereads
   the al-Samin cut and the three books and writes the corrected entry, citing al-Samin (book name +
   the quote). Never a change from Haiku's word alone.
5. Apply as a table in `write_surah.certain()` / `FIXES` (as on 2026-11-11), rerun the fill files,
   `check.py`, `audit_vowels.py`, `export_app.py`, commit.

## Rules
Never change a mushaf word. A change needs al-Samin (or Makki) to state it in so many words; where
al-Samin lists several views, ours stays as it is if ours is one of them. Report what changed,
with the reference, to the owner.
