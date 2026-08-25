import os
import json
import uuid

def add_pdfs_to_catalog():
    books_dir = r"E:\MyBooks"
    catalog_path = r"e:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\books\data\books_catalog.json"
    
    with open(catalog_path, 'r', encoding='utf-8') as f:
        catalog = json.load(f)
        
    existing_urls = {book.get("download_url") for book in catalog}
    
    new_books_count = 0
    for root, dirs, files in os.walk(books_dir):
        for file in files:
            if file.lower().endswith('.pdf'):
                pdf_path = os.path.join(root, file)
                
                if pdf_path in existing_urls:
                    continue
                    
                # Try to use the parent directory name as the title
                parent_dir = os.path.basename(root)
                # Fallback to filename if parent dir is just 'MyBooks'
                title = parent_dir if parent_dir != "MyBooks" else os.path.splitext(file)[0]
                
                # Cleanup the title if it has trailing dashes or weird chars
                title = title.replace('-', ' ').strip()
                if len(title) > 40:
                    title = title[:40] + "..."
                
                book = {
                    "id": f"local_pdf_{uuid.uuid4().hex[:8]}",
                    "title": title,
                    "author": "غير معروف",
                    "category": "مكتبتي الخاصة",
                    "format": "pdf",
                    "download_url": pdf_path
                }
                
                catalog.append(book)
                new_books_count += 1
                existing_urls.add(pdf_path)
                
    if new_books_count > 0:
        with open(catalog_path, 'w', encoding='utf-8') as f:
            json.dump(catalog, f, ensure_ascii=False, indent=2)
            
    print(f"Added {new_books_count} new PDF books to catalog.")

if __name__ == "__main__":
    add_pdfs_to_catalog()
