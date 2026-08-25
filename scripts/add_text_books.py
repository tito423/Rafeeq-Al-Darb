import json
import os

catalog_path = r"e:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\books\data\books_catalog.json"

with open(catalog_path, 'r', encoding='utf-8') as f:
    catalog = json.load(f)

new_books = [
    {
        "id": "shamela_12209",
        "title": "صيد الخاطر",
        "author": "ابن الجوزي",
        "category": "مكتبتي الخاصة",
        "format": "text",
        "download_url": "assets/books/shamela_12209.json"
    },
    {
        "id": "shamela_8216",
        "title": "الزهد لابن أبي الدنيا",
        "author": "ابن أبي الدنيا",
        "category": "مكتبتي الخاصة",
        "format": "text",
        "download_url": "assets/books/shamela_8216.json"
    },
    {
        "id": "shamela_22551",
        "title": "الزهد والرقائق",
        "author": "الخطيب البغدادي",
        "category": "مكتبتي الخاصة",
        "format": "text",
        "download_url": "assets/books/shamela_22551.json"
    },
    {
        "id": "shamela_34493",
        "title": "نوادر الأصول",
        "author": "الحكيم الترمذي",
        "category": "مكتبتي الخاصة",
        "format": "text",
        "download_url": "assets/books/shamela_34493.json"
    },
    {
        "id": "shamela_12242",
        "title": "الرضا عن الله بقضائه",
        "author": "ابن أبي الدنيا",
        "category": "مكتبتي الخاصة",
        "format": "text",
        "download_url": "assets/books/shamela_12242.json"
    }
]

existing_ids = {book["id"] for book in catalog if "id" in book}

added = 0
for book in new_books:
    if book["id"] not in existing_ids:
        catalog.append(book)
        added += 1

if added > 0:
    with open(catalog_path, 'w', encoding='utf-8') as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print(f"Added {added} new text books to catalog.")
else:
    print("No new books added, they already exist.")
