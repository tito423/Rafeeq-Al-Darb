#!/usr/bin/env python3
import os
import urllib.request
import ssl
import time
import concurrent.futures

# This script downloads multiple Mushaf types from a reliable open-source GitHub repository (QuranHub)
# and saves them locally so you can push them to your rafeeq-api repository.

MUSHAFS = {
    "hafs": {
        "url_template": "https://raw.githubusercontent.com/QuranHub/quran-pages-images/main/kfgqpc/hafs-wasat/{page}.jpg",
        "folder": "../rafeeq-api/mushaf/hafs"
    },
    "warsh": {
        "url_template": "https://raw.githubusercontent.com/QuranHub/quran-pages-images/main/kfgqpc/warsh/{page}.jpg",
        "folder": "../rafeeq-api/mushaf/warsh"
    },
    "tajweed": {
        "url_template": "https://raw.githubusercontent.com/QuranHub/quran-pages-images/main/easyquran.com/hafs-tajweed/{page}.jpg",
        "folder": "../rafeeq-api/mushaf/tajweed"
    }
}

# SSL context to bypass verification if needed
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def download_page(mushaf_key, page, url_template, output_dir):
    url = url_template.format(page=page)
    file_path = os.path.join(output_dir, f"{page}.jpg")
    
    if os.path.exists(file_path):
        return f"{mushaf_key} Page {page}: Already exists."
        
    retries = 3
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, context=ctx, timeout=15) as response, open(file_path, 'wb') as out_file:
                data = response.read()
                out_file.write(data)
            return f"{mushaf_key} Page {page}: Downloaded successfully."
        except Exception as e:
            time.sleep(1)
            if attempt == retries - 1:
                return f"{mushaf_key} Page {page}: Failed after {retries} attempts - {e}"

def download_all_mushafs():
    tasks = []
    
    for key, config in MUSHAFS.items():
        folder = config["folder"]
        if not os.path.exists(folder):
            os.makedirs(folder)
            
        print(f"Preparing to download {key} Mushaf to {folder}...")
        for page in range(1, 605):
            tasks.append((key, page, config["url_template"], folder))
            
    print(f"Starting download of {len(tasks)} total pages using ThreadPoolExecutor...")
    
    # Use 15 concurrent threads to speed up the process significantly
    with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
        futures = {executor.submit(download_page, t[0], t[1], t[2], t[3]): t for t in tasks}
        
        count = 0
        for future in concurrent.futures.as_completed(futures):
            count += 1
            result = future.result()
            if count % 50 == 0:
                print(f"Progress: {count}/{len(tasks)} pages processed.")
                
    print("Download complete! You can now commit and push the 'mushaf' folder to your rafeeq-api repository.")

if __name__ == "__main__":
    download_all_mushafs()
