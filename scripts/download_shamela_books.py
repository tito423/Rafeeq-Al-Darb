import os
import json
import asyncio
import aiohttp
from pathlib import Path

PROJECT_ROOT = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BOOKS_DIR = PROJECT_ROOT / "assets" / "data" / "books"

# Known raw JSON endpoints for some specific books
KNOWN_BOOKS = {
    "riyad_as_salihin": "https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/riyad_as_salihin/ar/riyad_as_salihin.json", # Usually something like this
    # OpenIslamicTexts etc might have these, I'll attempt a direct GitHub Search API to find JSONs matching the titles!
}

# The list of missing books
BOOKS_TO_FIND = [
    "Riyad as-Salihin",
    "Mukhtasar Minhaj al-Qasidin",
    "Muntakhab al-Nafais",
    "Al-Tadhkirah",
    "La Tahzan",
    "Zad al-Ma'ad",
    "Fiqh al-Sunnah",
    "Al-Fiqh 'ala al-Madhahib al-Arba'ah",
    "Hilyat al-Awliya",
    "Zad Academy Curriculum",
    "Works of Dr. Mustafa Mahmoud",
    "I'rab Al-Quran",
    "Asbab Al-Nuzul",
    "Shamela Preaching Softening Asceticism"
]

async def search_github_for_json(session, book_title):
    query = f"{book_title} extension:json"
    url = f"https://api.github.com/search/code?q={query}&per_page=1"
    headers = {'User-Agent': 'Rafeeq-Al-Darb-App'}
    try:
        async with session.get(url, headers=headers) as response:
            if response.status == 200:
                data = await response.json()
                items = data.get('items', [])
                if items:
                    item = items[0]
                    # Get raw URL
                    raw_url = item['html_url'].replace('github.com', 'raw.githubusercontent.com').replace('/blob/', '/')
                    return raw_url
    except Exception as e:
        print(f"[-] Error searching Github for {book_title}: {e}")
    return None

async def download_file(session, url, dest_path):
    try:
        async with session.get(url) as response:
            if response.status == 200:
                text = await response.text()
                with open(dest_path, 'w', encoding='utf-8') as f:
                    f.write(text)
                return True
    except Exception as e:
        pass
    return False

async def download_book(session, book_title):
    slug = book_title.lower().replace(' ', '_').replace('-', '_').replace("'", "")
    output_file = BOOKS_DIR / f"{slug}.json"
    
    if output_file.exists():
        print(f"[+] {book_title} already exists. Skipping.")
        return
        
    print(f"[*] Searching for {book_title}...")
    raw_url = await search_github_for_json(session, book_title)
    
    if raw_url:
        print(f"    -> Found JSON at: {raw_url}")
        success = await download_file(session, raw_url, output_file)
        if success:
            print(f"[+] Downloaded {book_title} successfully.")
        else:
            print(f"[-] Failed to download raw JSON for {book_title}.")
    else:
        print(f"[-] Could not find a direct JSON dataset for {book_title} on GitHub.")
        # Create a stub file to indicate it requires manual scraping later
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump({"title": book_title, "status": "Pending Manual Scraping / PDF Extraction"}, f, indent=2)

async def main():
    BOOKS_DIR.mkdir(parents=True, exist_ok=True)
    async with aiohttp.ClientSession() as session:
        tasks = []
        for book in BOOKS_TO_FIND:
            tasks.append(download_book(session, book))
            await asyncio.sleep(1) # Prevent GitHub search API rate limit (10 requests/min for unauthenticated search)
        
        # Gathering them sequentially since we have sleep limits
        for task in tasks:
            await task

if __name__ == "__main__":
    asyncio.run(main())
