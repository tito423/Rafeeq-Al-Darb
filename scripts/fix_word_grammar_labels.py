"""Rewrite word_grammar.pos_ar and .case_ar in quran_sciences.db from the corpus, correctly.

Only those two columns change, and only from the same source file the table
was built from (temp_phase1/corpus_morphology.xml); tafsirs, translations
and word meanings are not touched. See corpus_labels.py for what was wrong.

    py -3 scripts/fix_word_grammar_labels.py
"""
import collections
import html
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(__file__))
from corpus_labels import label, pos_label  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XML = os.path.join(ROOT, 'scripts', 'temp_phase1', 'corpus_morphology.xml')
DB = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_sciences.db')
PAT = re.compile(r'<word number="(\d+)" token="([^"]*)" morphology="([^"]*)"')


def main():
    new = {}
    ch = vs = 0
    for line in open(XML, encoding='utf-8'):
        m = re.search(r'<chapter number="(\d+)"', line)
        if m:
            ch = int(m.group(1))
            continue
        m = re.search(r'<verse number="(\d+)"', line)
        if m:
            vs = int(m.group(1))
            continue
        m = PAT.search(line)
        if m:
            morph = html.unescape(m.group(3))
            new[(ch, vs, int(m.group(1)))] = (pos_label(morph), label(morph))
    con = sqlite3.connect(DB)
    rows = con.execute('select surah, ayah, pos, pos_ar, case_ar from word_grammar').fetchall()
    if len(rows) != len(new) or any((s, a, p) not in new for s, a, p, _, _ in rows):
        sys.exit(f'row keys differ: db {len(rows)} vs corpus {len(new)}')
    changes = [(*new[(s, a, p)], s, a, p) for s, a, p, pa, ca in rows
               if new[(s, a, p)] != (pa, ca)]
    con.executemany('update word_grammar set pos_ar=?, case_ar=? where surah=? and ayah=? and pos=?',
                    changes)
    con.commit()
    after = collections.Counter(
        r[0] for r in con.execute("select case_ar from word_grammar where pos_ar='حرف جر'"))
    con.execute('vacuum')
    con.close()
    print(f'{len(changes)} of {len(rows)} labels rewritten; prepositions now: '
          f'{after.most_common(3)}')


if __name__ == '__main__':
    main()
