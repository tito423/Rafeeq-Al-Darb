"""Rewrite only `tafseer_texts` in the shipped `quran_sciences.db`.

The full `build_sciences_db.py` recreates the database from scratch, and
the shipped pack also holds tables other scripts added later (`irab_daas`,
`irab_daas_refs`, translations). This touches nothing but the tafsir rows:
it re-derives every passage's ayah range from the cached api.quran.com JSON
with `tafsir_ranges.ranges` (key = FIRST ayah of the group) and proves,
before committing, that

  * every other table keeps its exact row count,
  * the multiset of (source, surah, text) is unchanged except that the
    empty inner-group entries stay dropped - only ranges move,
  * the confirmed sources cover every ayah exactly once, the unconfirmed
    ones (tafsir_ranges.UNCONFIRMED) at most once.

    py -3 scripts/fix_tafsir_ranges.py          # dry run: report only
    py -3 scripts/fix_tafsir_ranges.py --write  # rewrite the table
"""
import collections
import html
import json
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tafsir_ranges  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_sciences.db')
LOCAL = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db')
CACHE = os.path.join(ROOT, 'scripts', 'temp_phase1', 'tafsir_complete')
SOURCES = ['muyassar', 'ibn_kathir', 'qurtubi', 'tabari', 'sadi',
           'baghawi', 'tantawi']


def clean_html(t):  # identical to build_sciences_db.clean_html
    t = re.sub(r"<[^>]+>", " ", t)
    t = html.unescape(t)
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\n\s*\n+", "\n", t)
    return t.strip()


def main():
    write = '--write' in sys.argv
    q = sqlite3.connect(LOCAL)
    count = dict(q.execute('SELECT id, ayahs_count FROM surahs'))
    texts = {}
    for s_, a_, t_ in q.execute(
            'SELECT surah_id, ayah_number, text_clean FROM ayahs'):
        texts.setdefault(s_, {})[a_] = t_
    q.close()
    assert len(count) == 114 and sum(count.values()) == 6236

    con = sqlite3.connect(DB)
    tables = [r[0] for r in con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%'")]
    before = {t: con.execute('SELECT COUNT(*) FROM "%s"' % t).fetchone()[0]
              for t in tables}
    old_texts = collections.Counter(con.execute(
        'SELECT source, surah, text FROM tafseer_texts'))

    new_rows = []
    for src in SOURCES:
        for ch in range(1, 115):
            items = json.load(open(os.path.join(CACHE, src, 'ch%d.json' % ch),
                                   encoding='utf-8'))
            kt = []
            for it in items:
                s, a = (int(x) for x in it['verse_key'].split(':'))
                assert s == ch
                kt.append((a, clean_html(it.get('text') or '')))
            at = texts[ch] if src in tafsir_ranges.UNCONFIRMED else None
            for lo, hi, t in tafsir_ranges.ranges(
                    kt, count[ch], at, tafsir_ranges.covered_for(src, ch)):
                new_rows.append((src, ch, lo, hi, t))

    new_texts = collections.Counter((s, c, t) for s, c, _, _, t in new_rows)
    if new_texts != old_texts:
        print('TEXT MISMATCH: only ranges may change')
        print(' only old:', sum((old_texts - new_texts).values()),
              ' only new:', sum((new_texts - old_texts).values()))
        return 1

    cover = collections.Counter()
    for s, c, lo, hi, _ in new_rows:
        for a in range(lo, hi + 1):
            cover[(s, c, a)] += 1
    uncovered = collections.Counter()
    for src in SOURCES:
        for ch in range(1, 115):
            for a in range(1, count[ch] + 1):
                k = cover[(src, ch, a)]
                if k == 0 and src in tafsir_ranges.UNCONFIRMED:
                    uncovered[src] += 1
                elif k != 1:
                    print('coverage %s %d:%d = %d' % (src, ch, a, k))
                    return 1

    old = {}
    for s, c, lo, hi, t in con.execute(
            'SELECT source, surah, ayah_start, ayah_end, text '
            'FROM tafseer_texts'):
        for a in range(lo, hi + 1):
            old[(s, c, a)] = t
    changed = collections.Counter()
    for s, c, lo, hi, t in new_rows:
        for a in range(lo, hi + 1):
            if old.get((s, c, a)) != t:
                changed[s] += 1
    print('rows: %d -> %d' % (before['tafseer_texts'], len(new_rows)))
    print('ayahs whose passage changes:', dict(changed))
    print('confirmed sources cover all 6236 ayahs exactly once; '
          'unquoted gap ayahs left empty:', dict(uncovered))

    if not write:
        print('dry run - nothing written (pass --write)')
        return 0
    with con:
        con.execute('DELETE FROM tafseer_texts')
        con.executemany(
            'INSERT INTO tafseer_texts(source, surah, ayah_start, ayah_end, '
            'text) VALUES (?,?,?,?,?)', new_rows)
    after = {t: con.execute('SELECT COUNT(*) FROM "%s"' % t).fetchone()[0]
             for t in tables}
    for t in tables:
        if t != 'tafseer_texts' and after[t] != before[t]:
            print('TABLE CHANGED', t, before[t], after[t])
            return 1
    con.execute('VACUUM')
    con.close()
    print('written; other tables unchanged:',
          {t: after[t] for t in tables if t != 'tafseer_texts'})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
