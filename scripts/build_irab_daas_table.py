"""Put al-Da'as's i'rab into quran_sciences.db and take the Corpus labels out.

Owner, 2026-09-25: the i'rab is «إعراب القرآن الكريم» by al-Da'as, Hamidan
and al-Qasim; the Quranic Arabic Corpus word labels stay only if 100%
certain («لو منتش متأكد مليون المية متحطهومش»). They are not verified, so
`word_grammar` is dropped.

Tables:
  irab_daas(surah, ayah_from, ayah_to, text)
      one row per book section, the text of build_irab_daas_final.py
  irab_daas_refs(surah, ayah_from, at, target_surah, target_ayah_from, target_ayah)
      a «سبق إعرابها» the resolver PROVED (resolve_irab_daas_refs.py);
      `at` = character offset in the section text after which the app shows
      the target section's i'rab, labelled with `target_ayah`

Run after build_irab_daas_final.py and resolve_irab_daas_refs.py:
    py -3 scripts/build_irab_daas_table.py
"""
import io
import json
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
DB = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_sciences.db')


def build(db_path=DB):
    F = json.load(io.open(os.path.join(T, 'irab_daas_final.json'), encoding='utf-8'))
    R = json.load(io.open(os.path.join(T, 'irab_daas_refs.json'), encoding='utf-8'))
    text_of = {(r['surah'], r['ayah_from']): r['text'] for r in F}
    for x in R:                      # every offset must sit inside its section
        if not 0 < x['at'] <= len(text_of[(x['surah'], x['ayah_from'])]):
            sys.exit(f"bad offset {x}")
    db = sqlite3.connect(db_path)
    db.executescript('''
        DROP TABLE IF EXISTS word_grammar;
        DROP TABLE IF EXISTS irab_daas;
        DROP TABLE IF EXISTS irab_daas_refs;
        CREATE TABLE irab_daas(
          surah INTEGER NOT NULL, ayah_from INTEGER NOT NULL,
          ayah_to INTEGER NOT NULL, text TEXT NOT NULL,
          PRIMARY KEY(surah, ayah_from));
        CREATE TABLE irab_daas_refs(
          surah INTEGER NOT NULL, ayah_from INTEGER NOT NULL, at INTEGER NOT NULL,
          target_surah INTEGER NOT NULL, target_ayah_from INTEGER NOT NULL,
          target_ayah INTEGER NOT NULL);
        CREATE INDEX idx_irab_refs ON irab_daas_refs(surah, ayah_from);
    ''')
    db.executemany('INSERT INTO irab_daas VALUES(?,?,?,?)',
                   [(r['surah'], r['ayah_from'], r['ayah_to'], r['text']) for r in F])
    db.executemany('INSERT INTO irab_daas_refs VALUES(?,?,?,?,?,?)',
                   [(x['surah'], x['ayah_from'], x['at'], x['target_section'][0],
                     x['target_section'][1], x['target_ayah']) for x in R])
    db.commit()
    db.execute('VACUUM')
    n = db.execute('SELECT COUNT(*) FROM irab_daas').fetchone()[0]
    m = db.execute('SELECT COUNT(*) FROM irab_daas_refs').fetchone()[0]
    # every ayah of the mushaf falls in exactly one section
    cov = db.execute('SELECT SUM(ayah_to - ayah_from + 1) FROM irab_daas').fetchone()[0]
    db.close()
    print(f'irab_daas: {n} sections covering {cov} ayahs | irab_daas_refs: {m} | word_grammar dropped')
    if cov != 6236:
        sys.exit('sections do not cover the 6,236 ayahs exactly')


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else DB)
