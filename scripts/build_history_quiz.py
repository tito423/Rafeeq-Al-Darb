"""Builds rafeeq_app/assets/data/quiz/history_quiz.json - the Islamic-history
quiz - from the authored question files in scripts/quiz/q_*.json, and fails
unless every question stands on its book:

* `quote` is a verbatim substring of page `pageIndex` of the library book
  `books/text/<book>.json` (the same file the app downloads), and `p` is
  that page's printed number;
* four distinct choices, the right one first (the app shuffles them);
* the book is in the app's library catalogue.

Books are read from the GitHub `content-mirror` release (R2 is blocked from
the cloud container) and cached in scripts/out/quiz_books/.

    python3 scripts/build_history_quiz.py
"""
import glob
import gzip
import hashlib
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'scripts', 'quiz')
CACHE = os.path.join(ROOT, 'scripts', 'out', 'quiz_books')
OUT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quiz',
                   'history_quiz.json')
MIRROR = ('https://github.com/tito423/Rafeeq-Al-Darb/releases/download/'
          'content-mirror/books__text__{}.json')
LEVELS = ('l1', 'l2', 'l3', 'l4', 'l5')


def book(bid):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, bid + '.json')
    if not os.path.exists(path):
        req = urllib.request.Request(MIRROR.format(bid),
                                     headers={'User-Agent': 'rafeeq-build'})
        data = urllib.request.urlopen(req, timeout=120).read()
        with open(path + '.part', 'wb') as f:
            f.write(data)
        os.replace(path + '.part', path)
    raw = open(path, 'rb').read()
    if raw[:2] == b'\x1f\x8b':
        raw = gzip.decompress(raw)
    return json.loads(raw)


def main():
    catalog = open(os.path.join(ROOT, 'rafeeq_app', 'lib', 'features',
                                'library', 'data', 'book_catalog.dart'),
                   encoding='utf-8').read()
    books, out, bad, seen = {}, [], [], set()
    for f in sorted(glob.glob(os.path.join(SRC, 'q_*.json'))):
        for n, q in enumerate(json.load(open(f, encoding='utf-8'))):
            where = '%s #%d' % (os.path.basename(f), n)
            bid = q['book']
            if f"id: '{bid}'" not in catalog:
                bad.append(where + ': book not in the library catalogue')
                continue
            b = books.get(bid) or books.setdefault(bid, book(bid))
            pg = b['pages'][q['pageIndex']]
            text = '\n'.join(p['t'] for p in pg['paras'])
            if q['quote'] not in text:
                bad.append(where + ': quote not on page %d' % q['pageIndex'])
            if pg['p'] != q['p']:
                bad.append(where + ': p %s != printed %s' % (q['p'], pg['p']))
            if len(set(q['choices'])) != 4 or len(q['choices']) != 4:
                bad.append(where + ': choices are not 4 distinct')
            if q['level'] not in LEVELS:
                bad.append(where + ': level ' + q['level'])
            key = q['q'].strip()
            if key in seen:
                bad.append(where + ': duplicate question')
            seen.add(key)
            qid = hashlib.sha1((bid + key).encode()).hexdigest()[:10]
            out.append({'id': qid, **{k: q[k] for k in (
                'level', 'q', 'choices', 'explain', 'book', 'pageIndex', 'p',
                'quote')}})
    if bad:
        print('\n'.join(bad))
        sys.exit('FAILED: %d problem(s)' % len(bad))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump({'schema': 1,
                   # the app keeps whichever bank (bundled or hosted
                   # quiz/history_quiz.json) is larger
                   'version': len(out),
                   'note': 'Built by scripts/build_history_quiz.py; every '
                           'quote is verbatim from its library page.',
                   'questions': out}, f, ensure_ascii=False, indent=0)
    per = {l: sum(1 for q in out if q['level'] == l) for l in LEVELS}
    print('OK %d questions %s from %s' % (len(out), per, sorted(books)))


if __name__ == '__main__':
    main()
