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

## Budget plan (2026-11-11, owner: «١٠ في المية ماكسيميم من الكوتة»)
Start: weekly all-models 53% (get_usage 2026-11-11 23:45 Dubai). Hard stop at 63%; read get_usage
after every model batch and stop the model steps at 62%.

Triage measured with Python before spending anything (5,876 alt texts on 5,566 words):
`role` 3,859 · `attach` (ta'alluq only) 1,020 · `clause` (mahall of a sentence only) 892 · `zaid` 105.
Every `alt` word already has a named book behind OURS by construction (README: ours follows al-Da'as
unless both al-Jadwal and Darwish part from it), and the other view is shown named under it. So an
`alt` is a recorded khilaf, not an unbacked claim. The unbacked words are the 535 `fuller`, and slips
inside `agree` words. Order of spending therefore:
1. Free: `audit_rules.py` (neighbour/role-case invariants) and `audit_repeats.py` over all words.
2. Free: al-Samin prefetch (tafsir.app, polite rate) for the ayahs of: fuller words, step-1 flags,
   `role` alts. `attach`/`clause` alts are skipped (both views stay shown; al-Samin rarely rules on them).
3. Free: cut al-Samin per word; silent -> no model.
4. Haiku: classify packets (fuller + flagged + role alts al-Samin speaks on). Sonnet audits 50
   random OURS verdicts first batch; >1 wrong -> Sonnet does the classifying for fuller + flags only.
5. Sonnet: decide only on ALT/OTHER/UNCLEAR. Opus (this session) does not read packets; it only runs
   scripts and reviews the final change table.

## Result (2026-11-12, finished)
Measured from the out_*.tsv files in pk/ and pkr/ (committed).
- Step 0 free audits: audit_rules 14 flags, all false positives; audit_repeats 46 role conflicts -> reviewed below.
- fuller + repeat (581): 142 confirmed free (al-Jadwal/Darwish name the same role after the word);
  439 by Sonnet: 260 OURS_OK, 161 NO_SOURCE, 16 UNCLEAR, 2 OURS_WRONG -> both read by hand, both recorded khilaf. 0 changes.
- role alts, priority (ours parted from al-Da'as, or both other books part from ours): 1,158 words;
  225 confirmed free; 933 classified (r000-r007 Sonnet, r008-r031 Haiku). Sonnet judged every
  OURS_WRONG/UNCLEAR (208) + 50 random Haiku OURS_OK (audit): 4 CHANGE proposals, 0 from the audit
  (Haiku's OK verdicts held on all 50).
  - 4:119 «فَلَيُبَتِّكُنَّ» REJECTED: the mushaf has the lam with fatha; lam al-amr is never maftuha, so
    al-Da'as/al-Jadwal (lam al-amr) contradict the mushaf vowel and ours (jawab qasam) stays.
  - 18:63 «فَإِنِّي», 20:85 «فَإِنَّا» REJECTED: ours is al-Da'as verbatim; the other views are shown.
  - 39:65 «وَلَقَدۡ» ACCEPTED, and the same slip found by grep in 6 more: 44:17, 45:16, 46:26, 46:27,
    67:18, 81:23. al-Da'as calls the waw «حرف قسم وجر» with no muqsam bih; al-Jadwal: «(الواو)
    استئنافية/عاطفة (اللام) لام القسم لقسم مقدر». Ours now follows al-Jadwal (the form 53:13-54:51
    already used); al-Da'as is shown under the word, quoted. Rule in write_surah.LAQAD.
- Not reviewed: the 2,339 role alts where only ONE other book differs from ours = al-Da'as (lowest risk),
  and the attach/clause-only alts (both views shown).
- Quota: weekly 53% -> see TASK_FOLLOWUP for the closing reading.

## Second review: a wider jury (2026-11-12, review2.py)
Books (tafsir.app, slugs and speed checked live): al-Nahhas «إعراب القرآن», Makki «مشكل إعراب القرآن»,
al-Kharrat «المجتبى», Abu Hayyan «البحر المحيط», plus al-Samin. No classical book parses every word,
so only words still in doubt are asked.
- Group A (every OURS_WRONG/UNCLEAR/NO_SOURCE of the first review, minus the 7 fixed): 425 words;
  239 none of the four books mentions (dropped); 186 judged by Sonnet: 186 KEEP, 0 CHANGE.
- Group B (the 2,339 low-risk role alts): fetch done/running; classification waits for the 5-hour
  quota window (97% at 01:35 Dubai, reset 04:40 Dubai). Weekly 65% (cap for this stage 67%).

## Group B result (2026-11-12, partial - stopped at the owner's 5-point cap)
`review2.py fetch B` found 0 to fetch; `cut B` gave 1,899 packets in 64 batches (436 words no book mentions were dropped).
- Classified (Haiku): b000-b015 = 480 words: 293 OURS_OK, 133 UNCLEAR, 29 OURS_WRONG, 25 NO_SOURCE (b012 was rerun: first output had 28 of 30 lines).
- Judged (Sonnet, j0-j6): the 162 UNCLEAR/OURS_WRONG + 30 random OURS_OK (audit) = 192 packets: 176 KEEP, 16 CHANGE, 0 CHANGE from the audit sample.
- I read all 16 against the packets and the mushaf vowels and accepted all 16 (each: a named book states it in the packet, no book in the packet supports ours; no Qur'an word touched). Rule table: `write_surah.GROUPB`; JSON patched by `apply_groupb.py`, ours' old text kept under the word as a `daas` alt.
  - 2:57 «ولكن» حالية -> عاطفة (al-Jadwal عاطفة; al-Mujtaba «معطوفة على جملة ما ظلمونا»).
  - 2:125 «السجود» معطوف بحذف العاطف -> نعت للركع (al-Nahhas «السجود نعت»; al-Samin «لم يعطف إحدى الصفتين على الأخرى»; al-Jadwal نعت).
  - 2:170 «آباءنا» مفعول ثان -> أول (al-Samin «أولهما آباءنا والثاني عليه»; al-Jadwal أول).
  - 3:54 «والله» حالية -> استئنافية (al-Mujtaba «مستأنفة لا محل لها»; al-Jadwal). 3:197 «وبئس» حالية -> استئنافية (al-Mujtaba «وجملة وبئس المهاد مستأنفة»). 4:13 «وذلك» حالية -> استئنافية (al-Jadwal only; no book for ours).
  - 3:100 «بعد» ظرف مكان -> زمان (al-Jadwal; attachment left as ours). 3:119 «الغيظ» تمييز -> متعلق بـ«عضوا» (al-Samin «من الغيظ متعلق بعضوا»; al-Jadwal).
  - 3:140 «فقد» عطف -> رابطة لجواب الشرط (al-Jadwal; al-Samin treats «فقد مس القوم قرح» as the condition's answer). 3:173 «فاخشوهم» فاء فصيحة -> عاطفة, clause in محل رفع (al-Mujtaba «معطوف على جملة قد جمعوا في محل رفع»; al-Jadwal).
  - 4:4 «هنيئا» and «مريئا» حال من الواو -> حال من الهاء (al-Nahhas «حال من الهاء»; al-Makki; al-Samin's four views, read in full in books_cache, have no waw view).
  - 4:92 «يصدقوا» حال -> استثناء منقطع (al-Samin «لأن المستقبل لا يكون حالا ... فكونه منقطعا هو الصواب»; al-Nahhas, al-Mujtaba, al-Jadwal).
  - 7:58 «بإذن» صفة لمفعول محذوف -> حال من نباته (al-Mujtaba, al-Jadwal; «يخرج نباته» has no omitted object). 7:178 and 7:186 «من» مبتدأ -> مفعول به مقدم (al-Mujtaba and al-Jadwal; «يهد الله / يضلل الله» has its fa'il and no returning pronoun). A scan of all 'من شرط مبتدأ' words showed these two are the only ones with that shape.
- Not done: b016-b063 (48 batches, ~1,419 packets) are not classified. Same slip families noticed but NOT changed (no source in a packet): 14:29 «وبئس القرار» حالية, 3:143 «فقد» عطف, other «والله» حالية words.
- Quota: weekly 69% -> 73% (16 Haiku batches ~2 points, 7 Sonnet judges ~2 points). Remaining estimate for b016-b063: ~6 points classify + ~6 judge.

## Group B result, part 2 (2026-11-12, on the owner's "كمل")
- Classified (Haiku) b016-b031 = 480 words: 279 OURS_OK, 120 UNCLEAR, 58 OURS_WRONG, 23 NO_SOURCE. With part 1: b000-b031 = 960 words (half of group B).
- Judged (Sonnet, j7-j13): 178 flags + 30 audit = 208: 183 KEEP, 25 CHANGE, 0 CHANGE from the audit sample.
- All 25 read by hand against the packets; all accepted (a named book states it, none in the packet supports ours; no Qur'an word touched). Rules in `write_surah.GROUPB` (second table), applied by `apply_groupb.py`, which now touches only words marked `alt` (the second «بالآيات» of 17:59, marked `agree`, was NOT changed). Al-Da'as' old text stays as a quoted alt.
  - Waw: 9:51 «وعلى» زائدة -> عاطفة (al-Jadwal). Fa: 9:96 «فإن» فصيحة -> استئنافية (al-Mujtaba «جملة فإن ترضوا مستأنفة»; al-Jadwal), 11:45 «فقال» زائدة -> عاطفة, معطوفة على «نادى» (al-Samin «عطف على نادى»; al-Jadwal).
  - Mafʿul mutlaq: 9:80 «سبعين» (al-Samin «منصوب على المصدر»; al-Mujtaba), 9:126 «مرة» (al-Mujtaba; al-Jadwal), 20:110 «علما» مفعول به -> نائب مفعول مطلق (al-Mujtaba; al-Jadwal says tamyiz, so this one is a choice between two named books, both against ours).
  - 10:32 «فماذا»: حرف نفي + ذا زائدة -> «ماذا» اسم استفهام بمعنى النفي (al-Samin; al-Jadwal; al-Mujtaba «ما اسم استفهام»). 11:19 «هم» فصل -> توكيد لفظي (al-Samin and al-Mujtaba «هم الثانية توكيد لفظي»).
  - 12:4 «ساجدين» مفعول ثان -> حال (al-Jadwal; al-Mujtaba «ساجدين حال»). 12:9 «أرضا» ظرف -> منصوب بنزع الخافض (al-Nahhas «لا على الظرف»; al-Mujtaba; al-Jadwal). 17:59 «بالآيات» (first) باء زائدة -> أصلية, حال (al-Jadwal; the cached al-Samin page is a fragment and does not settle it). 17:72 «أعمى» اسم كان -> خبر كان (al-Jadwal). 17:100 «أنتم» توكيد -> فاعل لفعل محذوف (al-Samin, al-Mujtaba, al-Jadwal).
  - «عسى» ناقصة -> تامة, المصدر فاعل (al-Mujtaba, al-Jadwal): 18:24, 19:48. 23:33 «الذين» نعت لقوم -> نعت للملأ (al-Mujtaba, al-Jadwal).
  - «حتى» حرف غاية وجر -> حرف ابتداء (al-Mujtaba «حتى ابتدائية»; al-Jadwal; al-Samin «الأظهر»): 18:86, 18:90, 18:93, 18:96 x2, 21:96, 24:39. NOTE: this is the common «حتى إذا» construction; the same wording probably stands at other places that were not in any packet - NOT changed, to be checked (count not measured).
  - 25:49 «ونسقيه» الهاء مفعول أول -> ثان and «أنعاما» ثان -> أول (al-Mujtaba «أنعاما مفعول أول لنسقيه»; al-Jadwal).
- check.py 114 OK; audit_vowels 3 known false positives; export_app 77,430 words. Not built, not seen on a device.
- Quota: weekly 73% -> 77% (16 Haiku batches ~2 points, 7 Sonnet judges ~2). Left: b032-b063 (32 batches, ~950 packets, ~8 more points with judges).

## Opus review of the Sonnet-run group B work (2026-11-12)
- Every changed word was re-read against al-Da'as's own text (`daas_cut.py` / `daas_quote.py`, quran_sciences.db `irab_daas`).
- Fault found and fixed: the `daas` alt under each changed word held OUR wording labelled as al-Da'as. All 38 now hold al-Da'as's verbatim phrase (cut from his «quote» to the next «/full stop); `apply_groupb.py` writes the book's text from now on.
- Policy applied (the house rule of README plus the 18:63/20:85 precedent): ours (= al-Da'as) changes only when at least TWO named books part from it, or ours is our writer's slip and not al-Da'as's text, or it contradicts the mushaf/grammar on its face. One book against al-Da'as is a recorded khilaf, shown under the word.
- Reverted (one book only): 4:13 «وذلك» (al-Jadwal only), 9:51 «وعلى» (al-Jadwal only), 17:59 «بالآيات» (al-Jadwal only).
- Kept (38 words): two or more books, or a slip of ours: 3:100 «بعد» (al-Da'as says «ظرف» only; «مكان» was ours), 4:4 «هنيئا/مريئا» (al-Da'as «حالان»; «من الواو» was ours), 7:58 (al-Da'as reads «يُخرج» with an object; the mushaf has «يَخۡرُجُ نَبَاتُهُۥ», fa'il). The «حتى إذا» group in al-Kahf is kept as one construction (al-Jadwal at each place; al-Mujtaba at 18:90, 18:96, 24:39; al-Samin «الأظهر» at 21:96).

## Group B part 3 (2026-11-12, Opus coordinating, cap 5 points: weekly 78% -> 82%)
- Classified (Haiku) b032-b047 = 480 words: 263 OURS_OK, 176 UNCLEAR, 15 OURS_WRONG, 26 NO_SOURCE. Total classified: b000-b047 = 1,440 of 1,899.
- Judged (Sonnet, j14-j21, with the two-book rule in the prompt): 191 flags + 30 audit = 221 packets; 214 answered (j19 skipped 7: 37:170:810, 38:21:167, 38:24:232, 38:24:243, 38:27:298, 38:31:333, 38:41:404 - rerun j19 for those).
- 91 CHANGE proposals, 123 KEEP; 1 CHANGE came from the audit sample. NONE APPLIED: 91 is far above the earlier rate (25 of 208), and a first look shows many where the "second book" is the ALT line itself plus al-Mujtaba saying the same, which may be right, but each must be read against al-Da'as's own text (daas_quote.py) before anything changes. List: `pk2B/PENDING_CHANGES_b032_b047.tsv`. Not read yet because this task's 5-point cap was reached.
- Left: b048-b063 not classified; the 91 pending proposals; the 7 unanswered j19 packets.

## Group B part 3 decided by Opus (2026-11-12)
- 94 proposals (91 from j14-j21 + 3 from the j19 rerun of its 7 skipped packets). Tools: `pending_digest.py` (our text, al-Da'as verbatim, ALT, the classical books' lines on the word), `quote_check.py` (96 of 102 book quotes found verbatim in the packet; the 6 others are abridged with «...»), `pending_plan.py` (particle-kind edits keep the rest of our text).
- Applied 92, rejected 2: 27:37 «فلنأتينهم» (only al-Jadwal says رابطة; al-Samin speaks of an implied condition, not of the fa) and 37:145 «فنبذناه» (the proposal broke al-Da'as's coherent «عاطفة على محذوف»).
- Every applied item has two named books against al-Da'as (the ALT book + al-Mujtaba in most; al-Samin/al-Nahhas/Makki in some) or corrects our slip (26:184 «والجبلة» was «معطوف على الذي»; al-Da'as says «معطوف على المفعول به»). Tails fixed with the particle (a clause called مستأنفة/معطوفة to match). Table: `groupb3_fixes.json`, loaded by write_surah.GROUPB; al-Da'as's verbatim phrase kept under each word.
- check.py 114 OK, audit_vowels 3 known false positives, export_app 77,430 words.

- Device check found one incoherence: 36:13 «أصحاب» changed to «بدل من مثلا» while «مثلا» kept al-Da'as's «مفعول به ثان» (the badal view needs «اضرب» with one object). Reverted to al-Da'as (91 part-3 fixes stand); al-Jadwal's badal view stays shown. LESSON: a role change can depend on its neighbours; before the next group, check each role change against the i'rab of the words next to it (not done yet for the 91 - follow-up).
