import os
import sys
import json
import shutil
import zipfile
import urllib.request
import ssl
from concurrent.futures import ThreadPoolExecutor

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

LOCAL_QF_STORE = r'C:\Users\Asus\AppData\Roaming\desktop.quranflash\Local Store\perm\books'
APP_ASSETS_THUMBS = r'e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\mushaf_thumbs'
API_REPO_DIR = r'e:\My Projects\Rafiq-Al-Darb\rafeeq-api'
API_MUSHAF_DIR = os.path.join(API_REPO_DIR, 'mushaf')
API_THUMBS_DIR = os.path.join(API_MUSHAF_DIR, 'thumbs')

# All 17 Quranflash Mushafs
MUSHAFS = [
    {
        "id": "medina1",
        "key": "Medina1",
        "name_ar": "مصحف المدينة النبوية (الإصدار الأول)",
        "name_en": "Normal Medina Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مجمع الملك فهد لطباعة المصحف الشريف",
        "pages": 604,
        "type": "medina",
    },
    {
        "id": "medina2",
        "key": "Medina2",
        "name_ar": "مصحف المدينة النبوية (المحسَّن)",
        "name_en": "Medium Medina Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مجمع الملك فهد لطباعة المصحف الشريف (مقاس وسط)",
        "pages": 604,
        "type": "medina",
    },
    {
        "id": "medina3",
        "key": "Medina3",
        "name_ar": "المصحف الجوامعي الكبير",
        "name_en": "Jawamee Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مجمع الملك فهد (مقاس جوامعي كبير)",
        "pages": 604,
        "type": "medina",
    },
    {
        "id": "medina_old",
        "key": "MedinaOld",
        "name_ar": "مصحف المدينة النبوية القديم",
        "name_en": "Old Medina Mushaf",
        "desc_ar": "رواية حفص عن عاصم - خط الخطاط عثمان طه (الإصدار الأول الأصلي)",
        "pages": 604,
        "type": "medina",
    },
    {
        "id": "tajweed",
        "key": "Tajweed",
        "name_ar": "مصحف التجويد الملوَّن",
        "name_en": "Tajweed Moshaf",
        "desc_ar": "رواية حفص عن عاصم - مع ترميز أحكام التجويد بالألوان (دار المعرفة)",
        "pages": 604,
        "type": "tajweed",
    },
    {
        "id": "shamarly",
        "key": "Shamarly",
        "name_ar": "مصحف الشمرلي (15 سطر - المصرية)",
        "name_en": "Shamarly Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مصحف الشمرلي المصري الشهير",
        "pages": 522,
        "type": "shamarly",
    },
    {
        "id": "warsh1",
        "key": "Warsh1",
        "name_ar": "مصحف رواية ورش (مجمع الملك فهد)",
        "name_en": "Warsh Mushaf",
        "desc_ar": "رواية ورش عن نافع المدني من طريق الأزرق - مجمع الملك فهد",
        "pages": 604,
        "type": "warsh",
    },
    {
        "id": "warsh2",
        "key": "Warsh2",
        "name_ar": "مصحف ورش من طريق الأصبهاني",
        "name_en": "Warsh (Asbahani)",
        "desc_ar": "رواية ورش عن نافع من طريق أبي بكر الأصبهاني",
        "pages": 604,
        "type": "warsh",
    },
    {
        "id": "qaloon",
        "key": "Qaloon",
        "name_ar": "مصحف رواية قالون عن نافع",
        "name_en": "Qaloon Mushaf",
        "desc_ar": "رواية قالون عن نافع المدني - مجمع الملك فهد",
        "pages": 604,
        "type": "qaloon",
    },
    {
        "id": "douri",
        "key": "Douri",
        "name_ar": "مصحف رواية الدوري عن أبي عمرو",
        "name_en": "Douri Mushaf",
        "desc_ar": "رواية الدوري عن أبي عمرو البصري - مجمع الملك فهد",
        "pages": 604,
        "type": "douri",
    },
    {
        "id": "shubah",
        "key": "Shubah",
        "name_ar": "مصحف رواية شعبة عن عاصم",
        "name_en": "Shubah Mushaf",
        "desc_ar": "رواية شعبة بن عياش عن عاصم الكوفي - مجمع الملك فهد",
        "pages": 604,
        "type": "shubah",
    },
    {
        "id": "line12",
        "key": "12line",
        "name_ar": "مصحف 12 سطر (الخط الكبير)",
        "name_en": "12 Lines Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مصحف 12 سطراً بخط كبير وواضح",
        "pages": 850,
        "type": "12line",
    },
    {
        "id": "tahajod",
        "key": "Tahajod",
        "name_ar": "مصحف التهجد وقيام الليل",
        "name_en": "Tahajod Mushaf",
        "desc_ar": "رواية حفص عن عاصم - مخصص لقيام الليل والتهجد (دار الصفوة)",
        "pages": 266,
        "type": "tahajod",
    },
    {
        "id": "naskh_taleek",
        "key": "NaskhTaleek",
        "name_ar": "مصحف خط نسخ تعليق",
        "name_en": "Naskh Taleek Mushaf",
        "desc_ar": "مصحف مكتوب بخط النستعليق والنسخ تعليق الجميل",
        "pages": 604,
        "type": "naskh",
    },
    {
        "id": "urdu12",
        "key": "Urdu12",
        "name_ar": "مصحف الأوردو (12 سطر)",
        "name_en": "Urdu 12 Lines",
        "desc_ar": "مصحف أوردو 12 سطراً للطباعة الباكستانية والهندية",
        "pages": 736,
        "type": "urdu",
    },
    {
        "id": "urdu13",
        "key": "Urdu13",
        "name_ar": "مصحف الأوردو (13 سطر)",
        "name_en": "Urdu 13 Lines",
        "desc_ar": "مصحف أوردو 13 سطراً للطباعة الباكستانية والهندية",
        "pages": 850,
        "type": "urdu",
    },
    {
        "id": "urdu15",
        "key": "Urdu15",
        "name_ar": "مصحف الأوردو (15 سطر)",
        "name_en": "Urdu 15 Lines",
        "desc_ar": "مصحف أوردو 15 سطراً الشهير لحفظ القرآن الكريم",
        "pages": 623,
        "type": "urdu",
    },
]

def download_book(item):
    key = item['key']
    mushaf_id = item['id']
    target_dir = os.path.join(API_MUSHAF_DIR, mushaf_id)
    os.makedirs(target_dir, exist_ok=True)
    
    # Check if already downloaded
    existing = len([f for f in os.listdir(target_dir) if f.endswith(('.png', '.jpg', '.gif'))])
    if existing > 100:
        print(f"[SKIP] {key} already has {existing} pages.")
        return

    # Check local store first
    local_L = os.path.join(LOCAL_QF_STORE, key, 'data', 'L')
    if os.path.exists(local_L) and len(os.listdir(local_L)) > 100:
        print(f"[COPY] Copying {key} from local Quranflash store...")
        for f in os.listdir(local_L):
            try:
                page_num = int(os.path.splitext(f)[0])
                shutil.copy2(os.path.join(local_L, f), os.path.join(target_dir, f"{page_num}.png"))
            except Exception:
                shutil.copy2(os.path.join(local_L, f), os.path.join(target_dir, f))
        print(f"[SUCCESS] Copied {key} ({len(os.listdir(target_dir))} pages)")
        return

    # Download L.zip from Amazon S3
    url = f"https://s3.amazonaws.com/quranflash/books/{key}/data/L.zip"
    zip_path = os.path.join(API_REPO_DIR, f"{key}_L.zip")
    print(f"[START] Downloading {key} from {url}...")
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=300) as resp, open(zip_path, 'wb') as out:
            total_size = int(resp.headers.get('Content-Length', 0))
            downloaded = 0
            chunk_size = 1024 * 1024  # 1 MB chunk
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                out.write(chunk)
                downloaded += len(chunk)
                if total_size > 0:
                    pct = (downloaded / total_size) * 100
                    print(f"[{key}] {downloaded // 1024 // 1024} MB / {total_size // 1024 // 1024} MB ({pct:.1f}%)", end='\r', flush=True)

        print(f"\n[EXTRACT] Extracting {key}...")
        with zipfile.ZipFile(zip_path, 'r') as zf:
            for member in zf.namelist():
                filename = os.path.basename(member)
                if not filename:
                    continue
                try:
                    page_num = int(os.path.splitext(filename)[0])
                    dst_name = f"{page_num}.png"
                except Exception:
                    dst_name = filename
                with zf.open(member) as s_file, open(os.path.join(target_dir, dst_name), 'wb') as d_file:
                    shutil.copyfileobj(s_file, d_file)
        
        if os.path.exists(zip_path):
            os.remove(zip_path)
        print(f"[SUCCESS] Finished {key} -> {len(os.listdir(target_dir))} pages")
    except Exception as e:
        print(f"[ERROR] Failed {key}: {e}")

if __name__ == '__main__':
    # Kill any old download processes if needed
    for item in MUSHAFS:
        download_book(item)
    print("=== ALL 17 MUSHAFS PROCESSED ===")
