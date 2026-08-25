import os
import asyncio
import aiohttp

BASE_URL = "https://raw.githubusercontent.com/GovarJabbar/Quran-PNG/master/{:03d}.png"
OUTPUT_DIR = "temp_downloads/mushaf/madani_1024"

# Ensure we limit concurrent connections
SEMAPHORE_LIMIT = 20

async def download_page(session, page_num, semaphore):
    url = BASE_URL.format(page_num)
    output_path = os.path.join(OUTPUT_DIR, f"page{page_num:03d}.png")
    
    if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
        return # Skip already downloaded
        
    async with semaphore:
        try:
            async with session.get(url, timeout=30) as response:
                if response.status == 200:
                    data = await response.read()
                    with open(output_path, "wb") as f:
                        f.write(data)
                    print(f"Downloaded page {page_num}")
                else:
                    print(f"Failed to download page {page_num} (HTTP {response.status})")
        except Exception as e:
            print(f"Error downloading page {page_num}: {e}")

async def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    semaphore = asyncio.Semaphore(SEMAPHORE_LIMIT)
    
    conn = aiohttp.TCPConnector(limit=SEMAPHORE_LIMIT)
    async with aiohttp.ClientSession(connector=conn) as session:
        tasks = []
        for page_num in range(1, 605):
            tasks.append(download_page(session, page_num, semaphore))
        
        print(f"Queueing downloads for 604 Quran pages...")
        await asyncio.gather(*tasks)
            
    print("Quran pages download complete.")

if __name__ == "__main__":
    asyncio.run(main())
