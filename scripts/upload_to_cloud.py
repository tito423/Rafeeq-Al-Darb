import os
import sys
import boto3
from concurrent.futures import ThreadPoolExecutor
import firebase_admin
from firebase_admin import credentials, firestore

API_REPO_DIR = r'e:\My Projects\Rafiq-Al-Darb\rafeeq-api'
API_MUSHAF_DIR = os.path.join(API_REPO_DIR, 'mushaf')
APP_ASSETS_DIR = r'e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data'

BUCKET_NAME = 'rafeeq-assets' # Replace with your actual R2 bucket name if different

# 1. Initialize Cloudflare R2 Client
s3 = boto3.client(
    's3',
    endpoint_url='https://33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com',
    aws_access_key_id='0ea932e392ce7b96cb81e8b4132a26d9',
    aws_secret_access_key='a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad',
    region_name='auto'
)

# 2. Initialize Firebase
db = None
service_account_path = os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
if os.path.exists(service_account_path):
    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("[Firebase] Initialized successfully.")
else:
    print("[WARNING] serviceAccountKey.json not found! Firebase indexing will be skipped.")

def upload_file(local_path, s3_path):
    try:
        s3.upload_file(local_path, BUCKET_NAME, s3_path)
        print(f"Uploaded: {s3_path}")
    except Exception as e:
        print(f"Failed to upload {local_path}: {e}")

def process_mushaf_edition(edition_id):
    edition_dir = os.path.join(API_MUSHAF_DIR, edition_id)
    if not os.path.isdir(edition_dir):
        return

    files = [f for f in os.listdir(edition_dir) if f.endswith(('.png', '.jpg'))]
    print(f"Processing Mushaf [{edition_id}] - {len(files)} pages")
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        for f in files:
            local_path = os.path.join(edition_dir, f)
            s3_path = f"mushaf/{edition_id}/pages/{f}"
            executor.submit(upload_file, local_path, s3_path)

    # Index into Firebase
    if db:
        doc_ref = db.collection('mushafs').document(edition_id)
        doc_ref.set({
            'id': edition_id,
            'name': edition_id.replace('_', ' ').title(),
            'total_pages': len(files),
            'base_url': f"mushaf/{edition_id}/pages/"
        })
        print(f"[Firebase] Indexed {edition_id}")

def process_other_assets():
    if not os.path.exists(APP_ASSETS_DIR):
        print(f"Directory {APP_ASSETS_DIR} does not exist. Skipping other assets.")
        return
        
    print("Processing other assets (Tafsir, Hadith, Books)...")
    with ThreadPoolExecutor(max_workers=10) as executor:
        for root, dirs, files in os.walk(APP_ASSETS_DIR):
            for file in files:
                local_path = os.path.join(root, file)
                rel_path = os.path.relpath(local_path, APP_ASSETS_DIR)
                # Normalize slashes for S3
                s3_path = f"data/{rel_path}".replace('\\', '/')
                executor.submit(upload_file, local_path, s3_path)

if __name__ == '__main__':
    print("Starting upload process...")
    # 1. Process Mushafs
    if os.path.exists(API_MUSHAF_DIR):
        for edition_id in os.listdir(API_MUSHAF_DIR):
            process_mushaf_edition(edition_id)
            
    # 2. Process Other Assets
    process_other_assets()
    
    print("Done!")
