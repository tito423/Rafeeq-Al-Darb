import boto3
from botocore.config import Config

R2_ENDPOINT_URL = "https://33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com"
R2_ACCESS_KEY = "0ea932e392ce7b96cb81e8b4132a26d9"
R2_SECRET_KEY = "a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad"
BUCKET_NAME = "rafeeq-aldarb-data"

client = boto3.client(
    's3',
    endpoint_url=R2_ENDPOINT_URL,
    aws_access_key_id=R2_ACCESS_KEY,
    aws_secret_access_key=R2_SECRET_KEY,
    config=Config(signature_version='s3v4'),
    region_name='auto'
)

paginator = client.get_paginator('list_objects_v2')
pages = paginator.paginate(Bucket=BUCKET_NAME)

count = 0
for page in pages:
    if 'Contents' in page:
        count += len(page['Contents'])

print(f"Total uploaded files in R2 bucket '{BUCKET_NAME}': {count}")
