import sqlite3
import json

def get_shamela_books():
    conn = sqlite3.connect(r'E:\shamela\database\master.db')
    conn.text_factory = bytes
    c = conn.cursor()
    c.execute("SELECT book_id, book_name FROM book")
    
    matches = []
    for row in c.fetchall():
        book_id = row[0]
        try:
            name = row[1].decode('utf-8')
        except:
            try:
                name = row[1].decode('windows-1256')
            except:
                name = ""
                
        # Search criteria
        if any(x in name for x in ['صيد الخاطر', 'أكاديمية', 'زاد', 'التذكرة', 'الرقائق', 'الزهد', 'منهاج القاصدين', 'الترمذي الحكيم']):
            matches.append({"id": book_id, "name": name})
            
    with open('shamela_search_results.json', 'w', encoding='utf-8') as f:
        json.dump(matches, f, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    get_shamela_books()
