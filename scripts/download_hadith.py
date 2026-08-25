import os
import asyncio
import aiohttp
import json

HADITH_BOOKS = [
    "ara-bukhari",
    "ara-muslim",
    "ara-abudawud",
    "ara-tirmidhi",
    "ara-nasai",
    "ara-ibnmajah",
    "ara-malik",
    "ara-nawawi",
    "ara-qudsi"
]

BASE_URL = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/{}.json"
OUTPUT_DIR = "temp_downloads/hadith"

async def download_hadith(session, book_name):
    url = BASE_URL.format(book_name)
    output_path = os.path.join(OUTPUT_DIR, f"{book_name}.json")
    
    if os.path.exists(output_path):
        print(f"[SKIP] {book_name} already exists.")
        return

    print(f"[START] Downloading {book_name}...")
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                with open(output_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"[SUCCESS] {book_name} downloaded successfully.")
            else:
                print(f"[ERROR] Failed to download {book_name} - HTTP {response.status}")
    except Exception as e:
        print(f"[ERROR] Exception while downloading {book_name}: {str(e)}")

async def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    async with aiohttp.ClientSession() as session:
        tasks = [download_hadith(session, book) for book in HADITH_BOOKS]
        await asyncio.gather(*tasks)
    print("Hadith download complete.")

if __name__ == "__main__":
    asyncio.run(main())
