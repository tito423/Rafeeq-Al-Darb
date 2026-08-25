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

# Initialize boto3 client for R2
s3 = boto3.client('s3',
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
    region_name='auto',
    config=Config(s3={'addressing_style': 'path'})
)

DIRECTORIES_TO_ZIP = {
    "mushaf_madani": "temp_downloads/mushaf/madani_1024",
    "hadith": "temp_downloads/hadith",
    "audio": "temp_downloads/audio/reciters",
    "tafsir": "temp_downloads/tafsir_api",
    "books": "temp_downloads/books",
}

OUTPUT_DIR = "temp_zips"

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for zip_name, dir_path in DIRECTORIES_TO_ZIP.items():
        if not os.path.exists(dir_path):
            print(f"Skipping {zip_name} - Directory not found: {dir_path}")
            continue
            
        zip_path = os.path.join(OUTPUT_DIR, zip_name)
        zip_file_with_ext = f"{zip_path}.zip"
        
        print(f"[{time.strftime('%X')}] Zipping {dir_path} into {zip_file_with_ext}...")
        
        # Archive it
        shutil.make_archive(zip_path, 'zip', dir_path)
        
        print(f"[{time.strftime('%X')}] Uploading {zip_file_with_ext} to R2 bucket {BUCKET_NAME}...")
        
        try:
            # Blind PUT upload (no HeadObject to save operations)
            s3.upload_file(zip_file_with_ext, BUCKET_NAME, f"{zip_name}.zip")
            print(f"[{time.strftime('%X')}] Successfully uploaded {zip_name}.zip")
            
        except Exception as e:
            print(f"Failed to upload {zip_name}.zip: {e}")

if __name__ == "__main__":
    main()
