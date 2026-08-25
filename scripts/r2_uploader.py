import os
import boto3
from botocore.client import Config

# Cloudflare R2 Credentials
R2_ACCOUNT_ID = 'e8edfc13bb53ce91a561113de8f080ed'
R2_ACCESS_KEY_ID = 'c13c77ebfc7750fc3de780b48dbcc00e'
R2_SECRET_ACCESS_KEY = 'a84aeb272ab31776999a4c52f6f1c4df2e96495d43eec3e4f3c7e75cc8cf1689'
BUCKET_NAME = 'rafeeq'
PUBLIC_URL = 'https://pub-b9273af6154c4a618f813447e8a9fc09.r2.dev'

s3 = boto3.client('s3',
  endpoint_url=f'https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com',
  aws_access_key_id=R2_ACCESS_KEY_ID,
  aws_secret_access_key=R2_SECRET_ACCESS_KEY,
  config=Config(signature_version='s3v4'),
  verify=False,
)

def upload_folder(folder_path, prefix=''):
    for filename in os.listdir(folder_path):
        if filename.endswith(".json"):
            file_path = os.path.join(folder_path, filename)
            object_name = f"books/texts/{filename}"
            print(f"Uploading {filename} to {object_name}...")
            
            s3.upload_file(
                file_path, 
                BUCKET_NAME, 
                object_name,
                ExtraArgs={'ContentType': 'application/json; charset=utf-8'}
            )
            
            download_url = f"{PUBLIC_URL}/{object_name}"
            print(f"File accessible at: {download_url}")

if __name__ == "__main__":
    scraped_dir = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\scripts\scraped_books"
    if os.path.exists(scraped_dir):
        upload_folder(scraped_dir)
    else:
        print(f"Directory {scraped_dir} not found.")
