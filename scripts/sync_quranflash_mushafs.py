import os
import sys
import json
import shutil
import zipfile
import urllib.request
import ssl
from concurrent.futures import ThreadPoolExecutor

sys.stdout.reconfigure(encoding='utf-8')

# SSL context for downloading
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# Paths
LOCAL_QF_STORE = r'C:\Users\Asus\AppData\Roaming\desktop.quranflash\Local Store\perm\books'
APP_ASSETS_THUMBS = r'e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\mushaf_thumbs'
API_REPO_DIR = r'e:\My Projects\Rafiq-Al-Darb\rafeeq-api'
API_MUSHAF_DIR = os.path.join(API_REPO_DIR, 'mushaf')
API_THUMBS_DIR = os.path.join(API_MUSHAF_DIR, 'thumbs')

# 17 Mushafs from Quranflash
MUSHAFS_METADATA = [
    {
        "id": "medina1",
        "key": "Medina1",
        "name_ar": "مصحف المدينة النبوية (الإصدار الأول)",
        "name_en": "Normal Medina Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مجمع الملك فهد لطباعة المصحف الشريف",
        "desc_en": "Hafs - King Fahd Complex (Standard Edition)",
        "pages": 604,
        "total_images": 624,
        "type": "medina",
    },
    {
        "id": "medina2",
        "key": "Medina2",
        "name_ar": "مصحف المدينة النبوية (المحسَّن - مقاس وسط)",
        "name_en": "Medium Medina Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مجمع الملك فهد لطباعة المصحف الشريف",
        "desc_en": "Hafs - King Fahd Complex (Medium Edition)",
        "pages": 604,
        "total_images": 624,
        "type": "medina",
    },
    {
        "id": "medina3",
        "key": "Medina3",
        "name_ar": "المصحف الجوامعي",
        "name_en": "Jawamee Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مجمع الملك فهد لطباعة المصحف الشريف (حجم كبير)",
        "desc_en": "Hafs - King Fahd Complex (Large Jawamee Edition)",
        "pages": 604,
        "total_images": 624,
        "type": "medina",
    },
    {
        "id": "medina_old",
        "key": "MedinaOld",
        "name_ar": "مصحف المدينة النبوية القديم (الطبعة الكلاسيكية)",
        "name_en": "Old Medina Mushaf",
        "desc_ar": "رواية حفص عن عاصم - خط الخطاط عثمان طه (الإصدار الأول الأصلي)",
        "desc_en": "Hafs - Classic King Fahd Complex Original Edition",
        "pages": 604,
        "total_images": 624,
        "type": "medina",
    },
    {
        "id": "tajweed",
        "key": "Tajweed",
        "name_ar": "مصحف التجويد الملوَّن",
        "name_en": "Tajweed Moshaf",
        "desc_ar": "رواية حفص عن عاصم - مع ترميز أحكام التجويد بالألوان (دار المعرفة)",
        "desc_en": "Hafs - Colored Tajweed Rules by Dar Al-Maarifa",
        "pages": 604,
        "total_images": 604,
        "type": "tajweed",
    },
    {
        "id": "shamarly",
        "key": "Shamarly",
        "name_ar": "مصحف الشمرلي (15 سطر - الطبعة المصرية الشهيرة)",
        "name_en": "Shamarly Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مصحف الحرمين والشمرلي المصري العريق",
        "desc_en": "Hafs - Authentic Egyptian 15-line Shamarly Edition",
        "pages": 522,
        "total_images": 524,
        "type": "shamarly",
    },
    {
        "id": "warsh1",
        "key": "Warsh1",
        "name_ar": "مصحف رواية ورش عن نافع (مجمع الملك فهد)",
        "name_en": "Warsh Mushaf",
        "desc_ar": "رواية ورش عن نافع المدني من طريق الأزرق - مجمع الملك فهد",
        "desc_en": "Warsh from Nafi' - King Fahd Complex",
        "pages": 604,
        "total_images": 576,
        "type": "warsh",
    },
    {
        "id": "warsh2",
        "key": "Warsh2",
        "name_ar": "مصحف ورش من طريق الأصبهاني",
        "name_en": "Warsh (Asbahani)",
        "desc_ar": "رواية ورش عن نافع من طريق أبي بكر الأصبهاني",
        "desc_en": "Warsh from Nafi' - Asbahani Way",
        "pages": 604,
        "total_images": 610,
        "type": "warsh",
    },
    {
        "id": "qaloon",
        "key": "Qaloon",
        "name_ar": "مصحف رواية قالون عن نافع",
        "name_en": "Qaloon Mushaf",
        "desc_ar": "رواية قالون عن نافع المدني - مجمع الملك فهد لطباعة المصحف الشريف",
        "desc_en": "Qaloon from Nafi' - King Fahd Complex",
        "pages": 604,
        "total_images": 576,
        "type": "qaloon",
    },
    {
        "id": "douri",
        "key": "Douri",
        "name_ar": "مصحف رواية الدوري عن أبي عمرو",
        "name_en": "Douri Mushaf",
        "desc_ar": "رواية الدوري عن أبي عمرو البصري - مجمع الملك فهد لطباعة المصحف الشريف",
        "desc_en": "Douri from Abi Amr - King Fahd Complex",
        "pages": 604,
        "total_images": 544,
        "type": "douri",
    },
    {
        "id": "shubah",
        "key": "Shubah",
        "name_ar": "مصحف رواية شعبة عن عاصم",
        "name_en": "Shubah Mushaf",
        "desc_ar": "رواية شعبة بن عياش عن عاصم الكوفي - مجمع الملك فهد",
        "desc_en": "Shubah from Asim - King Fahd Complex",
        "pages": 604,
        "total_images": 624,
        "type": "shubah",
    },
    {
        "id": "line12",
        "key": "12line",
        "name_ar": "مصحف 12 سطر (الخط الكبير)",
        "name_en": "12 Lines Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مصحف 12 سطراً بخط واضح ومريح للقراءة",
        "desc_en": "Hafs - 12 Lines Large Script Edition",
        "pages": 850,
        "total_images": 850,
        "type": "12line",
    },
    {
        "id": "tahajod",
        "key": "Tahajod",
        "name_ar": "مصحف التهجد وقيام الليل (حجم عريض)",
        "name_en": "Tahajod Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مخصص لقيام الليل والتهجد (دار الصفوة)",
        "desc_en": "Hafs - Night Prayer Tahajod Wide Edition",
        "pages": 266,
        "total_images": 266,
        "type": "tahajod",
    },
    {
        "id": "naskh_taleek",
        "key": "NaskhTaleek",
        "name_ar": "مصحف خط نسخ تعليق (الفارسي)",
        "name_en": "Naskh Taleek Mushaf",
        "desc_ar": "مصحف مكتوب بخط النستعليق والنسخ تعليق الجميل",
        "desc_en": "Naskh Taleek Script Edition",
        "pages": 604,
        "total_images": 620,
        "type": "naskh",
    },
    {
        "id": "urdu12",
        "key": "Urdu12",
        "name_ar": "مصحف الأوردو (12 سطر)",
        "name_en": "Urdu 12 Lines",
        "desc_ar": "مصحف أوردو 12 سطراً للقراء في شبه القارة الهندية والباكستانية",
        "desc_en": "Urdu 12 Lines Edition",
        "pages": 736,
        "total_images": 736,
        "type": "urdu",
    },
    {
        "id": "urdu13",
        "key": "Urdu13",
        "name_ar": "مصحف الأوردو (13 سطر)",
        "name_en": "Urdu 13 Lines",
        "desc_ar": "مصحف أوردو 13 سطراً للطباعة الباكستانية والهندية",
        "desc_en": "Urdu 13 Lines Edition",
        "pages": 850,
        "total_images": 850,
        "type": "urdu",
    },
    {
        "id": "urdu15",
        "key": "Urdu15",
        "name_ar": "مصحف الأوردو (15 سطر)",
        "name_en": "Urdu 15 Lines",
        "desc_ar": "مصحف أوردو 15 سطراً الشهير لحفظ القرآن الكريم",
        "desc_en": "Urdu 15 Lines Standard Edition",
        "pages": 623,
        "total_images": 623,
        "type": "urdu",
    },
]

def sync_thumbnails():
    print("=== SYNCING THUMBNAILS FOR ALL 17 MUSHAFS ===")
    os.makedirs(APP_ASSETS_THUMBS, exist_ok=True)
    os.makedirs(API_THUMBS_DIR, exist_ok=True)
    
    for item in MUSHAFS_METADATA:
        key = item['key']
        mushaf_id = item['id']
        local_thumb_dir = os.path.join(LOCAL_QF_STORE, key, 'thumbs')
        
        target_app_dir = os.path.join(APP_ASSETS_THUMBS, mushaf_id)
        target_api_dir = os.path.join(API_THUMBS_DIR, mushaf_id)
        os.makedirs(target_app_dir, exist_ok=True)
        os.makedirs(target_api_dir, exist_ok=True)
        
        if os.path.exists(local_thumb_dir):
            for f in os.listdir(local_thumb_dir):
                src = os.path.join(local_thumb_dir, f)
                shutil.copy2(src, os.path.join(target_app_dir, f))
                shutil.copy2(src, os.path.join(target_api_dir, f))
            print(f"[OK] Synced local thumbs for {key} -> {mushaf_id}")
        else:
            # Fallback download from quranflash
            for thumb_name in ['cover.gif', 'page1.gif', 'page2.gif']:
                thumb_url = f"https://s3.amazonaws.com/quranflash/books/{key}/thumbs/{thumb_name}"
                try:
                    req = urllib.request.Request(thumb_url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(req, context=ctx, timeout=10) as r:
                        data = r.read()
                        with open(os.path.join(target_app_dir, thumb_name), 'wb') as fp:
                            fp.write(data)
                        with open(os.path.join(target_api_dir, thumb_name), 'wb') as fp:
                            fp.write(data)
                    print(f"[OK] Downloaded thumb {thumb_name} for {key}")
                except Exception as e:
                    print(f"[WARN] Failed thumb {thumb_name} for {key}: {e}")

def save_catalog():
    print("=== SAVING MUSHAFS CATALOG JSON ===")
    catalog_path_app = os.path.join(r'e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data', 'mushafs_catalog.json')
    catalog_path_api = os.path.join(API_REPO_DIR, 'mushafs_catalog.json')
    
    os.makedirs(os.path.dirname(catalog_path_app), exist_ok=True)
    with open(catalog_path_app, 'w', encoding='utf-8') as f:
        json.dump(MUSHAFS_METADATA, f, ensure_ascii=False, indent=2)
    with open(catalog_path_api, 'w', encoding='utf-8') as f:
        json.dump(MUSHAFS_METADATA, f, ensure_ascii=False, indent=2)
    print(f"[OK] Saved catalog to {catalog_path_app} & {catalog_path_api}")

def download_and_extract_mushaf(item):
    key = item['key']
    mushaf_id = item['id']
    target_dir = os.path.join(API_MUSHAF_DIR, mushaf_id)
    os.makedirs(target_dir, exist_ok=True)
    
    # Check if local files already exist in Quranflash AppData
    local_data_L = os.path.join(LOCAL_QF_STORE, key, 'data', 'L')
    if os.path.exists(local_data_L) and len(os.listdir(local_data_L)) > 100:
        print(f"[LOCAL] Copying {key} from local AppData ({len(os.listdir(local_data_L))} files)...")
        for f in os.listdir(local_data_L):
            src = os.path.join(local_data_L, f)
            # rename e.g. 0001.gif -> 1.png or keep clean page index
            # Quranflash index starts at 0001
            try:
                page_num = int(os.path.splitext(f)[0])
                dst = os.path.join(target_dir, f"{page_num}.png")
                shutil.copy2(src, dst)
            except Exception:
                shutil.copy2(src, os.path.join(target_dir, f))
        print(f"[SUCCESS] Copied local {key} -> {target_dir}")
        return

    # Download from Amazon S3
    s3_url = f"https://s3.amazonaws.com/quranflash/books/{key}/data/L.zip"
    print(f"[DOWNLOAD] Downloading {key} from {s3_url}...")
    zip_temp = os.path.join(API_REPO_DIR, f"{key}_L.zip")
    try:
        req = urllib.request.Request(s3_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
            with open(zip_temp, 'wb') as out:
                shutil.copyfileobj(resp, out)
        print(f"[EXTRACT] Extracting {key}_L.zip ({os.path.getsize(zip_temp) // 1024 // 1024} MB)...")
        with zipfile.ZipFile(zip_temp, 'r') as zf:
            for member in zf.namelist():
                filename = os.path.basename(member)
                if not filename:
                    continue
                try:
                    page_num = int(os.path.splitext(filename)[0])
                    dst_filename = f"{page_num}.png"
                except Exception:
                    dst_filename = filename
                
                with zf.open(member) as src_file, open(os.path.join(target_dir, dst_filename), 'wb') as dst_file:
                    shutil.copyfileobj(src_file, dst_file)
        
        os.remove(zip_temp)
        print(f"[SUCCESS] Finished {key} -> {target_dir} ({len(os.listdir(target_dir))} pages)")
    except Exception as e:
        print(f"[ERROR] Failed to download/extract {key}: {e}")

if __name__ == '__main__':
    sync_thumbnails()
    save_catalog()
    
    # Download prominent Mushafs
    priority_books = ['Tajweed', 'Shamarly', 'Warsh1', 'Qaloon', 'Douri', 'Shubah', 'Medina1', 'Medina2', 'MedinaOld', '12line', 'Tahajod']
    
    target_items = [m for m in MUSHAFS_METADATA if m['key'] in priority_books]
    print(f"Starting parallel download for {len(target_items)} priority Mushafs...")
    
    with ThreadPoolExecutor(max_workers=3) as pool:
        pool.map(download_and_extract_mushaf, target_items)
    
    print("=== ALL PRIORITY MUSHAFS SYNCED! ===")
