import sqlite3
import os

quran_db_path = 'assets/quran_local.db'
hadith_db_path = 'assets/data/hadith.db'

print(f"=== Inspecting {quran_db_path} ===")
if os.path.exists(quran_db_path):
    conn = sqlite3.connect(quran_db_path)
    c = conn.cursor()
    c.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in c.fetchall()]
    print("Tables in quran_local.db:", tables)
    for t in tables:
        c.execute(f"PRAGMA table_info({t});")
        cols = [col[1] for col in c.fetchall()]
        c.execute(f"SELECT COUNT(*) FROM {t};")
        cnt = c.fetchone()[0]
        print(f"  Table '{t}' ({cnt} rows): {cols}")
    conn.close()

print(f"\n=== Inspecting {hadith_db_path} ===")
if os.path.exists(hadith_db_path):
    conn = sqlite3.connect(hadith_db_path)
    c = conn.cursor()
    c.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in c.fetchall()]
    print("Tables in hadith.db:", tables)
    for t in tables:
        c.execute(f"PRAGMA table_info({t});")
        cols = [col[1] for col in c.fetchall()]
        c.execute(f"SELECT COUNT(*) FROM {t};")
        cnt = c.fetchone()[0]
        print(f"  Table '{t}' ({cnt} rows): {cols}")
    conn.close()
