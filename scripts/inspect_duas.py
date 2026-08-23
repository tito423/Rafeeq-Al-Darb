import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/quran_local.db')
cursor = conn.cursor()

rows = cursor.execute("SELECT id, content, description, reference, fadl FROM azkar WHERE category='دعاء' LIMIT 20;").fetchall()
for r in rows:
    print(f"\n--- [id={r[0]}] ---")
    print(f"content: {repr(r[1])}")
    print(f"desc: {repr(r[2])}")
    print(f"ref: {repr(r[3])}")
    print(f"fadl: {repr(r[4])}")

conn.close()
