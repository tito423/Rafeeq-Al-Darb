import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# Test fetching sample word meanings or asbab from public authoritative quran endpoints
endpoints = [
    ("quran_api_asbab", "https://raw.githubusercontent.com/risan/quran-json/main/dist/quran.json"),
    ("word_meanings_api", "https://api.quran.com/api/v4/verses/by_key/1:1?words=true&word_fields=text_uthmani,translation"),
    ("quranenc_translation", "https://quranenc.com/api/v1/translation/sura/french_biography/1"),
]

for name, url in endpoints:
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
            data = response.read()
            print(f"Endpoint {name}: SUCCESS ({len(data)} bytes)")
    except Exception as e:
        print(f"Endpoint {name}: FAILED ({e})")
