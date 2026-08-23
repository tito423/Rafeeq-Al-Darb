import json
import sqlite3
import os
import glob

def main():
    db_path = 'assets/data/hadith.db'
    if os.path.exists(db_path):
        os.remove(db_path)
    
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS hadiths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id TEXT,
            hadith_number INTEGER,
            text TEXT
        )
    ''')
    
    c.execute('''CREATE INDEX idx_book_id ON hadiths(book_id)''')
    
    json_files = glob.glob('assets/data/hadith/*.json')
    for file in json_files:
        book_id = os.path.splitext(os.path.basename(file))[0]
        print(f"Processing {book_id}...")
        
        try:
            with open(file, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except json.JSONDecodeError:
            print(f"Skipping {book_id} because it is not valid JSON")
            continue
            
        hadiths = data.get('hadiths', [])
        
        records = []
        for i, h in enumerate(hadiths):
            text = h.get('text', '')
            num = h.get('hadithnumber', i + 1)
            records.append((book_id, num, text))
            
        c.executemany('''
            INSERT INTO hadiths (book_id, hadith_number, text) 
            VALUES (?, ?, ?)
        ''', records)
        
    conn.commit()
    conn.close()
    print("Done generating hadith.db!")

if __name__ == '__main__':
    main()
