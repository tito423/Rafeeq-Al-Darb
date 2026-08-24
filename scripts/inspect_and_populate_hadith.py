import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect('assets/data/hadith.db')
c = conn.cursor()

c.execute("SELECT DISTINCT book_id, COUNT(*) FROM hadiths GROUP BY book_id ORDER BY book_id;")
rows = c.fetchall()
print("Hadith Books & Counts:")
for r in rows:
    print(f"  Book ID {r[0]}: {r[1]} hadiths")

# Check if hadith numbers are sequential
c.execute("SELECT id, book_id, hadith_number, text FROM hadiths WHERE book_id=1 ORDER BY id LIMIT 10;")
print("\nFirst 10 Hadiths for Book 1:")
for r in c.fetchall():
    print(f"  ID {r[0]} | Hadith #{r[2]} | {r[3][:60]}...")

conn.close()
