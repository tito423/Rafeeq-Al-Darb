import os
import asyncio
import aiohttp

RECITERS = [
    "Alafasy_128kbps",
    "Abdul_Basit_Murattal_192kbps",
    "Husary_128kbps"
]

BASE_URL = "https://everyayah.com/data/{}/{:03d}{:03d}.mp3"
OUTPUT_DIR = "temp_downloads/audio/reciters"

SURAH_AYAHS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
    112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
    54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
    14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
    29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
    11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
]

# Ensure we limit concurrent connections so we don't overwhelm the server
SEMAPHORE_LIMIT = 50

async def download_ayah(session, reciter, surah, ayah, semaphore):
    url = BASE_URL.format(reciter, surah, ayah)
    reciter_dir = os.path.join(OUTPUT_DIR, reciter)
    output_path = os.path.join(reciter_dir, f"{surah:03d}{ayah:03d}.mp3")
    
    if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
        return # Skip already downloaded
        
    async with semaphore:
        try:
            async with session.get(url, timeout=30) as response:
                if response.status == 200:
                    data = await response.read()
                    with open(output_path, "wb") as f:
                        f.write(data)
                else:
                    print(f"Failed to download {surah:03d}{ayah:03d} for {reciter} (HTTP {response.status})")
        except Exception as e:
            print(f"Error downloading {surah:03d}{ayah:03d} for {reciter}: {e}")

async def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for reciter in RECITERS:
        os.makedirs(os.path.join(OUTPUT_DIR, reciter), exist_ok=True)
        
    semaphore = asyncio.Semaphore(SEMAPHORE_LIMIT)
    
    # We will use a shared session
    conn = aiohttp.TCPConnector(limit=SEMAPHORE_LIMIT)
    async with aiohttp.ClientSession(connector=conn) as session:
        tasks = []
        for reciter in RECITERS:
            print(f"Queueing downloads for {reciter}...")
            for surah_idx, num_ayahs in enumerate(SURAH_AYAHS):
                surah = surah_idx + 1
                for ayah in range(1, num_ayahs + 1):
                    tasks.append(download_ayah(session, reciter, surah, ayah, semaphore))
        
        print(f"Total files to check/download: {len(tasks)}")
        
        # Process in batches to avoid event loop overload
        batch_size = 10000
        for i in range(0, len(tasks), batch_size):
            batch = tasks[i:i+batch_size]
            print(f"Processing batch {i} to {i+batch_size}...")
            await asyncio.gather(*batch)
            
    print("Audio download complete.")

if __name__ == "__main__":
    asyncio.run(main())
