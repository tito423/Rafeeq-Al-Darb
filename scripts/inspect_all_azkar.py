import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/quran_local.db')
cursor = conn.cursor()

print("--- AZKAR CATEGORIES ---")
categories = cursor.execute("SELECT DISTINCT category FROM azkar;").fetchall()
for cat in categories:
    cat_name = cat[0]
    print(f"\nCategory: {cat_name}")
    rows = cursor.execute("SELECT id, content, description, reference, fadl FROM azkar WHERE category=? LIMIT 5;", (cat_name,)).fetchall()
    for r in rows:
        print(f"  [id={r[0]}] content: {r[1]}")
        if r[2]: print(f"        desc: {r[2]}")
        if r[3]: print(f"        ref: {r[3]}")
        if r[4]: print(f"        fadl: {r[4]}")

print("\n--- CHECKING FOR BRACKETS / PUNCTUATION IN AZKAR ---")
all_azkar = cursor.execute("SELECT id, category, content, description, reference, fadl FROM azkar;").fetchall()
dirty_count = 0
for r in all_azkar:
    has_issue = False
    for text in [r[2], r[3], r[4], r[5]]:
        if not text: continue
        if '((' in text or '))' in text or "','" in text or ',"' in text or '",' in text or "\\n" in text or "''" in text or "nN" in text:
            has_issue = True
    if has_issue:
        dirty_count += 1
        print(f"Dirty [id={r[0]}, cat={r[1]}]:")
        print(f"   content: {repr(r[2])}")
        if r[3]: print(f"   desc: {repr(r[3])}")
        if r[4]: print(f"   ref: {repr(r[4])}")
        if r[5]: print(f"   fadl: {repr(r[5])}")

print(f"Total dirty azkar rows found: {dirty_count} out of {len(all_azkar)}")

conn.close()
