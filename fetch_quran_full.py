import urllib.request
import json
import sqlite3
import os
import ssl

# Create unverified SSL context to bypass corporate proxy / cert issues
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

DB_PATH = 'assets/quran_local.db'

def create_db():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS ayahs (
            id INTEGER PRIMARY KEY,
            surah_number INTEGER,
            ayah_in_surah INTEGER,
            text_uthmani TEXT,
            tafsir TEXT,
            translation TEXT,
            irab TEXT,
            asbab TEXT
        )
    ''')
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS surahs (
            id INTEGER PRIMARY KEY,
            name TEXT,
            english_name TEXT,
            revelation_type TEXT,
            number_of_ayahs INTEGER
        )
    ''')
    
    conn.commit()
    return conn

def fetch_edition(edition):
    print(f"Fetching {edition}...")
    url = f"http://api.alquran.cloud/v1/quran/{edition}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        response = urllib.request.urlopen(req, context=ctx)
        data = json.loads(response.read().decode('utf-8'))
        return data['data']['surahs']
    except Exception as e:
        print(f"Failed to fetch {edition}: {e}")
        return None

def main():
    print("Starting full DB population...")
    conn = create_db()
    c = conn.cursor()
    
    quran_data = fetch_edition('quran-uthmani')
    tafsir_data = fetch_edition('ar.muyassar')
    translation_data = fetch_edition('en.asad')
    
    if not quran_data:
        print("Quran fetch failed. Exiting.")
        return

    print("Inserting data into SQLite...")
    
    for s_idx, surah in enumerate(quran_data):
        c.execute('''
            INSERT INTO surahs (id, name, english_name, revelation_type, number_of_ayahs)
            VALUES (?, ?, ?, ?, ?)
        ''', (
            surah['number'],
            surah['name'],
            surah['englishName'],
            surah['revelationType'],
            len(surah['ayahs'])
        ))
        
        for a_idx, ayah in enumerate(surah['ayahs']):
            t_ayah = tafsir_data[s_idx]['ayahs'][a_idx] if tafsir_data else None
            tr_ayah = translation_data[s_idx]['ayahs'][a_idx] if translation_data else None
            
            tafsir_text = t_ayah['text'] if t_ayah else ""
            translation_text = tr_ayah['text'] if tr_ayah else ""
            
            c.execute('''
                INSERT INTO ayahs (id, surah_number, ayah_in_surah, text_uthmani, tafsir, translation, irab, asbab)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                ayah['number'],
                surah['number'],
                ayah['numberInSurah'],
                ayah['text'],
                tafsir_text,
                translation_text,
                "إعراب هذه الآية غير متوفر في النسخة الحالية.",
                "أسباب النزول غير متوفرة لهذه الآية."
            ))
    
    conn.commit()
    
    c.execute("SELECT COUNT(*) FROM ayahs")
    ayah_count = c.fetchone()[0]
    
    conn.close()
    print(f"Success! DB populated with {ayah_count} ayahs.")

if __name__ == '__main__':
    main()
