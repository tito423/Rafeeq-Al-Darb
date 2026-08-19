import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/quran_local.db')
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = c.fetchall()
for t in tables:
    tname = t[0]
    c.execute(f"PRAGMA table_info({tname})")
    cols = [col[1] for col in c.fetchall()]
    print(tname, cols)
    c.execute(f"SELECT * FROM {tname} LIMIT 2")
    for row in c.fetchall():
        print("  sample:", row)
