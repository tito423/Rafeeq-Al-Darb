import urllib.request
import json
import ssl
import os

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

books = {
    'tirmidhi': 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-tirmidhi.json',
    'nasai': 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-nasai.json',
    'ibnmajah': 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-ibnmajah.json'
}

dest_dir = 'assets/data/hadith'
os.makedirs(dest_dir, exist_ok=True)

for name, url in books.items():
    file_path = os.path.join(dest_dir, f'{name}.json')
    if os.path.exists(file_path) and os.path.getsize(file_path) > 100000:
        print(f'{name}.json already exists ({os.path.getsize(file_path)} bytes), skipping download.')
        continue
    print(f'Downloading {name} from {url}...')
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            content = resp.read()
            with open(file_path, 'wb') as f:
                f.write(content)
        print(f'Successfully downloaded {name}.json ({len(content)} bytes)')
    except Exception as e:
        print(f'Error downloading {name}: {e}')

print('Done!')
