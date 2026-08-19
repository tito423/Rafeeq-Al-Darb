import urllib.request
import ssl

urls = [
    'https://raw.githubusercontent.com/quran/quran.com-images/master/width_1024/page001.png',
    'https://raw.githubusercontent.com/quran/quran.com-images/master/width_1024/page1.png',
    'https://quran-images-api.herokuapp.com/show/page/1',
    'https://everyayah.com/data/images_png/page1.png',
    'https://everyayah.com/data/images_png/page_001.png'
]

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

for u in urls:
    try:
        req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx) as r:
            print(f"OK: {u} (status {r.status})")
    except Exception as e:
        print(f"ERR: {u} -> {e}")
