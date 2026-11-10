# Writing one chunk of the own i'rab (brief for a chunk writer)

You write the i'rab (grammatical parsing) of a range of ayahs for the app
«رفيق الدرب», word by word, in the project's short codes. Another process
joins your block to the surah file; you only produce ONE block file and make
it pass the checker. Do not edit any file in the repo, do not commit, do not
build. Religious content: no guessing, no invention (CLAUDE.md 1.1, 1.2).

Work in `E:\My Projects\Rafiq-Al-Darb\scripts\own_irab`. Run Python as
`py -3` with `PYTHONIOENCODING=utf-8` (Bash tool:
`cd "/e/My Projects/Rafiq-Al-Darb/scripts/own_irab" && export PYTHONIOENCODING=utf-8`).
The console cannot print Arabic: always redirect output to a file in your
scratch directory and Read the file.

## Read first

1. `phrasebook_sheet.txt` - ALL codes (229 lines: code, TAB, the clause it
   expands to; `{}` is a slot filled with `code:word`).
2. `fill_006.py` lines 1-260 and `fill_005.py` lines 1900-2150 - the house
   style. Copy it exactly: which clauses a word gets, their order, how a
   prefixed و / ف / ل / ب and a suffixed pronoun are described, where the
   clause's place («والجملة ...») is stated (on the word that ends the
   analysis of that clause's verb or predicate, as in the samples).

## The sheet for your ayahs

```
py -3 sheet.py S A B --work > <scratch>/sheet_A_B.txt      (al-Da'as uncut + al-Jadwal)
py -3 sheet.py S A B --only-d > <scratch>/d_A_B.txt        (Darwish, only when needed)
```

Take 4-8 ayahs at a time. The first lines list each ayah's mushaf words
`[1]word [2]word ...`: one entry per listed word, in that order, no more and
no fewer. `DAAS` = al-Da'as, `J` = al-Jadwal (Mahmud Safi), `D` = Darwish.
A DAAS section may span several ayahs and is printed whole.

## The method (unchanged since surah 1)

- EVERY word is read against al-Da'as. Our analysis equals al-Da'as's,
  written out in full school form (role, case and its sign, hidden subject,
  what a jar-majrur attaches to, the place of the clause).
- al-Da'as is terse; what he does not state (the sign, the hidden pronoun,
  the attachment) is completed from al-Jadwal. That is still «agree».
- When al-Jadwal says something DIFFERENT from al-Da'as for a word (another
  role, another attachment, another place for the clause): read Darwish for
  that ayah (`--only-d`), then:
  - al-Jadwal AND Darwish against al-Da'as -> ours follows the two, and
    al-Da'as is shown: `alt('our codes', ('daas', "al-Da'as's own words"))`
  - only one of them against al-Da'as -> ours = al-Da'as, that book shown:
    `alt('our codes', ('jadwal', 'its own words'))` or `('darwish', ...)`
  - an obvious slip in al-Da'as (wrong word quoted, a case that contradicts
    the mushaf's vowel) -> ours correct, al-Da'as shown as the alt.
  The alt text is the book's OWN words copied from the sheet (short: the
  clause about that word), never your paraphrase. Books: `daas`, `jadwal`,
  `darwish` only.
- Not a difference (do NOT make an alt): «مستأنفة» vs «استئنافية» vs
  «ابتدائية»-type naming of the same clause status, «نعت» vs «صفة», «عاطفة»
  vs «حرف عطف», more or less detail, a second possibility a book mentions
  with «أو» / «ويجوز» after giving the same first view.
- Where al-Da'as truly has no text for a word (his section skips it):
  write it from al-Jadwal (and Darwish) as a pair `('codes', 'fuller')` and
  report the word in your final message.
- The mushaf's vowels decide the case sign: read the word's ending
  (ـَ ـُ ـِ, tanwin, ين/ون, ات) before choosing «الفتحة / الكسرة / الياء ...».
  Words ending in ى/ا take «المقدرة على الألف للتعذر», in ي «للثقل»
  as in the samples; diptotes «الفتحة نيابة عن الكسرة لأنه ممنوع من الصرف».
- Never write, quote or "fix" Qur'an text beyond naming a word inside «» the
  way the samples do (bare letters, e.g. `tf:أوفوا`, `mj:في`).

## When NOT to make an alt (measured on a trial: 24 alts where the hand-written text had 6)

An alt is for a different ROLE or CASE of the word, a different thing a
jar-majrur / zarf attaches to, or a different place of a clause that changes
its role (حال against معطوفة, خبر against صفة ...). It is not for:
- the kind of a «لا محل لها» clause (مستأنفة / استئنافية / ابتدائية /
  مفسرة / تعليلية / جواب شرط مقدر ...): write al-Da'as's, else al-Jadwal's;
- a و that al-Da'as does not describe (عاطفة against استئنافية): al-Jadwal's;
- any word al-Da'as is silent on where al-Jadwal and Darwish differ: ours is
  al-Jadwal's, no alt, check stays «agree» (or `fuller` if he skips the word);
- «خبر المبتدأ جملة الشرط» against «الشرط والجواب معا»: write «وجملة الشرط
  وجوابه في محل رفع خبر المبتدأ «من»», no alt.

## House conventions (the wording already shipped in 111 surahs)

- «يا أيها الذين آمنوا» is always exactly:
  `'Xnd:يا,و«أيّ» منادى نكرة مقصودة مبني على الضم في محل نصب,و«ها» حرف تنبيه'`,
  `'اسم موصول مبني على الفتح في محل نصب بدل من «أيّ»,وجملة النداء لا محل لها من الإعراب'`,
  `'vpw,ww,alf,jsl'`; and likewise «يا أيها الناس» with «الناس» بدل مرفوع
  as in the samples. No alt for it.
- Plural imperative (افعلوا): `van5,ww,alf,...` (not `van`).
- Verb with تاء الفاعل (فعلتُ / فعلتَ): `vptf` + `t_fa` / `tf_fa`; with «نا»:
  `vpn:نا,W:نا pfa`; with «تم»: see the samples.
- «ولا» after a negation: `'wa,و«لا» زائدة لتأكيد النفي'`; prohibitive:
  `'wa,حرف نهي وجزم مبني على السكون'` (no «لا» named).
- A حال / تمييز whose owner a book names: say it («حال من فاعل «علمتم»
  منصوبة ...», «حال من الضمير في «لكم» ...»).
- Sound masculine plural as حال / صفة / خبر كان: «... الياء لأنها جمع
  مذكر سالم» for حال and صفة, «لأنه» for nouns.
- The place of a nominal clause goes on its LAST word as
  «والجملة الاسمية ...» (codes `jisti`, `jist`, `jim`, `jihal`, `jitl`,
  `jimq`, `jismkh:X`); of a verbal clause on its verb (`jst`, `jm`, `jsl`,
  `jhal`, `jmq`, `jkh:X` ...). Do not quote the clause («وجملة «...»») unless
  the samples do in the same situation.
- «مما / عما / ممن»: `'«من» حرف جر مبني على السكون,و«ما» اسم موصول مبني
  على السكون في محل جر بـ«من»,...'`.
- The pronoun's vowel is read off the mushaf: لَهُمۡ / مِنۡهُمۡ = «مبني على
  الضم» (`hd_jl`, `hd_md`, `hd_mf`), بِهِمۡ / عَلَيۡهِمۡ / فِيهِ = «على الكسر»
  (`hk_jb:X`, `hk_md`, `hk_jbb`).
- Add `ayd` («والعائد محذوف») on the صلة verb when the returning pronoun is
  dropped; do not add «مقدم / مؤخر» to an attached object pronoun.
- A conjoined noun: `wa,man:X` / `wa,maj:X` / `wa,mar:X` when the sign is
  the plain vowel; other signs literal («معطوف على «X» مجرور وعلامة جره
  الياء ...»).

## Entry syntax

One Python string per mushaf word. Clauses separated by ASCII commas; a
clause is a code, `code:arg` (`_` for a space inside an arg, several slots
`code:a:b`), `W:x code` (= «و«x»» + clause), or literal Arabic when no code
fits (literal Arabic is normal; use the samples' wording). No Arabic comma
«،» and no full stop inside an entry - the expander adds them. A literal
clause must not contain Latin letters.

`IDHA` is a ready constant for «إذا» الشرطية (use `IDHA` or
`IDHA + ',...'`). `Ais:X` / `is:X` are for إنّ-type (mansub) names only; the
name of كان is written literally («اسم «كان» مرفوع ...»).

## The block file

Write `<scratch>/block_S_A_B.txt` (S, A, B = surah, first and last ayah of
your whole range): for each ayah a line with exactly one leading space,
` # N`, then one entry per line, each line starting with one space and
ending with a comma:

```
 # 7
 'wa,va,ant',
 'mf,mud',
 alt('md', ('daas', 'وقدير مضاف إليه')),
 ('lj,mjl,tf:قال', 'fuller'),
```

Then check, and fix until it prints OK:

```
py -3 blockcheck.py S A B <scratch>/block_S_A_B.txt --show > <scratch>/check.txt
```

Read `check.txt`: it lists every word with the expanded wording. Read it
BACK against the sheet for at least every hand-typed (literal) entry and
every alt: the word next to each line must be the word you meant (an entry
too many or too few shifts everything after it - the per-ayah count catches
it, the reading catches a swap).

## Final message (plain text, short)

- the path of the block file, the checker's last two lines;
- every alt: `ayah[word] book` one per line;
- every `fuller` written because al-Da'as has no text;
- anything you could not settle (ayah, word, what the books say) - say it,
  do not hide it.
