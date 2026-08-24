import sqlite3

conn = sqlite3.connect('assets/quran_local.db')
c = conn.cursor()

for col in ['tafsir', 'tafsir_jalalayn', 'translation', 'word_meanings', 'irab', 'asbab']:
    c.execute(f"SELECT COUNT(*) FROM ayahs WHERE {col} IS NOT NULL AND trim({col}) != '';")
    count = c.fetchone()[0]
    print(f"{col}: {count}/6236 non-empty rows")

# Sample rows
print("\n--- Sample Ayah 1:1 ---")
c.execute("SELECT surah_number, ayah_in_surah, text_uthmani, word_meanings, irab, asbab, translation FROM ayahs WHERE surah_number=1 AND ayah_in_surah=1;")
print(c.fetchone())

print("\n--- Sample Ayah 2:1 ---")
c.execute("SELECT surah_number, ayah_in_surah, text_uthmani, word_meanings, irab, asbab, translation FROM ayahs WHERE surah_number=2 AND ayah_in_surah=1;")
print(c.fetchone())

conn.close()
