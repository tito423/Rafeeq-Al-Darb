import os
import shutil
import boto3
from botocore.config import Config
import time

# R2 Configuration
R2_ENDPOINT = 'https://33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com'
ACCESS_KEY = '0ea932e392ce7b96cb81e8b4132a26d9'
SECRET_KEY = 'a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad'
BUCKET_NAME = 'rafeeq-aldarb-data'

s3 = boto3.client('s3',
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
    region_name='auto',
    config=Config(s3={'addressing_style': 'path'})
)

MUSHAF_DIR = r"E:\My Projects\Rafiq-Al-Darb\rafeeq-api\mushaf"
OUTPUT_DIR = "temp_zips_mushafs"

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # List all mushaf folders
    mushaf_folders = [f for f in os.listdir(MUSHAF_DIR) if os.path.isdir(os.path.join(MUSHAF_DIR, f)) and f != "thumbs"]
    
    print(f"Found {len(mushaf_folders)} Mushaf variants to zip and upload.")
    
    total_uploaded = 0
    
    for folder_name in mushaf_folders:
        dir_path = os.path.join(MUSHAF_DIR, folder_name)
        zip_name = f"mushaf_{folder_name}"
        zip_path = os.path.join(OUTPUT_DIR, zip_name)
        zip_file_with_ext = f"{zip_path}.zip"
        
        # Check if it's already uploaded (like madani_1024)
        if folder_name == "madani_1024":
            print(f"Skipping {folder_name} (Already uploaded as mushaf_madani.zip).")
            continue
            
        print(f"[{time.strftime('%X')}] Zipping {dir_path} into {zip_file_with_ext}...")
        
        shutil.make_archive(zip_path, 'zip', dir_path)
        
        size = os.path.getsize(zip_file_with_ext)
        print(f"[{time.strftime('%X')}] Size of {zip_file_with_ext}: {size / 1024 / 1024:.2f} MB")
        
        print(f"[{time.strftime('%X')}] Uploading {zip_file_with_ext} to R2 bucket {BUCKET_NAME}...")
        
        try:
            s3.upload_file(zip_file_with_ext, BUCKET_NAME, f"{zip_name}.zip")
            print(f"[{time.strftime('%X')}] Successfully uploaded {zip_name}.zip")
            total_uploaded += 1
        except Exception as e:
            print(f"Failed to upload {zip_name}.zip: {e}")
            
    print(f"\nAll {total_uploaded} missing Mushafs have been uploaded to Cloudflare R2!")

if __name__ == "__main__":
    main()
