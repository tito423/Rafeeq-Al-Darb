import os
import boto3
from botocore.config import Config
import time

# R2 Configuration
R2_ENDPOINT = 'https://33946f20ace0d8aa2aba052fa705d685.r2.cloudflarestorage.com'
ACCESS_KEY = '0ea932e392ce7b96cb81e8b4132a26d9'
SECRET_KEY = 'a117398b232c11b17b9bebd497131bf8b0497791b20a5f02ada8558cbc1427ad'
BUCKET_NAME = 'rafeeq-aldarb-data'

def main():
    s3 = boto3.client('s3',
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name='auto',
        config=Config(s3={'addressing_style': 'path'})
    )

    audio_zip_path = r'temp_zips\audio.zip'
    if not os.path.exists(audio_zip_path):
        print("audio.zip not found!")
        return

    print(f"Retrying upload for {audio_zip_path}...")
    try:
        s3.upload_file(audio_zip_path, BUCKET_NAME, 'audio.zip')
        print("Successfully uploaded audio.zip")
    except Exception as e:
        print(f"Failed to upload audio.zip: {e}")

if __name__ == '__main__':
    main()
