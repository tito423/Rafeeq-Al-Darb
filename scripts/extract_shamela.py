import sqlite3
import json
import os
import asyncio
import aiohttp
from bs4 import BeautifulSoup

# This script extracts book metadata locally from Shamela v4 SQLite database
# and fetches the text concurrently from shamela.ws to bypass local Lucene encryption.
# It formats the output into a clean JSON file divided by chapters/pages.

SHAMELA_MASTER_DB = r"E:\shamela\database\master.db"
OUTPUT_DIR = r"assets\data\books"

def get_book_metadata(book_id):
    if not os.path.exists(SHAMELA_MASTER_DB):
        return {"id": book_id, "title": f"كتاب {book_id}", "author": "غير معروف"}
        
    conn = sqlite3.connect(SHAMELA_MASTER_DB)
    c = conn.cursor()
    c.execute("SELECT book_name, main_author FROM book WHERE book_id = ?", (book_id,))
    row = c.fetchone()
    
    if row:
        title, author_id = row
        author_name = "غير معروف"
        if author_id:
            c.execute("SELECT author_name FROM author WHERE author_id = ?", (author_id,))
            a_row = c.fetchone()
            if a_row: author_name = a_row[0]
            
        return {"id": book_id, "title": title, "author": author_name}
    return {"id": book_id, "title": f"كتاب {book_id}", "author": "غير معروف"}

async def fetch_page(session, book_id, page):
    url = f"https://shamela.ws/book/{book_id}/{page}"
    try:
        async with session.get(url, headers={'User-Agent': 'Mozilla/5.0'}) as response:
            if response.status == 200:
                html = await response.text()
                soup = BeautifulSoup(html, 'html.parser')
                nass_div = soup.find('div', class_='nass')
                if nass_div:
                    return page, nass_div.get_text(separator='\n', strip=True)
    except Exception as e:
        pass
    return page, None

async def extract_book(book_id, max_pages=50):
    metadata = get_book_metadata(book_id)
    print(f"Extracting: {metadata['title']} (Author: {metadata['author']})")
    
    chapters = []
    
    # Fetch concurrently for speed
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_page(session, book_id, p) for p in range(1, max_pages + 1)]
        results = await asyncio.gather(*tasks)
        
        # Sort by page number
        results.sort(key=lambda x: x[0])
        
        for page, text in results:
            if text:
                chapters.append({
                    "title": f"الصفحة {page}",
                    "content": text
                })
                
    metadata["chapters"] = chapters
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"shamela_{book_id}.json")
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)
        
    print(f"Saved {len(chapters)} pages to {out_path}")

if __name__ == '__main__':
    # Extract example books (e.g., Ar-Rouh by Ibn Qayyim is 390)
    asyncio.run(extract_book(390, max_pages=15))
    print("Extraction complete!")
