"""P3-43 #16 (2026-09-05): uploads the 3 new book-text editions
(qasr_al_amal, al_hasanah_wa_al_sayyiah, adab_al_nafs) to R2, the same way
scripts/r2_upload_new_books.py did for the previous 3 (P3-15) — kept as its
own dated script rather than editing that one, so each upload batch stays a
distinct, honest historical record.
"""

import hashlib
import boto3

env = {}
with open(r'E:\My Projects\Rafiq-Al-Darb\scripts\.env') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            env[k] = v

s3 = boto3.client('s3',
    endpoint_url=env['R2_ENDPOINT'],
    aws_access_key_id=env['R2_ACCESS_KEY_ID'],
    aws_secret_access_key=env['R2_SECRET_ACCESS_KEY'],
    region_name='auto')

BUCKET = 'rafeeq-content'
IDS = ['qasr_al_amal', 'al_hasanah_wa_al_sayyiah', 'adab_al_nafs']

for book_id in IDS:
    path = rf'E:\My Projects\Rafiq-Al-Darb\scripts\book_text_build\{book_id}.json'
    with open(path, 'rb') as f:
        data = f.read()
    key = f'books/text/{book_id}.json'
    s3.put_object(Bucket=BUCKET, Key=key, Body=data, ContentType='application/json')
    sha = hashlib.sha256(data).hexdigest()
    print(f'uploaded {key}  {len(data)} bytes  sha256={sha[:12]}...')

print()
print('--- verify ---')
for book_id in IDS:
    key = f'books/text/{book_id}.json'
    head = s3.head_object(Bucket=BUCKET, Key=key)
    print(f'{key}: R2 size={head["ContentLength"]}')
