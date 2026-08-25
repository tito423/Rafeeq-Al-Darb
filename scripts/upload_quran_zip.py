import boto3
from botocore.client import Config
import os

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

zip_file = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\quran\quran_images.zip"
object_name = "quran_assets/quran_images.zip"

print(f"Uploading {zip_file} to {object_name}...")
s3.upload_file(
    zip_file, 
    BUCKET_NAME, 
    object_name,
    ExtraArgs={'ContentType': 'application/zip'}
)
print(f"Uploaded successfully! URL: {PUBLIC_URL}/{object_name}")
