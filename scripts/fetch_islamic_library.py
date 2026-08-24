import os
import shutil
import json
import asyncio
import aiohttp
from pathlib import Path

# Setup paths
PROJECT_ROOT = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCAL_MUSHAF_DIR = PROJECT_ROOT.parent / "rafeeq-api" / "mushaf"

DATA_DIR = PROJECT_ROOT / "assets" / "data"
QURAN_IMAGES_DIR = DATA_DIR / "quran_images"
QURAN_TEXT_DIR = DATA_DIR / "quran_text"
TAFSIR_DIR = DATA_DIR / "tafsir"
HADITH_DIR = DATA_DIR / "hadith"
BOOKS_DIR = DATA_DIR / "books"

MISSING_BOOKS_LOG = PROJECT_ROOT / "missing_books.txt"

def setup_directories():
    for d in [DATA_DIR, QURAN_IMAGES_DIR, QURAN_TEXT_DIR, TAFSIR_DIR, HADITH_DIR, BOOKS_DIR]:
        d.mkdir(parents=True, exist_ok=True)
    
    if MISSING_BOOKS_LOG.exists():
        MISSING_BOOKS_LOG.unlink()

def log_missing(book_title):
    with open(MISSING_BOOKS_LOG, "a", encoding="utf-8") as f:
        f.write(f"{book_title}\n")
    print(f"[MISSING] Logged missing book: {book_title}")

def copy_local_mushaf():
    print(f"[*] Checking local Mushaf images at: {LOCAL_MUSHAF_DIR}")
    if LOCAL_MUSHAF_DIR.exists() and LOCAL_MUSHAF_DIR.is_dir():
        print(f"[*] Found local Mushaf images. Copying to {QURAN_IMAGES_DIR}...")
        # Iterating styles
        for style_dir in LOCAL_MUSHAF_DIR.iterdir():
            if style_dir.is_dir():
                dest_style = QURAN_IMAGES_DIR / style_dir.name
                if not dest_style.exists():
                    print(f"    -> Copying style: {style_dir.name}")
                    shutil.copytree(style_dir, dest_style)
                else:
                    print(f"    -> Style already exists: {style_dir.name}")
        print("[+] Local Mushaf images copied successfully.")
    else:
        print("[-] Could not find local Mushaf directory.")

async def fetch_json(session, url, dest_path, file_name):
    target_file = dest_path / file_name
    if target_file.exists():
        return True

    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json(content_type=None)
                with open(target_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"[+] Downloaded: {file_name}")
                return True
            else:
                print(f"[-] Failed {file_name}: HTTP {response.status}")
                return False
    except Exception as e:
        print(f"[-] Error downloading {file_name}: {e}")
        return False

async def download_text_data():
    print("\n[*] Starting text data downloads...")
    async with aiohttp.ClientSession() as session:
        tasks = []
        
        # 1. Quran Text (Uthmani)
        tasks.append(fetch_json(session, "https://api.alquran.cloud/v1/quran/quran-uthmani", QURAN_TEXT_DIR, "quran_uthmani.json"))
        
        # 2. Quran Translations (en, ur, fr)
        for lang in ['en.sahih', 'ur.jalandhry', 'fr.hamidullah']:
            tasks.append(fetch_json(session, f"https://api.alquran.cloud/v1/quran/{lang}", QURAN_TEXT_DIR, f"translation_{lang}.json"))
            
        # 3. Tafsirs (from api.alquran.cloud - wait, let's use some known ones if available)
        # Often tafsirs are available in editions like ar.muyassar, ar.jalalayn
        for tafsir in ['ar.muyassar', 'ar.jalalayn']:
            tasks.append(fetch_json(session, f"https://api.alquran.cloud/v1/quran/{tafsir}", TAFSIR_DIR, f"tafsir_{tafsir}.json"))
            
        # 4. Hadith (from fawazahmed0/hadith-api)
        hadith_books = ['bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah', 'malik']
        for book in hadith_books:
            url = f"https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-{book}.json"
            tasks.append(fetch_json(session, url, HADITH_DIR, f"hadith_{book}.json"))
            
        await asyncio.gather(*tasks)

        # 5. Log specific missing books that we can't reliably fetch via simple open APIs without a scraper
        specific_books = [
            "Tafsir Al-Qurtubi",
            "Tafsir Al-Sa'di",
            "Tafsir Al-Baghawi",
            "Tafsir Ibn Kathir",
            "Tafsir Ibn Al-Qayyim",
            "Riyad as-Salihin",
            "Mukhtasar Minhaj al-Qasidin",
            "Muntakhab al-Nafais",
            "Al-Tadhkirah",
            "La Tahzan",
            "Zad al-Ma'ad",
            "Fiqh al-Sunnah",
            "Al-Fiqh 'ala al-Madhahib al-Arba'ah",
            "Hilyat al-Awliya",
            "Zad Academy Curriculum (Levels 1-4)",
            "Works of Dr. Mustafa Mahmoud",
            "I'rab Al-Quran",
            "Asbab Al-Nuzul",
            "Shamela Dumps (Preaching, Softening of Hearts, Asceticism)"
        ]
        
        for book in specific_books:
            log_missing(book)

if __name__ == "__main__":
    setup_directories()
    copy_local_mushaf()
    asyncio.run(download_text_data())
    print("\n[*] Script completed.")
