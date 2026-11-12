# Group B neighbour-coherence review (2026-11-12, Opus)

Input: `neighbours.txt` (from `neighbours.py`): 94 GROUPB words whose i'rab names
a relation, each with 2 words either side. All 94 were read by Opus. Book
passages for the suspects were dumped with a scratch script (al-Da'as from
quran_sciences.db, al-Jadwal + Darwish via `books.get`). Nothing below is
applied yet.

Key: D = al-Da'as, J = al-Jadwal, W = Darwish.

## A. Pure neighbour fixes (the GROUPB word stands; a neighbour's tail contradicts it)

| ayah | GROUPB word says | neighbour that clashes | fix (to be checked against the books before applying) |
|---|---|---|---|
| 10:32 | ماذا مبتدأ (J, W) | بعد «متعلق بمحذوف خبر مقدم» | drop «مقدم»: J «متعلق بمحذوف خبر المبتدأ», D «متعلق بالخبر المحذوف» |
| 2:170 | آباءنا مفعول به أول (W) | عليه «متعلقان بالفعل ألفينا» | W: «عليه في موضع نصب مفعول ألفينا الثاني»; D gives that as «وقيل». Fix عليه per W. |
| 27:87 | الصور «في محل رفع نائب فاعل» | ينفخ «ونائب الفاعل ضمير مستتر» | ينفخ: drop the hidden na'ib fa'il. Books not read yet. |
| 27:87 | وكل: الواو حالية | داخرين tail «والجملة الاسمية مستأنفة» | tail -> «في محل نصب حال». Books not read yet. |
| 27:91 | وله: الواو اعتراضية | شيء tail «في محل نصب حال» | tail -> «اعتراضية لا محل لها». Books not read yet. |
| 28:58 | وكنا: الواو حرف عطف | الوارثين tail «في محل نصب حال» | D says «الواو حالية» (NEEDLE in daas_quote.py) - decide which side. |
| 29:45 | ولذكر: الواو حرف استئناف | أكبر tail «في محل نصب حال» | tail -> «مستأنفة». Books not read yet. |
| 30:26 | وله: الواو حرف عطف | من tail «والجملة مستأنفة» | tail -> «معطوفة». Books not read yet. |
| 35:18 | ومن: الواو حرف استئناف … «والجملة اعتراضية» | contradiction inside the same word | pick one. Books not read yet. |
| 36:6 | فهم: الفاء عاطفة | غافلون tail «تعليلية» | decide. Books not read yet. |
| 36:51 | ونفخ: الواو حرف عطف | الصور tail «استئنافية» | tail -> «معطوفة». Books not read yet. |
| 36:75 | وهم: الواو حرف عطف | جند tail «في محل نصب حال» | decide. Books not read yet. |
| 37:66 | فإنهم: الفاء حرف استئناف | آكلون tail «معطوفة» | decide. Books not read yet. |
| 38:24 | وقليل: الواو اعتراضية | هم tail «في محل نصب حال» | tail -> «اعتراضية». Books not read yet. |

## B. The GROUPB change itself is in doubt (two books against it, the old neighbour agrees with them)

| ayah | GROUPB change | books | neighbour |
|---|---|---|---|
| 3:54 | والله: «الواو استئنافية» | D «والجملة حالية», W «الواو حالية … في محل نصب على الحال»; only J استئنافية | الماكرين tail still «في محل نصب حال». Two books = حال: revert or argue from the jury (al-Samin/al-Bahr) before keeping. |
| 12:4 | ساجدين: حال (J, Abu al-Baqa') | D and W: «مفعول به ثان لرأيتهم» | رأيتهم: «هم … مفعول به أول». Decide; then make رأيتهم agree. |
| 17:72 | أعمى: خبر «كان» (J) | D and W: أعمى اسم كان مؤخر, في هذه خبر مقدم | في هذه still «خبر كان مقدم» -> two khabars. Either في هذه «متعلقان بـ«أعمى»» (J) or revert أعمى. |
| 25:49 | أنعاما: مفعول به أول (J) | D and W: مفعول به ثان (الهاء أول) | ونسقيه: check what it calls the ha. |
| 18:24, 19:48, 27:72, 28:9, 28:67 | عسى: تامة, the masdar is its fa'il (J) | D and W: ناقصة, the masdar is its khabar | the following verb still says «المصدر المؤول في محل نصب خبر «عسى»» -> self-contradiction in every one. Either revert عسى (two books) or rewrite the verbs' tails. |

## C. Not yet read

`nb_books.txt` stopped at 26:29 (context limit). Entries 26:29 (غيري مفعول ثان
while إلها has no «أول»), 30:54 (بعد مفعول ثان, قوة just «مفعول به») and
everything from 26:29 on in the book dump still need the books read.
Everything else among the 94 was read and is coherent.

## Next step

1. For every row in B: open al-Samin / al-Bahr (review2.py books cache) and
   decide; the two-book rule says revert unless the jury gives a named reason.
2. Read the books for the A rows marked «not read», then write the
   accepted fixes into a groupb5 table, `apply_groupb.py`, `check.py`,
   `audit_vowels.py`, `export_app.py`.
3. Then TASK_FOLLOWUP NEXT items (2)-(5) (b052-b063 etc.).

## Done 2026-11-12 (Opus) - `groupb5_fixes.json`, 24 fixes applied

- Table B: every change KEPT. al-Mujtaba (al-Kharrat) sides with al-Jadwal in
  all of them, so it is two books on each side and the change stands:
  3:54 «جملة والله خير مستأنفة», 12:4 «ساجدين حال», 17:72 «في هذه متعلق بأعمى»,
  25:49 «أنعاما مفعول أول» (ونسقيه already said ثان: no fix), and the «عسى»
  family «فعل ماض تام … المصدر فاعل». Al-Samin and al-Bahr do not rule on any
  of these. The neighbours were made to agree (7 fixes).
- Table A: all 14 decided from al-Jadwal / Darwish / al-Mujtaba, each quote
  in the `why` field (15 fixes; 28:58 الوارثين became «معطوفة على جملة لم
  تسكن» in محل نصب, per al-Jadwal and al-Mujtaba).
- Section C: 26:29 إلها, 30:54 قوة and ضعفا -> «مفعول به أول» (al-Jadwal).
- Not changed, found on the way: 36:51 «في الصور» — al-Jadwal and al-Mujtaba
  make it the na'ib fa'il of «نفخ»; ours (al-Da'as, Darwish) a hidden na'ib.
  Two books against ours: decide it in the next group B pass.
