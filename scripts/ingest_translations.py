#!/usr/bin/env python3
"""
Fold the bundled ayah translations into quran_sciences.db.

The three translation files shipped in assets/data/quran_text/ were dead
weight: ~11 MB inside the APK that no code ever read. Moving them into the
sciences database makes them queryable per ayah (one indexed lookup instead of
decoding a 2.5 MB JSON at runtime) and lets the raw assets be dropped.

Editions are the alquran.cloud text editions already vendored in the repo.
"""
import json, os, sqlite3, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB   = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_sciences.db')
SRC  = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_text')

EDITIONS = [
    ('en', 'en.sahih',      'Saheeh International', 'translation_en.sahih.json'),
    ('fr', 'fr.hamidullah', 'Muhammad Hamidullah',  'translation_fr.hamidullah.json'),
    ('ur', 'ur.jalandhry',  'Fateh Muhammad Jalandhry', 'translation_ur.jalandhry.json'),
]

con = sqlite3.connect(DB)
cur = con.cursor()
cur.executescript("""
CREATE TABLE IF NOT EXISTS translations (
  surah   INTEGER NOT NULL,
  ayah    INTEGER NOT NULL,
  lang    TEXT    NOT NULL,
  edition TEXT    NOT NULL,
  text    TEXT    NOT NULL,
  PRIMARY KEY (surah, ayah, lang)
);
CREATE INDEX IF NOT EXISTS idx_translations_ayah ON translations(surah, ayah);

CREATE TABLE IF NOT EXISTS translation_editions (
  lang    TEXT PRIMARY KEY,
  edition TEXT NOT NULL,
  name    TEXT NOT NULL
);
""")

total = 0
for lang, edition, name, fname in EDITIONS:
    path = os.path.join(SRC, fname)
    if not os.path.exists(path):
        print('!! missing', fname, file=sys.stderr)
        continue
    doc = json.load(open(path, encoding='utf-8'))
    rows = []
    for surah in doc['data']['surahs']:
        s = int(surah['number'])
        for a in surah['ayahs']:
            txt = (a['text'] or '').strip()
            if txt:
                rows.append((s, int(a['numberInSurah']), lang, edition, txt))
    cur.executemany(
        'INSERT OR REPLACE INTO translations(surah,ayah,lang,edition,text)'
        ' VALUES (?,?,?,?,?)', rows)
    cur.execute('INSERT OR REPLACE INTO translation_editions VALUES (?,?,?)',
                (lang, edition, name))
    print('%-3s %-16s %5d ayahs' % (lang, edition, len(rows)))
    total += len(rows)

# ayah_sciences was created empty by an earlier run and duplicates
# tafseer_texts; drop it so the schema has one obvious source of truth.
cur.execute("SELECT COUNT(*) FROM ayah_sciences")
if cur.fetchone()[0] == 0:
    cur.execute("DROP TABLE ayah_sciences")
    print('dropped empty placeholder table ayah_sciences')

con.commit()
cur.execute('VACUUM')
con.commit()

print('\ntotal translation rows:', total)
for lang, in con.execute('SELECT DISTINCT lang FROM translations ORDER BY lang'):
    n = con.execute('SELECT COUNT(*) FROM translations WHERE lang=?', (lang,)).fetchone()[0]
    print('  %s: %d' % (lang, n))
con.close()
print('db size: %.1f MB' % (os.path.getsize(DB) / 1048576))
