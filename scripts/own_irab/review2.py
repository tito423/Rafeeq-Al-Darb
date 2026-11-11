"""Second review of the own i'rab: a wider jury of named books (owner,
2026-11-12: «شوف كتاب محقق وراجع عليه»).

No classical book parses every word, so the jury is asked only about words
still in doubt. Books (tafsir.app src, checked live 2026-11-12):
  iraab-alnahas          al-Nahhas, «إعراب القرآن»
  makki                  Makki b. Abi Talib, «مشكل إعراب القرآن»
  mujtaba-mushkil-iraab  Ahmad al-Kharrat, «المجتبى من مشكل إعراب القرآن»
  albahr-almuheet        Abu Hayyan, «البحر المحيط» (al-Samin's main source)
plus al-Samin's cut from the first review.

Groups:
  A  every word the first review left OURS_WRONG / UNCLEAR / NO_SOURCE
     (pk/ and pkr/ out files), minus the 7 already fixed
  B  the role alternatives the first review skipped (one book against ours,
     ours = al-Da'as)
A word none of the four books mentions is dropped: they add nothing on it.

    py -3 review2.py fetch A|B      download (3 workers, cached, atomic)
    py -3 review2.py cut A|B        -> pk2A/ or pk2B/ batches of 30
"""
import glob, json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from books import get
from samin_cut import keys, windows, bare, samin
from samin_targets import kind

BOOKS = [('iraab-alnahas', 'NAHHAS'), ('makki', 'MAKKI'),
         ('mujtaba-mushkil-iraab', 'MUJTABA'), ('albahr-almuheet', 'BAHR')]
FIXED = {(39, 65), (44, 17), (45, 16), (46, 26), (46, 27), (67, 18), (81, 23)}


def words():
    out = {}
    for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
        out[int(os.path.basename(f)[:3])] = json.load(open(f, encoding='utf-8'))['words']
    return out


def targets(group, W):
    if group == 'A':
        ids = set()
        for f in glob.glob(os.path.join(H, 'pk', 'out_b*.tsv')) + glob.glob(os.path.join(H, 'pkr', 'out_b*.tsv')):
            for l in open(f, encoding='utf-8'):
                p = l.rstrip('\n').split('\t')
                if len(p) > 1 and p[1].strip() in ('OURS_WRONG', 'UNCLEAR', 'NO_SOURCE'):
                    ids.add(re.sub(r'\s*\(.*\)', '', p[0]).strip())
        t = [tuple(map(int, i.split(':'))) for i in ids]
        return sorted(x for x in t if (x[0], x[1]) not in FIXED)
    done = set()
    for f in ['samin_targets.json']:
        pass
    tg = json.load(open(os.path.join(H, 'samin_targets.json'), encoding='utf-8'))
    out = []
    for t in tg:
        if t['group'] != 'role':
            continue
        w = W[t['s']][t['i']]
        bs = {x['book'] for x in w['alts'] if kind(x['text']) == 'role'}
        if 'daas' in bs or {'jadwal', 'darwish'} <= bs:
            continue  # reviewed in the first pass
        out.append((t['s'], t['a'], t['i']))
    return sorted(out)


def fetch(group):
    W = words()
    ayahs = sorted({(s, a) for s, a, _ in targets(group, W)})
    jobs = [(src, s, a) for s, a in ayahs for src, _ in BOOKS] + [('aldur-almasoon', s, a) for s, a in ayahs]
    jobs = [j for j in jobs if not os.path.exists(os.path.join(H, 'books_cache', f'{j[0]}_{j[1]}_{j[2]}.json'))]
    print(len(ayahs), 'ayahs,', len(jobs), 'to fetch', flush=True)

    def one(j):
        try:
            get(*j)
            return None
        except Exception as e:
            return f'{j}: {e}'
    with ThreadPoolExecutor(3) as ex:
        for n, err in enumerate(ex.map(one, jobs)):
            if err:
                print('FAIL', err, flush=True)
            if n % 500 == 0:
                print(n, flush=True)
    print('done')


def cut(group):
    W = words()
    out, dropped = [], 0
    for s, a, i in targets(group, W):
        w = W[s][i]
        ks = keys(w['w'])
        cuts = {}
        for src, name in BOOKS:
            t = get(src, s, a) or ''
            c = windows(t, ks, 2 if name != 'BAHR' else 1)
            if c:
                cuts[name] = bare(c)
        if not cuts:
            dropped += 1
            continue
        idx = [j for j, x in enumerate(W[s]) if x['a'] == a]
        lo, hi = max(idx[0], i - 6), min(idx[-1], i + 6)
        ayah = ' '.join(('[' + W[s][j]['w'] + ']') if j == i else bare(W[s][j]['w']) for j in range(lo, hi + 1))
        sm = samin(s, a, w['w'])
        out.append((f'{s}:{a}:{i}', ayah, w, cuts, bare(sm) if sm and not sm.startswith('(no direct') else 'silent'))
    d = os.path.join(H, f'pk2{group}')
    os.makedirs(d, exist_ok=True)
    B = 30
    for n in range(0, len(out), B):
        with open(os.path.join(d, f'b{n // B:03d}.txt'), 'w', encoding='utf-8') as f:
            for pid, ayah, w, cuts, sm in out[n:n + B]:
                f.write(f'### {pid}\nAYAH: {ayah}\nOURS: {w["irab"]}\n')
                for x in w.get('alts', []):
                    f.write(f"ALT {x['book']}: {x['text']}\n")
                f.write(f'SAMIN: {sm}\n')
                for name, c in cuts.items():
                    f.write(f'{name}: {c}\n')
                f.write('\n')
    size = sum(os.path.getsize(os.path.join(d, x)) for x in os.listdir(d) if x.startswith('b'))
    print(len(out), 'packets;', dropped, 'dropped (all four books silent);', (len(out) + B - 1) // B, 'batches;', size, 'B')


if __name__ == '__main__':
    {'fetch': fetch, 'cut': cut}[sys.argv[1]](sys.argv[2])
