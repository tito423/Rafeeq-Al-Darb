import os
import json
import urllib.request
import subprocess
import time
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

API_BASE = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions"
REPO_PATH = r"e:\My Projects\Rafiq-Al-Darb\rafeeq-api"
HADITH_DIR = os.path.join(REPO_PATH, "hadith")

BOOKS = {
    "bukhari": {
        "id": "bukhari",
        "api_name": "ara-bukhari",
        "title": "صحيح البخاري",
        "author": "الإمام البخاري"
    },
    "muslim": {
        "id": "muslim",
        "api_name": "ara-muslim",
        "title": "صحيح مسلم",
        "author": "الإمام مسلم"
    },
    "abudawud": {
        "id": "abudawud",
        "api_name": "ara-abudawud",
        "title": "سنن أبي داود",
        "author": "الإمام أبو داود"
    },
    "tirmidhi": {
        "id": "tirmidhi",
        "api_name": "ara-tirmidhi",
        "title": "جامع الترمذي",
        "author": "الإمام الترمذي"
    },
    "nasai": {
        "id": "nasai",
        "api_name": "ara-nasai",
        "title": "سنن النسائي",
        "author": "الإمام النسائي"
    },
    "ibnmajah": {
        "id": "ibnmajah",
        "api_name": "ara-ibnmajah",
        "title": "سنن ابن ماجه",
        "author": "الإمام ابن ماجه"
    }
}

os.makedirs(HADITH_DIR, exist_ok=True)

# 1. Fetch JSONs
for b_id, b_info in BOOKS.items():
    print(f"Fetching {b_id}...")
    url = f"{API_BASE}/{b_info['api_name']}.json"
    try:
        req = urllib.request.urlopen(url, context=ctx)
        if req.getcode() == 200:
            data = json.loads(req.read().decode('utf-8'))
            out_path = os.path.join(HADITH_DIR, f"{b_id}.json")
            with open(out_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False)
            print(f"Saved {out_path}")
    except Exception as e:
        print(f"Failed to fetch {url}: {e}")
    time.sleep(1)

# 2. Update rafeeq_config.json
config_path = os.path.join(REPO_PATH, "rafeeq_config.json")
with open(config_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

new_books = []
for b_id, b_info in BOOKS.items():
    new_books.append({
        "id": b_id,
        "title": b_info['title'],
        "author": b_info['author'],
        "description": "كتاب حديث شريف",
        "download_url": f"https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/{b_id}.json",
        "cover_url": ""
    })

config['library']['books'] = new_books

with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, ensure_ascii=False, indent=2)

print("Updated rafeeq_config.json")

# 3. Git commit and push
print("Pushing to GitHub...")
subprocess.run(["git", "add", "."], cwd=REPO_PATH, check=True)
subprocess.run(["git", "commit", "-m", "Add full Arabic Hadith books collection"], cwd=REPO_PATH, check=False)
subprocess.run(["git", "push", "origin", "main"], cwd=REPO_PATH, check=True)
print("Done!")
