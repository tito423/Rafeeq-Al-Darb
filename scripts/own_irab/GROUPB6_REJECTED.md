# Group B part 6 — judge CHANGE proposals rejected by Opus (2026-11-12)

Source: `pk2B/out_j22.tsv`..`out_j27.tsv` (Sonnet, 78 CHANGE). Each read against
the packet (al-Samin, al-Nahhas, Makki, al-Mujtaba, al-Bahr) plus al-Jadwal and
Darwish from `books_cache/` (tafsir.app). Rule: two named books agreeing on the
same replacement = change; one book, or books that disagree with each other, = KEEP.
63 accepted -> `groupb6_fixes.json` (87 text edits with neighbour tails).

| Word | Proposal | Why kept |
|---|---|---|
| 40:67 ومنكم | waw i'tirad | Jadwal says عاطفة, Mujtaba says معترضة; Darwish says مستأنفة = ours. No two agree. |
| 41:34 فإذا | not fasiha | Jadwal تعليلية, Mujtaba معطوفة; Darwish: «الفصيحة هنا أولى» = ours. |
| 43:10 لكم | 2nd object / hal | Jadwal: حال من مهدا; Mujtaba: متعلق بالمفعول الثاني. Differ; Darwish allows ours. |
| 43:72 الجنة | badal | Nahhas نعت, Mujtaba بدل; Darwish «والجنة خبر» = ours. |
| 44:10 فارتقب | not fasiha | Jadwal عاطفة للربط, Mujtaba مستأنفة; Darwish الفصيحة = ours. |
| 45:23 أفرأيت | fa istinaf | Only Jadwal names the fa; Mujtaba speaks of the sentence (مستأنفة), which fits ours. |
| 47:15 أنهار | sentence = hal | Only Mujtaba says hal; Jadwal استئناف بياني (allows ours), Samin cites مفسرة. |
| 48:23 لسنة | tied to تجد | Darwish: بتجد; Jadwal: مفعول ثان. Differ. |
| 50:26 فألقياه | fa rabita | Needs الذي مبتدأ (Jadwal; Samin/Nahhas as options); ours الذي بدل with Darwish, Mujtaba (معطوفة على ألقيا). |
| 50:43 نحن | tawkid | Mujtaba توكيد, Jadwal مبتدأ (توكيد only in a footnote); Darwish فصل أو مبتدأ. |
| 51:35 فأخرجنا | fa atf | Mujtaba atf on أرسلنا, Darwish fasiha, Jadwal atf on an elided sentence. Three readings. |
| 58:10 الذين | fa'il | Jadwal only; its own footnote gives ours. Sonnet's «ليحزن لازم» is wrong: Hafs reads لِيَحْزُنَ (حَزَنَه, transitive). |
| 65:3 لكل | 2nd object | Jadwal مفعول ثان, Mujtaba حال من قدرا. Differ. |
| 73:20 فاقرءوا | not atf | Jadwal رابطة لشرط مقدر, Mujtaba مستأنفة; Darwish عاطفة = ours. |
| 46:17 لكما (audit) | أعني مقدرا | Mujtaba أعني, Darwish حال, Samin بيان; Jadwal باسم الفعل = ours. |

Open (not changed, worth a later pass): «إنك أنت ...» and «إنا نحن ...» elsewhere —
60:5 now reads أنت = توكيد (al-Jadwal + al-Mujtaba), other ayahs still say فصل.
64:13 «فليتوكل»: ours says الفاء حرف استئناف; Mujtaba زائدة, Jadwal رابطة (no two agree).
