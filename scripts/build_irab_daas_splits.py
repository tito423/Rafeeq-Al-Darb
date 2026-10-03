"""Cut each multi-ayah section of al-Da'as's i'rab at the ayah it moves to.

Owner (2026-10-03): «الاعراب جايب الصفحة كلها انا عايزه يجيب ايه ايه بس».
The book parses 2-12 ayahs as one run. The run is NOT rewritten: this only
finds, for ayah k of a section, the offset of the first «…» quote that
parses a word of ayah k, so the app can show the part that belongs to the
opened ayah.

Quotes are aligned in order to the section's mushaf words (consonant
skeleton, resolve_irab_daas_refs.wskel/skel). A section is cut only when
every ayah after the first gets a boundary, boundaries rise, and the quotes
cover at least half the words of each ayah; any other section is left whole
(the app then shows the whole run and says which ayahs it covers).

    py -3 scripts/build_irab_daas_splits.py <quran_sciences.db>
      -> rafeeq_app/assets/data/irab_daas_splits.json  {"s:from": [off,...]}
"""
import json
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from resolve_irab_daas_refs import skel, wskel  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'irab_daas_splits.json')
BASMALA = 'بسم الله الرحمن الرحيم'
WINDOW = 12


def lo(w):
    return re.sub('ل+', 'ل', skel(w))


def eq(a, b):
    return a == b or (lo(a) and lo(a) == lo(b))


def ayah_words(text, ayah, surah):
    words = wskel(text).split()
    if ayah == 1 and surah not in (1, 9):
        b = wskel(BASMALA).split()
        if words[:len(b)] == b:
            words = words[len(b):]
    return words


def split(text, surah, a0, a1, ay):
    stream = [(w, k) for k in range(a0, a1 + 1)
              for w in ayah_words(ay[(surah, k)], k, surah)]
    p, first, hit = 0, {}, [0] * len(stream)
    for m in re.finditer(r'«([^«»]+)»', text):
        q = m.group(1)
        if re.search(r'[\d٠-٩]', q):
            continue
        t = wskel(q).split()
        if not t:
            continue
        for j in range(p, min(p + WINDOW, len(stream) - len(t) + 1)):
            if all(eq(t[i], stream[j + i][0]) for i in range(len(t))):
                k = stream[j][1]
                first.setdefault(k, m.start())
                for i in range(len(t)):
                    hit[j + i] = 1
                p = j + len(t)
                break
    cuts = []
    for k in range(a0 + 1, a1 + 1):
        if k not in first or (cuts and first[k] <= cuts[-1]):
            return None
        idx = [i for i, (_, kk) in enumerate(stream) if kk == k]
        if idx and sum(hit[i] for i in idx) * 2 < len(idx):
            return None
        cuts.append(first[k])
    for k in range(a0, a1 + 1):  # the first ayah too must be covered
        idx = [i for i, (_, kk) in enumerate(stream) if kk == k]
        if idx and sum(hit[i] for i in idx) * 2 < len(idx):
            return None
    return cuts


def main():
    sci = sqlite3.connect(sys.argv[1])
    q = sqlite3.connect(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    ay = {(s, a): t for s, a, t in q.execute('select surah_id, ayah_number, text_clean from ayahs')}
    out, bad = {}, []
    rows = sci.execute('select surah, ayah_from, ayah_to, text from irab_daas '
                       'where ayah_to > ayah_from order by surah, ayah_from').fetchall()
    for s, a0, a1, text in rows:
        c = split(text, s, a0, a1, ay)
        if c is None:
            bad.append(f'{s}:{a0}-{a1}')
        else:
            out[f'{s}:{a0}'] = c
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(out, f, separators=(',', ':'))
    sys.stdout.reconfigure(encoding='utf-8')
    print(f'multi-ayah sections {len(rows)} | cut {len(out)} | left whole {len(bad)}')
    print('left whole:', ' '.join(bad))


if __name__ == '__main__':
    main()
