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
    # P2‑8 #9 (2026‑09‑03) — es/ru/pt added so Rafiq's own es/ru/pt UI
    # locales get a Quran translation in their own language too (previously
    # only en/fr/ur existed, so an es/ru/pt-reading user had none). Same
    # trusted alquran.cloud source, one edition per language chosen for
    # being the standard/most-used scholarly translation in that language:
    # Kuliev for Russian (the most widely used Russian Quran translation
    # among Muslims), Cortés for Spanish (a standard academic reference
    # translation), El-Hayek for Portuguese (the only major one on
    # alquran.cloud, long-standing standard Portuguese translation).
    ('es', 'es.cortes',  'Julio Cortés',  'translation_es.cortes.json'),
    ('ru', 'ru.kuliev',  'Эльмир Кулиев (Elmir Kuliev)', 'translation_ru.kuliev.json'),
    ('pt', 'pt.elhayek', 'Samir El-Hayek', 'translation_pt.elhayek.json'),
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

# Commit the real ingestion before the maintenance step below, so a bug in
# that unrelated cleanup can never roll back a whole run's worth of real
# translation rows again (exactly what happened 2026‑09‑03).
con.commit()

# ayah_sciences was created empty by an earlier run and duplicated
# tafseer_texts; dropped once already, so this is a no-op on every run
# since (real bug caught 2026‑09‑03: an unconditional SELECT here crashed
# with "no such table" on a second run and rolled back that whole run's
# inserts, since it ran before the commit below).
cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='ayah_sciences'")
if cur.fetchone():
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
