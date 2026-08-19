import sqlite3
conn = sqlite3.connect('assets/quran_local.db')
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = c.fetchall()
print('Tables:', tables)
for (table,) in tables:
    c.execute(f"SELECT COUNT(*) FROM {table}")
    count = c.fetchone()[0]
    print(f'  {table}: {count} rows')
    c.execute(f"PRAGMA table_info({table})")
    cols = c.fetchall()
    print(f'  Columns: {[col[1] for col in cols]}')
# Sample ayah data
c.execute("SELECT id, surah_number, ayah_in_surah, text_uthmani, tafsir, translation, irab, asbab FROM ayahs LIMIT 2")
rows = c.fetchall()
for row in rows:
    print('Sample ayah:', row[:4], '| tafsir len:', len(row[4] or ''), '| trans len:', len(row[5] or ''), '| irab len:', len(row[6] or ''), '| asbab len:', len(row[7] or ''))
conn.close()
