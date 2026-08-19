import os
import requests
import json
from concurrent.futures import ThreadPoolExecutor

# Quranflash S3 bucket endpoint (based on app analysis)
BASE_URL = "https://s3.amazonaws.com/quranflash/books"

# Known Mushaf IDs based on Quranflash platform
MUSHAFS = {
    "hafs_medina": "15_c",
    "hafs_shamrly": "4_c",
    "hafs_tajweed": "1_c",
    "warsh_medina": "2_c",
    "qaloon": "3_c",
    "doori": "7_c",
    "shuba": "8_c"
}

OUTPUT_DIR = "quranflash_mushafs"

def download_file(url, filepath):
    if os.path.exists(filepath):
        return
    try:
        response = requests.get(url, stream=True, timeout=10)
        if response.status_code == 200:
            with open(filepath, 'wb') as f:
                for chunk in response.iter_content(1024):
                    f.write(chunk)
            print(f"Downloaded: {filepath}")
        else:
            print(f"Failed to download (Status {response.status_code}): {url}")
    except Exception as e:
        print(f"Error downloading {url}: {e}")

def process_mushaf(mushaf_name, mushaf_id):
    print(f"--- Starting download for {mushaf_name} ---")
    mushaf_dir = os.path.join(OUTPUT_DIR, mushaf_name)
    os.makedirs(mushaf_dir, exist_ok=True)
    
    # Quranflash typically stores pages as {page_num}.png or {page_num}.jpg in a subfolder
    # Usually pages are from 1 to 604
    
    def download_page(page_num):
        # Trying standard hi-res page URL pattern
        url_jpg = f"{BASE_URL}/{mushaf_id}/pages/high/{page_num}.jpg"
        filepath_jpg = os.path.join(mushaf_dir, f"{page_num}.jpg")
        
        # Download image
        download_file(url_jpg, filepath_jpg)

    # Use multithreading to speed up downloading 604 pages
    with ThreadPoolExecutor(max_workers=10) as executor:
        executor.map(download_page, range(1, 605))
        
    print(f"--- Completed {mushaf_name} ---")

def generate_github_json():
    # Generate a catalog.json for your Github API
    catalog = []
    for name, _ in MUSHAFS.items():
        catalog.append({
            "id": name,
            "name": name.replace("_", " ").title(),
            "base_url": f"https://raw.githubusercontent.com/tito423/rafeeq-api/main/mushafs/{name}/",
            "total_pages": 604,
            "extension": ".jpg"
        })
        
    with open(os.path.join(OUTPUT_DIR, "catalog.json"), "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=4)
    print("Generated catalog.json for Github.")

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for name, qf_id in MUSHAFS.items():
        process_mushaf(name, qf_id)
        
    generate_github_json()
    print("\nAll downloads complete! You can now upload the 'quranflash_mushafs' folder to your GitHub repository.")
