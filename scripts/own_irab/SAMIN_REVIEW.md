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

## Step 0 - free checks over ALL 77,430 words (added on review, before any model)
The al-Samin steps only touch the disputed 8%. The «agree» 92% can still hold a writer's slip
(the 2026-11-11 «is:كان» misuse sat in agree words). Python catches that class at no cost:
- **Grammar invariants between neighbours** (`audit_rules.py`): the word after a jarr particle is
  named مجرور (or the particle زائد); a verb after لم/لمّا/لا الناهية/لام الأمر is مجزوم, after
  لن/كي/أن/لام التعليل/حتى/فاء السببية منصوب; the noun after إنّ وأخواتها named اسم «إنّ» is منصوب,
  after كان وأخواتها named اسم «كان» is مرفوع; مضاف إليه is مجرور; a sound plural's sign is
  الواو/الياء; a word named مبني carries no «وعلامة».
- **Same text, same i'rab** (`audit_repeats.py`): an identical run of 3+ tokens that recurs (e.g.
  «إِنَّ ٱللَّهَ عَلَىٰ كُلِّ شَيۡءٖ قَدِيرٞ») must carry the same i'rab, except the first word's link
  to what precedes it. Every divergence is listed; the majority form is the candidate.
- **Second opinion as a flagger only:** the Leeds Quranic Arabic Corpus case/POS tags. It is not
  a source (its errors are why al-Da'as was chosen), but where it AND al-Da'as differ from ours,
  the word goes to step 4.
Each list is read by Sonnet only for the flagged words.

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
   **Haiku is checked before it is trusted:** Sonnet rereads 50 random `SAMIN=OURS` verdicts. A
   wrong «OURS» hides an error (Sonnet never sees it again), so if more than 1 of the 50 is wrong,
   drop Haiku and run step 3 on Sonnet for the priority groups (a)-(c).
4. **Sonnet, decide.** Only `SAMIN=ALT`, `SAMIN=OTHER` and `UNCLEAR` go to Sonnet, which rereads
   the al-Samin cut and the three books and writes the corrected entry, citing al-Samin (book name +
   the quote). Never a change from Haiku's word alone.
5. Apply as a table in `write_surah.certain()` / `FIXES` (as on 2026-11-11), rerun the fill files,
   `check.py`, `audit_vowels.py`, `export_app.py`, commit.

## Rules
Never change a mushaf word. A change needs al-Samin (or Makki) to state it in so many words; where
al-Samin lists several views, ours stays as it is if ours is one of them. Report what changed,
with the reference, to the owner.
