import sqlite3
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

def remove_tashkeel(text):
    if not text:
        return ""
    text = re.sub(r'[\u064B-\u065F\u0670\u0640]', '', text)
    text = text.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا').replace('ى', 'ي').replace('ة', 'ه')
    text = re.sub(r'\s+', ' ', text).strip()
    return text

conn = sqlite3.connect('assets/quran_local.db')
c = conn.cursor()
c.execute("SELECT id, category, content, count, description FROM azkar")
rows = c.fetchall()

seen = {}
duplicates = []

for r in rows:
    zid, cat, content, cnt, desc = r
    clean = remove_tashkeel(content)
    # Check key (category, clean)
    key = (cat, clean)
    if key in seen:
        duplicates.append((zid, cat, content, seen[key]))
    else:
        seen[key] = (zid, content)

print(f"Total azkar: {len(rows)}")
print(f"Found {len(duplicates)} duplicates within same category:")
for d in duplicates:
    print(f"Duplicate ID {d[0]} in cat '{d[1]}' matches ID {d[3][0]}:")
    print(f"  New: {d[2][:70]}")
    print(f"  Old: {d[3][1][:70]}")

# Also check cross-category
seen_global = {}
cross_dups = []
for r in rows:
    zid, cat, content, cnt, desc = r
    clean = remove_tashkeel(content)
    if clean in seen_global:
        cross_dups.append((zid, cat, content, seen_global[clean]))
    else:
        seen_global[clean] = (zid, cat, content)

print(f"\nFound {len(cross_dups)} cross-category duplicates:")
for cd in cross_dups[:10]:
    print(f"ID {cd[0]} ('{cd[1]}') matches ID {cd[3][0]} ('{cd[3][1]}'): {cd[2][:50]}")
