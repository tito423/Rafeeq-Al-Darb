import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/data/hadith.db')
c = conn.cursor()

books = ['bukhari', 'muslim', 'tirmidhi', 'abudawud', 'nasai', 'ibnmajah', 'malik', 'nawawi', 'qudsi']

for b in books:
    c.execute("SELECT id, hadith_number, text FROM hadiths WHERE book_id=? ORDER BY id ASC;", (b,))
    rows = c.fetchall()
    print(f"Fixing book '{b}' ({len(rows)} hadiths)...")
    for idx, r in enumerate(rows, 1):
        hadith_id = r[0]
        text = r[2] or ''
        # Clean text
        cleaned_text = text.replace('((', '«').replace('))', '»').strip()
        while cleaned_text.startswith("'") or cleaned_text.startswith('"') or cleaned_text.startswith(','):
            cleaned_text = cleaned_text[1:].strip()
        while cleaned_text.endswith("'") or cleaned_text.endswith('"') or cleaned_text.endswith(','):
            cleaned_text = cleaned_text[:-1].strip()

        c.execute("UPDATE hadiths SET hadith_number=?, text=? WHERE id=?;", (idx, cleaned_text, hadith_id))

conn.commit()
print("All hadith numbering sequenced sequentially from 1 to N without any gaps!")
conn.close()
