import json
import os
import sqlite3
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

# ── 1. Clean Hadith Books ───────────────────────────────────────────────────
hadith_dir = 'assets/data/hadith'
books = ['bukhari', 'muslim', 'abudawud', 'tirmidhi', 'nasai', 'ibnmajah']

print("=== Cleaning Hadith Books ===")
for b in books:
    path = os.path.join(hadith_dir, f'{b}.json')
    if not os.path.exists(path):
        print(f"Skipping {b}, file not found")
        continue

    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    hadiths = data.get('hadiths', [])
    initial_count = len(hadiths)
    
    # Filter out empty or whitespace-only hadiths
    cleaned_hadiths = []
    for h in hadiths:
        text = h.get('text', '') or h.get('arab', '') or h.get('hadith', '') or ''
        text = text.strip()
        if text:
            # Ensure 'text' field is populated and trimmed
            h['text'] = text
            cleaned_hadiths.append(h)

    removed = initial_count - len(cleaned_hadiths)
    data['hadiths'] = cleaned_hadiths
    data['metadata']['length'] = len(cleaned_hadiths)
    
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"✓ {b}: Total: {len(cleaned_hadiths)} (Removed {removed} empty entries)")

# ── 2. Clean Azkar Duplicates in SQLite ──────────────────────────────────────
print("\n=== Cleaning Azkar Duplicates in SQLite ===")
db_path = 'assets/quran_local.db'
conn = sqlite3.connect(db_path)
c = conn.cursor()

def normalize_text(text):
    if not text:
        return ""
    text = re.sub(r'[\u064B-\u065F\u0670\u0640]', '', text)
    text = text.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا').replace('ى', 'ي').replace('ة', 'ه')
    text = re.sub(r'[\(\)\[\]«».,،:;\-!؟"\'`]', '', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

c.execute("SELECT id, category, content, count, description, reference, fadl FROM azkar ORDER BY id")
rows = c.fetchall()
print(f"Initial Azkar count: {len(rows)}")

seen_by_cat = {}
ids_to_delete = []

for r in rows:
    zid, cat, content, cnt, desc, ref, fadl = r
    norm = normalize_text(content)
    key = (cat, norm)
    if key in seen_by_cat:
        ids_to_delete.append(zid)
    else:
        seen_by_cat[key] = zid

if ids_to_delete:
    print(f"Found {len(ids_to_delete)} duplicate Azkar IDs to delete: {ids_to_delete}")
    for did in ids_to_delete:
        c.execute("DELETE FROM azkar WHERE id = ?", (did,))
    conn.commit()
else:
    print("No exact or normalized duplicates found in azkar table.")

c.execute("SELECT count(*) FROM azkar")
print(f"Final Azkar count: {c.fetchone()[0]}")
conn.close()
