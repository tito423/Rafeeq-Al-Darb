import sqlite3
import json
import os

def extract_books():
    db_path = r'E:\shamela\database\master.db'
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    
    # 1. Find authors
    author_terms = ["ابن القيم", "ابن الجوزي", "القرطبي", "ابن أبي الدنيا", "الترمذي"]
    auth_conds = [f"author_name LIKE '%{t}%'" for t in author_terms]
    c.execute(f"SELECT author_id, author_name FROM author WHERE {' OR '.join(auth_conds)}")
    
    author_map = {}
    for row in c.fetchall():
        author_map[row[0]] = row[1]
    
    print(f"Found {len(author_map)} matching authors.")
    
    # 2. Find books
    book_terms = ["منهاج القاصدين", "التذكرة", "أكاديمية زاد", "الروح"]
    book_conds = [f"book_name LIKE '%{t}%'" for t in book_terms]
    
    if author_map:
        author_ids = ",".join(map(str, author_map.keys()))
        book_conds.append(f"main_author IN ({author_ids})")
        
    c.execute(f"SELECT book_id, book_name, main_author, book_category FROM book WHERE {' OR '.join(book_conds)}")
    
    matching_books = []
    for row in c.fetchall():
        book_id, title, auth_id, cat_id = row
        author_name = author_map.get(auth_id, "Unknown")
        matching_books.append({
            "id": book_id,
            "title": title,
            "author": author_name,
            "category_id": cat_id
        })
        
    print(f"Found {len(matching_books)} matching books.")
    
    # Check existence
    exists_count = 0
    for b in matching_books:
        folder = str(b['id'] // 1000).zfill(3)
        path = rf'E:\shamela\database\book\{folder}\{b["id"]}.db'
        if os.path.exists(path):
            exists_count += 1
            b['db_path'] = path
            
    print(f"Found actual DB files for {exists_count} books.")
    
    # Save the matched books to a JSON file for inspection
    with open('matched_shamela_books.json', 'w', encoding='utf-8') as f:
        json.dump(matching_books, f, ensure_ascii=False, indent=2)
        
    print("Saved to matched_shamela_books.json")
    conn.close()

if __name__ == '__main__':
    extract_books()
