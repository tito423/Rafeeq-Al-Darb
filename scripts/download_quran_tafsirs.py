import os
import json
import asyncio
import aiohttp
from pathlib import Path

PROJECT_ROOT = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TAFSIR_DIR = PROJECT_ROOT / "assets" / "data" / "tafsir"

# Tafsir IDs from Quran.com API v4
TAFSIRS = {
    14: "ibn_kathir",
    90: "qurtubi",
    91: "saddi",
    94: "baghawi",
}

async def fetch_chapter_tafsir(session, tafsir_id, chapter):
    url = f"https://api.quran.com/api/v4/quran/tafsirs/{tafsir_id}?chapter_number={chapter}"
    try:
        async with session.get(url) as response:
            if response.status == 200:
                data = await response.json()
                return data.get('tafsirs', [])
            else:
                print(f"[-] HTTP {response.status} for Tafsir {tafsir_id} Chapter {chapter}")
                return []
    except Exception as e:
        print(f"[-] Error Tafsir {tafsir_id} Chapter {chapter}: {e}")
        return []

async def download_tafsir(session, tafsir_id, slug_name):
    print(f"[*] Downloading Tafsir: {slug_name} (ID: {tafsir_id})...")
    output_file = TAFSIR_DIR / f"tafsir_{slug_name}.json"
    
    if output_file.exists():
        print(f"[+] {slug_name} already exists. Skipping.")
        return

    all_verses = []
    # 114 Surahs
    for chapter in range(1, 115):
        verses = await fetch_chapter_tafsir(session, tafsir_id, chapter)
        all_verses.extend(verses)
        # Small sleep to prevent rate limiting (100ms)
        await asyncio.sleep(0.1)
        if chapter % 20 == 0:
            print(f"    - {slug_name}: Fetched {chapter}/114 surahs...")

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump({'tafsir_id': tafsir_id, 'name': slug_name, 'tafsirs': all_verses}, f, ensure_ascii=False, indent=2)
    
    print(f"[+] Finished downloading Tafsir: {slug_name} ({len(all_verses)} verses)")

async def main():
    TAFSIR_DIR.mkdir(parents=True, exist_ok=True)
    async with aiohttp.ClientSession() as session:
        for tafsir_id, slug in TAFSIRS.items():
            await download_tafsir(session, tafsir_id, slug)

if __name__ == "__main__":
    asyncio.run(main())
