import sqlite3

conn = sqlite3.connect('assets/quran_local.db')
cur = conn.cursor()

print("--- Checking azkar by category and content ---")
cur.execute("SELECT category, content, count(*) as c FROM azkar GROUP BY category, content HAVING c > 1")
rows = cur.fetchall()
print(f"Duplicates in (category, content): {len(rows)}")
for r in rows:
    print("Dup:", r[0], r[1][:40], "count:", r[2])

print("\n--- Checking azkar content regardless of category ---")
cur.execute("SELECT content, count(*) as c FROM azkar GROUP BY content HAVING c > 1")
rows2 = cur.fetchall()
print(f"Duplicates in content across categories: {len(rows2)}")
for r in rows2[:5]:
    print("Shared content:", r[0][:50], "count:", r[1])

print("\n--- Checking categories ---")
cur.execute("SELECT category, count(*) FROM azkar GROUP BY category")
for r in cur.fetchall():
    print(r)

conn.close()
