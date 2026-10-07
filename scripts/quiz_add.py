"""Adds authored questions to scripts/quiz/<file>.json. Each question is
written with its quote WITHOUT diacritics (as quiz_pages.py prints it); the
quote is located on its page ignoring diacritics and stored VERBATIM from the
book, with the page's printed number. Fails loudly if the quote is not found.
    py -3 scripts/quiz_add.py <file> <questions.json>
questions.json: [{"book","pageIndex","level","q","choices"[right first],"quote","explain"}]"""
import io, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from build_history_quiz import book, SRC
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
DIA = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭ]')


def verbatim(text, plain):
    """The substring of text whose undiacritised form is plain."""
    keep = [i for i, c in enumerate(text) if not DIA.match(c)]
    bare = ''.join(text[i] for i in keep)
    k = bare.find(plain)
    if k < 0:
        return None
    s, e = keep[k], keep[k + len(plain) - 1] + 1
    while e < len(text) and DIA.match(text[e]):
        e += 1
    return text[s:e]


out_path = os.path.join(SRC, sys.argv[1] + '.json')
out = json.load(open(out_path, encoding='utf-8')) if os.path.exists(out_path) else []
bad = 0
for q in json.load(open(sys.argv[2], encoding='utf-8')):
    pg = book(q['book'])['pages'][q['pageIndex']]
    text = '\n'.join(p['t'] for p in pg['paras'])
    v = verbatim(text, ' '.join(q['quote'].split()))
    if v is None:
        v = verbatim(text.replace('\n', ' '), ' '.join(q['quote'].split()))
    if v is None:
        print('NOT FOUND', q['pageIndex'], q['quote'][:60]); bad += 1; continue
    out.append({'book': q['book'], 'pageIndex': q['pageIndex'], 'p': pg['p'],
                'level': q['level'], 'q': q['q'], 'choices': q['choices'],
                'quote': v, 'explain': q['explain']})
json.dump(out, open(out_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', len(out), 'in', sys.argv[1], 'missing', bad)
