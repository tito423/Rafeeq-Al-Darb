import os
import json
import uuid

catalog_path = r'E:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\books\data\books_catalog.json'

def load_catalog():
    if os.path.exists(catalog_path):
        with open(catalog_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return []

def save_catalog(catalog):
    with open(catalog_path, 'w', encoding='utf-8') as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)

def main():
    catalog = load_catalog()
    existing_paths = {b.get('download_url') for b in catalog if b.get('format') == 'pdf'}
    
    mybooks_dir = r'E:\MyBooks'
    
    new_books = []
    
    # Process main folders
    if os.path.exists(mybooks_dir):
        for item in os.listdir(mybooks_dir):
            item_path = os.path.join(mybooks_dir, item)
            if os.path.isdir(item_path) and item != "New folder":
                book_title = item
                # Find all pdfs in this folder
                pdfs = [f for f in os.listdir(item_path) if f.lower().endswith('.pdf')]
                if pdfs:
                    for pdf in pdfs:
                        pdf_path = os.path.join(item_path, pdf)
                        # Normalize path separators
                        pdf_path = pdf_path.replace('\\', '/')
                        if pdf_path not in existing_paths:
                            title = book_title
                            if len(pdfs) > 1:
                                title += f" - {pdf}"
                            new_books.append({
                                "id": str(uuid.uuid4())[:8],
                                "title": title,
                                "author": "غير معروف",
                                "category": "مكتبتي",
                                "format": "pdf",
                                "download_url": pdf_path,
                            })
                            existing_paths.add(pdf_path)

    # Process New folder
    new_folder = os.path.join(mybooks_dir, 'New folder')
    if os.path.exists(new_folder):
        for f in os.listdir(new_folder):
            if f.lower().endswith('.pdf'):
                pdf_path = os.path.join(new_folder, f)
                pdf_path = pdf_path.replace('\\', '/')
                if pdf_path not in existing_paths:
                    title = f.replace('.pdf', '')
                    if title == 'ar_sayd_alkhatir':
                        title = 'صيد الخاطر'
                    new_books.append({
                        "id": str(uuid.uuid4())[:8],
                        "title": title,
                        "author": "غير معروف",
                        "category": "مكتبتي",
                        "format": "pdf",
                        "download_url": pdf_path,
                    })
                    existing_paths.add(pdf_path)
                    
    if new_books:
        catalog.extend(new_books)
        save_catalog(catalog)
        print(f"Added {len(new_books)} new books to catalog.")
    else:
        print("No new books found.")

if __name__ == '__main__':
    main()
