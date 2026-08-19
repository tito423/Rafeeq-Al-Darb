import urllib.request
import json
import sqlite3
import os
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

DB_PATH = 'assets/quran_local.db'

def main():
    print("Starting Azkar DB population...")
    
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    c.execute('''
        CREATE TABLE IF NOT EXISTS azkar (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT,
            count TEXT,
            description TEXT,
            reference TEXT,
            content TEXT
        )
    ''')
    
    # We will fetch Hisn al-Muslim (Azkar) from an open source JSON repository
    url = "https://cdn.jsdelivr.net/gh/nawafalqari/azkar-api@56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    
    try:
        response = urllib.request.urlopen(req, context=ctx)
        data = json.loads(response.read().decode('utf-8'))
        
        c.execute("DELETE FROM azkar") # Clear old azkar if any
        
        for category, azkar_list_of_lists in data.items():
            for azkar_list in azkar_list_of_lists:
                if isinstance(azkar_list, list):
                    for zikr in azkar_list:
                        c.execute('''
                            INSERT INTO azkar (category, count, description, reference, content)
                            VALUES (?, ?, ?, ?, ?)
                        ''', (
                            category,
                            zikr.get('count', '1'),
                            zikr.get('description', ''),
                            zikr.get('reference', ''),
                            zikr.get('content', zikr.get('text', ''))
                        ))
                elif isinstance(azkar_list, dict):
                    zikr = azkar_list
                    c.execute('''
                        INSERT INTO azkar (category, count, description, reference, content)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (
                        category,
                        zikr.get('count', '1'),
                        zikr.get('description', ''),
                        zikr.get('reference', ''),
                        zikr.get('content', zikr.get('text', ''))
                    ))
        
        conn.commit()
        
        c.execute("SELECT COUNT(*) FROM azkar")
        count = c.fetchone()[0]
        print(f"Success! Inserted {count} azkar items.")
        
    except Exception as e:
        print(f"Failed to fetch or parse Azkar: {e}")
    
    conn.close()

if __name__ == '__main__':
    main()
