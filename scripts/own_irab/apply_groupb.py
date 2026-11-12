"""Applies write_surah.GROUPB to the NNN.json files: the new i'rab replaces the
old, and the old text stays under the word as al-Da'as's view (quoted)."""
import json, os, sys
sys.stdout.reconfigure(encoding='utf-8')
from write_surah import GROUPB, H, bare
for surah in sorted({k[0] for k in GROUPB}):
    f = os.path.join(H, f'{surah:03d}.json')
    d = json.load(open(f, encoding='utf-8'))
    for (s, a, w), reps in GROUPB.items():
        if s != surah:
            continue
        hit = [x for x in d['words'] if x['a'] == a and bare(x['w']) == w]
        assert len(hit) == 1, (s, a, w, len(hit))
        x = hit[0]
        old = x['irab']
        new = old
        for o, n in reps:
            if n in new:
                continue
            assert o in new, (s, a, w, o)
            new = new.replace(o, n)
        if new == old:
            print('already', s, a); continue
        x['irab'] = new
        x['check'] = 'alt'
        alts = x.setdefault('alts', [])
        if not any(al['book'] == 'daas' for al in alts):
            alts.append({'book': 'daas', 'text': old})
        print('fixed', s, a)
    json.dump(d, open(f, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
