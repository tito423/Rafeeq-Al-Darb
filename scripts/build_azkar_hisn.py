"""Build rafeeq_app/assets/data/azkar.db from Hisn al-Muslim.

    py -3 scripts/build_azkar_hisn.py

Source: scripts/azkar_hisn/hisn_elmuslim_asellam.json (see README there).

Qur'an inside the book (owner: «آيات وحروف القرآن الكريم مفيش فيها هزار»,
CLAUDE.md 1.2): every passage the book puts in braces is located in the
mushaf by its consonant skeleton, and the quoted words are then written from
`quran_local.db` (the Madinah text the app shows everywhere else). A passage
that cannot be located stops the build - it is never guessed.
Two passages end in «...» because the book only names the start of a surah
(«ألم * تنزيل ...», «تبارك الذي بيده الملك ...»); they are kept as printed.
"""
import difflib
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
SRC = os.path.join(HERE, 'azkar_hisn', 'hisn_elmuslim_asellam.json')
QDB = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db')
OUT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'azkar.db')

MARK = re.compile('[\u0640\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u08d3-\u08ff]')


def words(s):
    s = re.sub(r'\(\s*\d+\s*\)', '', s).replace('...', ' ').replace('*', ' ')
    s = MARK.sub('', s)
    return re.sub(r'[^\u0621-\u064a\u0671 ]', ' ', s).split()


def relax(w):
    # Consonant skeleton. Doubled letters collapse because the mushaf writes
    # «ٱلَّيۡلِ» with one lam and a shadda where plain spelling has «الليل».
    w = re.sub('[اأإآٱءؤئىيو]', '', w)
    return re.sub(r'(.)\1+', r'\1', w)


def load_quran():
    c = sqlite3.connect(QDB)
    by = {}
    for sid, n, t in c.execute(
            'select surah_id, ayah_number, text_uthmani from ayahs order by id'):
        for w in t.split():
            by.setdefault(sid, []).append((n, w))
    return by


def locate(seg, quran):
    """Every place in the mushaf whose consonant skeleton equals the segment's.

    Returns (surah, [(ayah, word), ...]) with EVERY mushaf word between the
    first and last match - including words whose skeleton is empty («أو»,
    «يا»), which matching skips - 3:195's «أَوۡ» went missing from the output
    that way until test/azkar_hisn_test.dart caught it.
    """
    key = [relax(w) for w in words(seg)]
    key = [k for k in key if k]
    hits = []
    for sid, ws in quran.items():
        rel = [(i, relax(MARK.sub('', w))) for i, (n, w) in enumerate(ws)]
        rel = [r for r in rel if r[1]]
        keys = [r[1] for r in rel]
        for i in range(len(keys) - len(key) + 1):
            if keys[i:i + len(key)] == key:
                a, z = rel[i][0], rel[i + len(key) - 1][0]
                hits.append((sid, ws[a:z + 1]))
    return hits


def replace_quran(text, quran, log, diffs):
    def sub(m):
        seg = m.group(1)
        if '...' in seg:
            log.append(('KEPT-AS-PRINTED', seg.strip()[:60]))
            return m.group(0)
        hits = locate(seg, quran)
        if len(hits) != 1:
            print('NOT LOCATED / AMBIGUOUS (%d):' % len(hits), seg[:80])
            sys.exit(1)
        sid, ws = hits[0]
        # Words the mushaf has and the book's quotation lacks (their skeleton
        # is empty, so matching skips them) are logged, never silently kept.
        book = [MARK.sub('', w).replace('ٱ', 'ا') for w in words(seg)]
        for n, w in ws:
            if not relax(MARK.sub('', w)):
                bare = MARK.sub('', w).replace('ٱ', 'ا')
                if bare not in book:
                    log.append(('WORD-MISSING-IN-BOOK', '%d:%d' % (sid, n), w))
        # Evidence for the owner's rule: what differed between the book's
        # spelling and the mushaf's, word by word.
        hw = words(seg)
        mw = [MARK.sub('', w) for n, w in ws]
        sm = difflib.SequenceMatcher(
            None, [relax(w) or w for w in hw], [relax(w) or w for w in mw],
            autojunk=False)
        for op, a1, a2, b1, b2 in sm.get_opcodes():
            if op == 'equal':
                for h, m2, (n, _) in zip(hw[a1:a2], mw[b1:b2], ws[b1:b2]):
                    if h != m2:
                        diffs.add('%d:%d  %s -> %s' % (sid, n, h, m2))
            else:
                diffs.add('%d:%d  DIFFERENT WORDS  book=%s mushaf=%s' % (
                    sid, ws[b1][0] if b1 < len(ws) else ws[-1][0],
                    ' '.join(hw[a1:a2]), ' '.join(mw[b1:b2])))
        out, prev = [], None
        for n, w in ws:
            if prev is not None and n != prev:
                out.append('*')
            out.append(w)
            prev = n
        log.append((sid, ws[0][0], ws[-1][0]))
        return '{ ' + ' '.join(out) + ' }'
    return re.sub(r'\{([^}]*)\}', sub, text)


def main():
    src = json.load(open(SRC, encoding='utf-8'))
    quran = load_quran()
    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.execute('CREATE TABLE azkar_sections(\n  id INTEGER PRIMARY KEY AUTOINCREMENT, '
               'title TEXT NOT NULL)')
    db.execute('CREATE TABLE azkar_items(\n  id INTEGER PRIMARY KEY AUTOINCREMENT, '
               'section_id INTEGER NOT NULL,\n  body TEXT NOT NULL, footnote TEXT, '
               'repeat INTEGER NOT NULL DEFAULT 1)')
    log = []
    diffs = set()
    n_items = 0
    for title, chap in src.items():
        cur = db.execute('INSERT INTO azkar_sections(title) VALUES(?)',
                         (re.sub(r'\s+', ' ', title).strip(),))
        sid = cur.lastrowid
        for x in chap['Adhkar']:
            body = replace_quran(x['Text'].strip(), quran, log, diffs)
            db.execute(
                'INSERT INTO azkar_items(section_id, body, footnote, repeat) '
                'VALUES(?,?,?,?)',
                (sid, body, x['Reference'].strip(), int(x['Count'])))
            n_items += 1
    db.commit()
    db.execute('VACUUM')
    db.close()
    print('sections', len(src), 'items', n_items)
    for l in log:
        print('  quran', l)
    rep = os.path.join(HERE, 'azkar_hisn', 'quran_orthography_report.txt')
    order = sorted(diffs, key=lambda z: (int(z.split(':')[0]),
                                         int(z.split(':')[1].split()[0])))
    head = ('Book spelling -> mushaf spelling (Madinah text), written by '
            'build_azkar_hisn.py.'+chr(10)+'The mushaf wording is what the app shows.'+chr(10)+chr(10))
    with open(rep, 'w', encoding='utf-8', newline=chr(10)) as f:
        f.write(head + chr(10).join(order) + chr(10))


if __name__ == '__main__':
    main()
