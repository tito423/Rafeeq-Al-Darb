import os
import boto3
from botocore.config import Config
import mimetypes
from concurrent.futures import ThreadPoolExecutor, as_completed
import time

# ==========================================
# Cloudflare R2 Configuration
# ==========================================
R2_ENDPOINT_URL = "https://33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com"
R2_ACCESS_KEY = "0ea932e392ce7b96cb81e8b4132a26d9"
R2_SECRET_KEY = "a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad"
BUCKET_NAME = "rafeeq-aldarb-data"
MAX_WORKERS = 50  # Concurrent uploads

def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY,
        aws_secret_access_key=R2_SECRET_KEY,
        config=Config(signature_version='s3v4', retries={'max_attempts': 3, 'mode': 'standard'}),
        region_name='auto'
    )

def upload_single_file(client, local_path, bucket, s3_key, content_type):
    try:
        client.upload_file(
            local_path, 
            bucket, 
            s3_key,
            ExtraArgs={'ContentType': content_type}
        )
        return True, local_path
    except Exception as e:
        return False, f"{local_path} (Error: {e})"

def upload_directory_to_r2(local_dir, prefix=""):
    print(f"\n[*] Scanning {local_dir} for files...")
    tasks = []
    
    for root, dirs, files in os.walk(local_dir):
        for file in files:
            local_path = os.path.join(root, file)
            relative_path = os.path.relpath(local_path, local_dir)
            s3_key = os.path.join(prefix, relative_path).replace("\\", "/")
            
            content_type, _ = mimetypes.guess_type(local_path)
            if content_type is None:
                content_type = 'application/octet-stream'
                
            tasks.append((local_path, s3_key, content_type))
            
    total_files = len(tasks)
    print(f"[*] Found {total_files} files to upload.")
    
    if total_files == 0:
        return
        
    client = get_r2_client()
    completed = 0
    failed = 0
    
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {
            executor.submit(upload_single_file, client, t[0], BUCKET_NAME, t[1], t[2]): t 
            for t in tasks
        }
        
        for future in as_completed(futures):
            success, result = future.result()
            if success:
                completed += 1
            else:
                failed += 1
                print(f"[!] Failed to upload: {result}")
                
            # Log progress every 1000 files
            if (completed + failed) % 1000 == 0:
                print(f"Progress: {completed + failed} / {total_files} (Failed: {failed})")

    duration = time.time() - start_time
    print(f"[+] Finished uploading {local_dir}. Uploaded: {completed}, Failed: {failed}. Time: {duration:.2f}s")

if __name__ == "__main__":
    print("Starting Multi-threaded Cloudflare R2 Asset Upload Pipeline...")
    
    dirs_to_upload = [
        ("temp_downloads/mushaf", "mushaf/"),
        ("temp_downloads/audio/reciters", "audio/reciters/"),
        ("temp_downloads/audio/adhan", "audio/adhan/"),
        ("temp_downloads/hadith", "hadith/"),
        ("temp_downloads/books", "books/"),
        ("temp_downloads/tafsir_api", "tafsir/")
    ]
    
    for local_dir, prefix in dirs_to_upload:
        if os.path.exists(local_dir):
            upload_directory_to_r2(local_dir, prefix)
        else:
            print(f"[-] Directory {local_dir} not found. Skipping...")
            
    print("All configured directories processed.")
