"""Builds the review target list (SAMIN_REVIEW.md, budget plan) and prefetches
al-Samin «الدر المصون» (tafsir.app src=aldur-almasoon) for their ayahs.

Targets, each {s, a, i (word index in the surah file), group}:
  fuller   - al-Da'as silent, no book behind ours
  repeat   - audit_repeats.py role conflicts (passed as a TSV path)
  role     - `alt` words whose other view names a different ROLE (not only
             the mahall of a clause or a ta'alluq: those stay shown as khilaf)

    py -3 samin_targets.py rep_keep.tsv [--fetch]
writes samin_targets.json; --fetch downloads missing al-Samin pages (0.4 s apart).
"""
import glob, json, os, re, sys, time
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from books import get

ROLE_WORDS = re.compile(r'مرفوع|منصوب|مجرور|مفعول|فاعل|مبتدأ|خبر|حال|نعت|صفة|بدل|تمييز|ظرف|مضاف|توكيد|اسم')


def kind(alt):
    if re.search(r'جملة|الجملة', alt) and not ROLE_WORDS.search(re.sub(r'جملة.*', '', alt)):
        return 'clause'
    if re.search(r'متعلق|متعلّق', alt) and not re.search(r'مرفوع|منصوب|مجرور|مفعول به|فاعل|مبتدأ|خبر', alt):
        return 'attach'
    if 'زائد' in alt:
        return 'zaid'
    return 'role'


def main():
    rep = set()
    for l in open(sys.argv[1], encoding='utf-8'):
        sa, tok = l.split('\t')[:2]
        s, a = sa.split(':')
        rep.add((int(s), int(a), tok))
    out = []
    for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
        s = int(os.path.basename(f)[:3])
        for i, w in enumerate(json.load(open(f, encoding='utf-8'))['words']):
            g = None
            if w['check'] == 'fuller':
                g = 'fuller'
            elif any((s, w['a'], t) == (s, w['a'], re.sub(r'[ۖۗۚۛۜۘۙ۞۩ـ]', '', w['w'])) for (x, y, t) in rep if (x, y) == (s, w['a'])):
                g = 'repeat'
            elif w['check'] == 'alt' and any(kind(al['text']) == 'role' for al in w['alts']):
                g = 'role'
            if g:
                out.append({'s': s, 'a': w['a'], 'i': i, 'group': g})
    json.dump(out, open(os.path.join(H, 'samin_targets.json'), 'w', encoding='utf-8'))
    from collections import Counter
    ayahs = sorted({(t['s'], t['a']) for t in out})
    print(Counter(t['group'] for t in out), len(ayahs), 'ayahs')
    if '--fetch' in sys.argv:
        miss = [x for x in ayahs if not os.path.exists(os.path.join(H, 'books_cache', f'aldur-almasoon_{x[0]}_{x[1]}.json'))]
        print(len(miss), 'to fetch', flush=True)
        for n, (s, a) in enumerate(miss):
            for k in range(4):
                try:
                    get('aldur-almasoon', s, a)
                    break
                except Exception as e:
                    print('retry', s, a, e, flush=True)
                    time.sleep(5 * (k + 1))
            if n % 100 == 0:
                print(n, s, a, flush=True)
            time.sleep(0.4)
        print('done')


if __name__ == '__main__':
    main()
