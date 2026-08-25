import os
import boto3
from botocore.config import Config
import mimetypes

# ==========================================
# Cloudflare R2 Configuration
# ==========================================
R2_ENDPOINT_URL = os.environ.get("R2_ENDPOINT_URL", "https://<ACCOUNT_ID>.r2.cloudflarestorage.com")
R2_ACCESS_KEY = os.environ.get("R2_ACCESS_KEY", "your_access_key")
R2_SECRET_KEY = os.environ.get("R2_SECRET_KEY", "your_secret_key")
BUCKET_NAME = "rafeeq-assets"

def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY,
        aws_secret_access_key=R2_SECRET_KEY,
        config=Config(signature_version='s3v4'),
        region_name='auto'
    )

def upload_directory_to_r2(local_dir, prefix=""):
    client = get_r2_client()
    for root, dirs, files in os.walk(local_dir):
        for file in files:
            local_path = os.path.join(root, file)
            relative_path = os.path.relpath(local_path, local_dir)
            s3_key = os.path.join(prefix, relative_path).replace("\\", "/")
            
            content_type, _ = mimetypes.guess_type(local_path)
            if content_type is None:
                content_type = 'application/octet-stream'
                
            print(f"Uploading {local_path} to R2 as {s3_key}...")
            client.upload_file(
                local_path, 
                BUCKET_NAME, 
                s3_key,
                ExtraArgs={'ContentType': content_type}
            )

if __name__ == "__main__":
    print("Starting Cloudflare R2 Asset Upload Pipeline...")
    
    # Example paths based on requested structure
    # You should have these directories filled with downloaded data before running this
    if os.path.exists("temp_downloads/mushaf"):
        upload_directory_to_r2("temp_downloads/mushaf", "mushaf/")
    
    if os.path.exists("temp_downloads/audio/reciters"):
        upload_directory_to_r2("temp_downloads/audio/reciters", "audio/reciters/")
        
    if os.path.exists("temp_downloads/audio/adhan"):
        upload_directory_to_r2("temp_downloads/audio/adhan", "audio/adhan/")
        
    if os.path.exists("temp_downloads/hadith"):
        upload_directory_to_r2("temp_downloads/hadith", "hadith/")
        
    if os.path.exists("temp_downloads/books"):
        upload_directory_to_r2("temp_downloads/books", "books/")
        
    print("Done uploading assets to Cloudflare R2.")
