"""Neighbour coherence of applied role changes: for every GROUPB word whose
new i'rab names a relation (first/second object, badal, na't, 'atf, khabar,
mubtada, ism, hal, tamyiz, mafʿul mutlaq ...) print it with the words before
and after, so a change that clashes with a neighbour's i'rab is seen."""
import json, re, sys
sys.stdout.reconfigure(encoding='utf-8')
from write_surah import GROUPB, bare
REL = re.compile('مفعول به (أول|ثان)|بدل|نعت|صفة|معطوف|خبر|مبتدأ|اسم «|حال|تمييز|مفعول مطلق|توكيد|نائب فاعل|فاعل')
PART = re.compile(r'^(الواو|الفاء|ثم) ')
seen = set()
for (s, a, w), reps in sorted(GROUPB.items()):
    d = json.load(open(f'{s:03d}.json', encoding='utf-8'))['words']
    for i, x in enumerate(d):
        if x['a'] != a or bare(x['w']) != w or x['check'] != 'alt': continue
        if (s, a, i) in seen: continue
        seen.add((s, a, i))
        if PART.match(x['irab']) and not REL.search(x['irab'].split('،', 1)[-1]): continue
        if not REL.search(x['irab']): continue
        print(f'## {s}:{a} {x["w"]}')
        for j in range(max(0, i - 2), min(len(d), i + 3)):
            mark = '>>' if j == i else '  '
            print(f'{mark} {d[j]["w"]}: {d[j]["irab"][:150]}')
