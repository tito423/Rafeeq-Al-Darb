import os
import sys
import shutil
import zipfile
import urllib.request
import ssl
from concurrent.futures import ThreadPoolExecutor

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

API_REPO_DIR = r'e:\My Projects\Rafiq-Al-Darb\rafeeq-api'
API_MUSHAF_DIR = os.path.join(API_REPO_DIR, 'mushaf')
LOCAL_QF_STORE = r'C:\Users\Asus\AppData\Roaming\desktop.quranflash\Local Store\perm\books'

MUSHAFS = [
    {"id": "medina1", "key": "Medina1", "min_pages": 604},
    {"id": "medina2", "key": "Medina2", "min_pages": 604},
    {"id": "medina3", "key": "Medina3", "min_pages": 604},
    {"id": "medina_old", "key": "MedinaOld", "min_pages": 604},
    {"id": "tajweed", "key": "Tajweed", "min_pages": 604},
    {"id": "shamarly", "key": "Shamarly", "min_pages": 522},
    {"id": "warsh1", "key": "Warsh1", "min_pages": 576},
    {"id": "warsh2", "key": "Warsh2", "min_pages": 604},
    {"id": "qaloon", "key": "Qaloon", "min_pages": 576},
    {"id": "douri", "key": "Douri", "min_pages": 544},
    {"id": "shubah", "key": "Shubah", "min_pages": 604},
    {"id": "line12", "key": "12line", "min_pages": 850},
    {"id": "tahajod", "key": "Tahajod", "min_pages": 266},
    {"id": "naskh_taleek", "key": "NaskhTaleek", "min_pages": 604},
    {"id": "urdu12", "key": "Urdu12", "min_pages": 736},
    {"id": "urdu13", "key": "Urdu13", "min_pages": 850},
    {"id": "urdu15", "key": "Urdu15", "min_pages": 623},
]

def process_mushaf(item):
    key = item['key']
    m_id = item['id']
    min_pages = item['min_pages']
    target_dir = os.path.join(API_MUSHAF_DIR, m_id)
    os.makedirs(target_dir, exist_ok=True)
    
    # Check existing count
    existing_files = [f for f in os.listdir(target_dir) if f.endswith(('.png', '.jpg', '.gif'))]
    if len(existing_files) >= min_pages:
        print(f"[READY] {m_id} already has {len(existing_files)} pages (>= {min_pages}).")
        return

    # Check local Quranflash AppData
    local_data_L = os.path.join(LOCAL_QF_STORE, key, 'data', 'L')
    if os.path.exists(local_data_L):
        local_files = os.listdir(local_data_L)
        if len(local_files) >= min_pages:
            print(f"[LOCAL] Copying {key} -> {m_id} ({len(local_files)} files)...")
            for f in local_files:
                try:
                    p_num = int(os.path.splitext(f)[0])
                    dst = os.path.join(target_dir, f"{p_num}.png")
                except Exception:
                    dst = os.path.join(target_dir, f)
                shutil.copy2(os.path.join(local_data_L, f), dst)
            print(f"[SUCCESS] Copied local {key} -> {m_id} ({len(os.listdir(target_dir))} pages)")
            return

    # Download from Amazon S3
    url = f"https://s3.amazonaws.com/quranflash/books/{key}/data/L.zip"
    zip_path = os.path.join(API_REPO_DIR, f"{key}_L.zip")
    print(f"[DOWNLOAD] Downloading {key} from {url}...")
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=300) as resp, open(zip_path, 'wb') as out:
            shutil.copyfileobj(resp, out)
        
        print(f"[EXTRACT] Extracting {key} to {m_id}...")
        with zipfile.ZipFile(zip_path, 'r') as zf:
            for member in zf.namelist():
                filename = os.path.basename(member)
                if not filename:
                    continue
                try:
                    p_num = int(os.path.splitext(filename)[0])
                    dst_name = f"{p_num}.png"
                except Exception:
                    dst_name = filename
                with zf.open(member) as src_f, open(os.path.join(target_dir, dst_name), 'wb') as dst_f:
                    shutil.copyfileobj(src_f, dst_f)
        
        if os.path.exists(zip_path):
            os.remove(zip_path)
        print(f"[SUCCESS] Finished {key} -> {m_id} with {len(os.listdir(target_dir))} pages")
    except Exception as e:
        print(f"[ERROR] Failed {key}: {e}")

if __name__ == '__main__':
    print("=== STARTING FAST PARALLEL DOWNLOAD FOR ALL MUSHAFS ===")
    with ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(process_mushaf, MUSHAFS))
    
    print("\n=== FINAL VERIFICATION OF PAGE COUNTS ===")
    for item in MUSHAFS:
        m_id = item['id']
        td = os.path.join(API_MUSHAF_DIR, m_id)
        cnt = len([f for f in os.listdir(td) if f.endswith(('.png', '.jpg', '.gif'))]) if os.path.exists(td) else 0
        status = "OK" if cnt >= item['min_pages'] else "INCOMPLETE"
        print(f"  {m_id:15}: {cnt:4} pages (min: {item['min_pages']}) -> [{status}]")
