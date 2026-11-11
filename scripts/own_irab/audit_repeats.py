"""Same text, same i'rab (SAMIN_REVIEW.md step 0), no model.

Every run of N (default 4) identical mushaf tokens that recurs is grouped; for
each inner token (not the first, whose link to what precedes it may differ,
and not the last, whose clause place may differ) the head clause of its
i'rab (role + case, up to the first «،») is compared across occurrences.
Where they differ the minority occurrences are printed with the majority
form - a candidate, read before anything changes.

    py -3 audit_repeats.py [N] > out.tsv
"""
import glob, json, os, re, sys
from collections import Counter, defaultdict
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
N = int(sys.argv[1]) if len(sys.argv) > 1 else 4
STRIP = re.compile(r'[ۖۗۚۛۜۘۙ۞۩ـ]')


SIG = ['نائب فاعل', 'فاعل', 'مبتدأ', 'اسم «إن', 'اسم «كان', 'خبر «كان', 'خبر', 'مفعول به', 'مفعول مطلق',
       'مفعول فيه', 'ظرف', 'مفعول لأجله', 'مفعول معه', 'حال', 'تمييز', 'مضاف إليه', 'بدل', 'نعت|صفة',
       'معطوف', 'توكيد', 'مستثنى', 'منادى', 'حرف', 'فعل', 'ضمير فصل', 'زائد']


def head(ir):
    """Role signature of the head clause: the role named FIRST in it
    (wording differences are not flagged)."""
    h = re.split(r'[،.]', ir)[0]
    best = None
    for r in SIG:
        m = re.search(r, h)
        if m and (best is None or m.start() < best[0]):
            best = (m.start(), r)
    return best[1] if best else h.strip()


seq = []
for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
    s = os.path.basename(f)[:3]
    for w in json.load(open(f, encoding='utf-8'))['words']:
        seq.append((s, w['a'], STRIP.sub('', w['w']), head(w['irab'])))

grams = defaultdict(list)
for i in range(len(seq) - N + 1):
    win = seq[i:i + N]
    if len({(x[0], x[1]) for x in win}) > 1:
        continue  # stay inside one ayah
    grams[tuple(x[2] for x in win)].append(i)

seen = set()
n = 0
for g, starts in grams.items():
    if len(starts) < 2:
        continue
    for k in range(1, N - 1):
        heads = Counter(seq[i + k][3] for i in starts)
        if len(heads) < 2:
            continue
        major, cnt = heads.most_common(1)[0]
        for i in starts:
            x = seq[i + k]
            key = (x[0], x[1], k + i)
            if x[3] != major and key not in seen:
                seen.add(key)
                n += 1
                print(f'{x[0]}:{x[1]}\t{x[2]}\t{cnt}/{len(starts)}\tOURS: {x[3]}\tMAJ: {major}')
print(f'{n} divergent occurrences (N={N})', file=sys.stderr)
