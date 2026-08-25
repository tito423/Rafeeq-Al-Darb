import urllib.request
import ssl
from bs4 import BeautifulSoup
import json
import time
import os
import concurrent.futures

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def fetch_page(book_id, page_number, retries=3):
    url = f'https://shamela.ws/book/{book_id}/{page_number}'
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    for attempt in range(retries):
        try:
            response = urllib.request.urlopen(req, context=ctx, timeout=5)
            html = response.read().decode('utf-8')
            return html
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            time.sleep(1)
        except Exception as e:
            time.sleep(1)
    return None

def check_page_exists(book_id, page):
    html = fetch_page(book_id, page)
    if not html: return False
    soup = BeautifulSoup(html, 'html.parser')
    return soup.find('div', class_='nass') is not None

def find_last_page(book_id):
    print(f"Finding last page for book {book_id}...")
    low = 1
    high = 5000
    last_valid = 1
    
    while low <= high:
        mid = (low + high) // 2
        if check_page_exists(book_id, mid):
            last_valid = mid
            low = mid + 1
        else:
            high = mid - 1
            
    print(f"Last page for book {book_id} is {last_valid}")
    return last_valid

def scrape_page(args):
    book_id, page = args
    html = fetch_page(book_id, page)
    if not html: return page, ""
    soup = BeautifulSoup(html, 'html.parser')
    nass_div = soup.find('div', class_='nass')
    if not nass_div: return page, ""
    return page, nass_div.get_text(separator='\n', strip=True)

def parse_book(book_id, title, author, output_file):
    print(f"Starting scraping for: {title}")
    book_data = {
        "id": f"shamela_{book_id}",
        "title": title,
        "author": author,
        "format": "text",
        "chapters": []
    }
    
    last_page = find_last_page(book_id)
    pages_data = {}
    
    # 5 concurrent workers + 0.1s sleep to avoid rate limiting
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        args = [(book_id, p) for p in range(1, last_page + 1)]
        futures = {}
        for arg in args:
            futures[executor.submit(scrape_page, arg)] = arg
            time.sleep(0.05)
            
        for count, future in enumerate(concurrent.futures.as_completed(futures), 1):
            page, text = future.result()
            pages_data[page] = text
            if count % 20 == 0:
                print(f"Scraped page {count}/{last_page} for {title}")

    # Sort pages and add to chapters
    for page in sorted(pages_data.keys()):
        if pages_data[page]:
            book_data["chapters"].append({
                "title": f"الجزء {page}",
                "content": pages_data[page]
            })
            
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(book_data, f, ensure_ascii=False, indent=2)
        
    print(f"Finished {title}. Saved to {output_file}")

books_to_scrape = [
    (12209, "صيد الخاطر", "ابن الجوزي"),
    (8216, "الزهد لابن أبي الدنيا", "ابن أبي الدنيا"),
    (22551, "الزهد والرقائق", "الخطيب البغدادي"),
    (34493, "نوادر الأصول", "الحكيم الترمذي"),
    (12242, "الرضا عن الله بقضائه", "ابن أبي الدنيا")
]

output_dir = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\scripts\scraped_books"
os.makedirs(output_dir, exist_ok=True)

for book_id, title, author in books_to_scrape:
    out_file = os.path.join(output_dir, f"shamela_{book_id}.json")
    # Only scrape if it doesn't already exist to save time
    if not os.path.exists(out_file):
        parse_book(book_id, title, author, out_file)
    else:
        print(f"Skipping {title}, already exists.")

print("All books scraped successfully!")
