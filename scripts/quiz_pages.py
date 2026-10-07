"""Helper for authoring quiz questions (scripts/quiz/q_*.json): prints library
book pages without diacritics, so they can be read cheaply, and marks pages
already used by a question.
    py -3 scripts/quiz_pages.py <book> <first pageIndex> <count> [maxchars]"""
import glob, io, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from build_history_quiz import book, SRC
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
DIA = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭ]')
bid, a, n = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
mx = int(sys.argv[4]) if len(sys.argv) > 4 else 1800
used = {q['pageIndex'] for f in glob.glob(os.path.join(SRC, 'q_*.json'))
        for q in json.load(open(f, encoding='utf-8')) if q['book'] == bid}
b = book(bid)
print(bid, 'pages', len(b['pages']), 'used', len(used))
for i in range(a, min(a + n, len(b['pages']))):
    pg = b['pages'][i]
    t = DIA.sub('', ' '.join(p['t'] for p in pg['paras']))
    print(f'## {i} p{pg["p"]}{" USED" if i in used else ""}: {t[:mx]}')
