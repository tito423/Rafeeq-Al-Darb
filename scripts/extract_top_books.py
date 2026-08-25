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
    author_map = {row[0]: row[1] for row in c.fetchall()}
    
    # 2. Find books
    book_terms = ["منهاج القاصدين", "التذكرة", "أكاديمية زاد", "الروح", "الجواب الكافي", "زاد المعاد", "إغاثة اللهفان", "بر الوالدين"]
    book_conds = [f"book_name LIKE '%{t}%'" for t in book_terms]
    
    if author_map:
        author_ids = ",".join(map(str, author_map.keys()))
        book_conds.append(f"main_author IN ({author_ids})")
        
    c.execute(f"SELECT book_id, book_name, main_author, book_category FROM book WHERE {' OR '.join(book_conds)} LIMIT 20")
    
    matching_books = []
    for row in c.fetchall():
        book_id, title, auth_id, cat_id = row
        author_name = author_map.get(auth_id, "Unknown")
        folder = str(book_id).zfill(3)[-3:]
        path = rf'E:\shamela\database\book\{folder}\{book_id}.db'
        
        if os.path.exists(path):
            matching_books.append({
                "id": book_id,
                "title": title,
                "author": author_name,
                "category_id": cat_id,
                "db_path": path
            })
            
    print(f"Found actual DB files for {len(matching_books)} books.")
    
    # Extract them
    assets_dir = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\books"
    os.makedirs(assets_dir, exist_ok=True)
    
    extracted_books = []
    for b in matching_books:
        print(f"Extracting {b['title']}...")
        try:
            b_conn = sqlite3.connect(b['db_path'])
            b_c = b_conn.cursor()
            
            # Fetch all pages
            b_c.execute("SELECT part FROM page ORDER BY id ASC")
            pages = b_c.fetchall()
            
            chapters = []
            page_num = 1
            for page_row in pages:
                text = page_row[0]
                if text and text.strip():
                    chapters.append({
                        "title": f"صفحة {page_num}",
                        "content": text.strip()
                    })
                    page_num += 1
            
            b_conn.close()
            
            if chapters:
                book_data = {
                    "id": f"shamela_{b['id']}",
                    "title": b['title'],
                    "author": b['author'],
                    "chapters": chapters
                }
                out_path = os.path.join(assets_dir, f"shamela_{b['id']}.json")
                with open(out_path, 'w', encoding='utf-8') as f:
                    json.dump(book_data, f, ensure_ascii=False, indent=2)
                    
                extracted_books.append({
                    "id": f"shamela_{b['id']}",
                    "title": b['title'],
                    "author": b['author'],
                    "category": "إسلاميات",
                    "format": "text",
                    "download_url": f"assets/books/shamela_{b['id']}.json"
                })
                print(f"  -> Extracted {len(chapters)} pages.")
        except Exception as e:
            print(f"  -> Error: {e}")
            
    print(f"Successfully extracted {len(extracted_books)} books.")
    
    # Update catalog
    catalog_path = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\books\data\books_catalog.json"
    if os.path.exists(catalog_path):
        with open(catalog_path, 'r', encoding='utf-8') as f:
            catalog = json.load(f)
            
        # Add new books
        existing_ids = {b['id'] for b in catalog}
        for b in extracted_books:
            if b['id'] not in existing_ids:
                catalog.insert(0, b)
                
        with open(catalog_path, 'w', encoding='utf-8') as f:
            json.dump(catalog, f, ensure_ascii=False, indent=2)
        print("Updated books_catalog.json")

if __name__ == '__main__':
    extract_books()
