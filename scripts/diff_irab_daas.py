"""Compare the two digital copies of al-Da'as's i'rab, section by section.

Copy A: Shamela 23584, cut into the book's own sections (parse_irab_daas.py).
Copy B: e-quran.com `eerab`, one page per ayah (fetch_irab_daas_equran.py).

For each book section, B's pages for ayah_from..ayah_to are joined and both
texts are reduced to bare letters (no tashkil, no brackets or punctuation,
alef/ya/ta-marbuta forms kept as they are - only marks are dropped) and
compared word by word. What comes out is a measure of agreement, not a
correction: nothing here rewrites either copy.

    py -3 scripts/diff_irab_daas.py      -> scripts/temp_phase1/irab_daas_diff.json
"""
import difflib
import html
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, 'scripts', 'temp_phase1', 'irab_daas.json')
B = os.path.join(ROOT, 'scripts', 'shamela_raw', 'irab_daas_equran.jsonl')
OUT = os.path.join(ROOT, 'scripts', 'temp_phase1', 'irab_daas_diff.json')

MARKS = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')


def b_body(page_html):
    """The i'rab block of one e-quran page: after the nav, before «قارن التفاسير»."""
    m = re.search(r'<main.*?</main>', page_html, re.S)
    t = html.unescape(re.sub(r'<[^>]+>', '\n', m.group(0) if m else page_html))
    lines = [x.strip() for x in t.split('\n') if x.strip()]
    try:
        start = lines.index('التالي') + 1
        end = lines.index('قارن التفاسير')
    except ValueError:
        return None
    body = lines[start:end]
    # The first line is the whole ayah in parentheses; the book text follows.
    if body and body[0].startswith('('):
        body = body[1:]
    return '\n'.join(body)


def words(t):
    t = MARKS.sub('', t)
    t = re.sub(r'[^ء-ي\s]', ' ', t)
    return t.split()


def main():
    rows = json.load(io.open(A, encoding='utf-8'))
    pages = {}
    for l in io.open(B, encoding='utf-8'):
        d = json.loads(l)
        pages[(d['s'], d['a'])] = b_body(d['html'])
    out, complete = [], 0
    for r in rows:
        keys = [(r['surah'], a) for a in range(r['from'], r['to'] + 1)]
        if not all(k in pages and pages[k] is not None for k in keys):
            continue
        complete += 1
        b = '\n'.join(pages[k] for k in keys)
        wa, wb = words(r['text']), words(b)
        ratio = difflib.SequenceMatcher(None, wa, wb, autojunk=False).ratio()
        # Same words in another order: the two copies put a word-meanings
        # paragraph before or after the i'rab (2:70-71). Not a disagreement
        # about the text.
        if ratio == 1.0:
            kind = 'identical'
        elif sorted(wa) == sorted(wb):
            kind = 'reordered'
        elif 'يوجد إعراب' in b or len(wb) < 0.8 * len(wa):
            kind = 'b_missing'
        elif len(wa) < 0.8 * len(wb):
            kind = 'a_missing'
        else:
            kind = 'differs'
        out.append({'surah': r['surah'], 'from': r['from'], 'to': r['to'],
                    'page': r['page'], 'ratio': round(ratio, 4), 'kind': kind,
                    'unbalanced_a': sum(1 for p in r['text'].split('\n')
                                        if p.count('«') != p.count('»')),
                    'b': b})
    json.dump(out, io.open(OUT, 'w', encoding='utf-8'), ensure_ascii=False)
    sys.stdout.reconfigure(encoding='utf-8')
    buckets = [(1.0, 1.0), (0.98, 0.9999), (0.95, 0.98), (0.9, 0.95), (0.0, 0.9)]
    print(f'{complete} of {len(rows)} sections have every ayah page in copy B')
    for lo, hi in buckets:
        n = sum(1 for o in out if lo <= o['ratio'] <= hi)
        print(f'  ratio {lo:.2f}-{hi:.4f}: {n}')
    import collections
    print('  kinds:', dict(collections.Counter(o['kind'] for o in out)))
    dmg = [o for o in out if o['unbalanced_a']]
    print(f'  damaged-in-A sections compared: {len(dmg)}, their ratios:',
          sorted(o['ratio'] for o in dmg)[:15])


if __name__ == '__main__':
    main()
