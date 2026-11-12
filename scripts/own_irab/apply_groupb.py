"""Applies write_surah.GROUPB to the NNN.json files: the new i'rab replaces the
old, and al-Da'as's own text on the word (daas_quote.py) stays under it as the
`daas` alt. Rerunning also replaces a daas alt written in our wording (the
first run of 2026-11-12 did that) with the book's text."""
import json, os, sys
sys.stdout.reconfigure(encoding='utf-8')
from write_surah import GROUPB, H, bare
from daas_quote import quote
for surah in sorted({k[0] for k in GROUPB}):
    f = os.path.join(H, f'{surah:03d}.json')
    d = json.load(open(f, encoding='utf-8'))
    for (s, a, w), reps in GROUPB.items():
        if s != surah:
            continue
        hit = [x for x in d['words'] if x['a'] == a and bare(x['w']) == w]
        assert hit, (s, a, w)
        changed = 0
        for x in hit:
            if x['check'] != 'alt':
                continue
            old = x['irab']
            new = old
            for o, n in reps:
                if n in new:
                    continue
                if o in new:
                    new = new.replace(o, n)
            if new == old:
                for al in x.get('alts', []):
                    if al['book'] == 'daas' and not al['text'].startswith('«') and quote(s, a, w):
                        al['text'] = quote(s, a, w)
                        changed += 1
                continue
            x['irab'] = new
            x['check'] = 'alt'
            alts = x.setdefault('alts', [])
            if not any(al['book'] == 'daas' for al in alts):
                alts.append({'book': 'daas', 'text': quote(s, a, w) or old})
            changed += 1
        print('fixed' if changed else 'already/none', s, a, len(hit), changed)
    json.dump(d, open(f, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
