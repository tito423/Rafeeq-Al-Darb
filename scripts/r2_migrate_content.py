import hashlib
import boto3
import requests

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
GH_BASE = 'https://raw.githubusercontent.com/tito423/rafeeq-api/master'

CONTENT_TYPES = {
    '.zip': 'application/zip',
    '.json': 'application/json',
    '.mp4': 'video/mp4',
}

FILES = [
    'hadith/hadith.zip',
    'books/text/al_fawaid.json',
    'books/text/al_ubudiyyah.json',
    'books/text/mukhtasar_minhaj_al_qasidin.json',
    'books/text/riyad_as_salihin.json',
    'books/text/sayd_al_khatir.json',
    'adhan/video/haram_makkah.mp4',
    'adhan/video/kaaba.mp4',
    'adhan/video/madina_nabawi.mp4',
    'adhan/video/mosque_ottoman.mp4',
    'adhan/video/mosque_prayer.mp4',
]

results = []
for key in FILES:
    url = f'{GH_BASE}/{key}'
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    data = r.content
    sha = hashlib.sha256(data).hexdigest()
    ext = '.' + key.rsplit('.', 1)[1]
    ctype = CONTENT_TYPES.get(ext, 'application/octet-stream')
    s3.put_object(Bucket=BUCKET, Key=key, Body=data, ContentType=ctype)
    results.append((key, len(data), sha))
    print(f'uploaded {key}  {len(data)} bytes  sha256={sha[:12]}...')

print()
print('--- verify via S3 head_object ---')
for key, size, sha in results:
    head = s3.head_object(Bucket=BUCKET, Key=key)
    ok = head['ContentLength'] == size
    print(f'{key}: R2 size={head["ContentLength"]} expected={size} {"OK" if ok else "MISMATCH!!"}')
