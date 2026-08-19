import urllib.request
import json
import os

# URLs for Arabic editions from fawazahmed0/hadith-api
DATASETS = {
    'bukhari': 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-bukhari.json',
    'muslim': 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-muslim.json',
    'abudawud': 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-abudawud.json'
}

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'hadith')

import ssl

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    for name, url in DATASETS.items():
        print(f"Downloading {name} from {url}...")
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, context=ctx) as response:
                data = json.loads(response.read().decode('utf-8'))
                
            out_file = os.path.join(OUTPUT_DIR, f'{name}.json')
            with open(out_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"Successfully saved {name} to {out_file}")
        except Exception as e:
            print(f"Failed to download {name}: {e}")

if __name__ == '__main__':
    main()
