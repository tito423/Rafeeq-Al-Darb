"""Prints what other named i'rab books say on an ayah, to chase a doubt about
al-Da'as before writing our entry (CLAUDE.md 1.2): al-Jadwal (Mahmud Safi)
and «إعراب القرآن وبيانه» (Darwish), as tafsir.app serves them. Pages are
cached in scripts/own_irab/books_cache/ (gitignored is not needed - small).

    py -3 scripts/own_irab/books.py 88 5 [word ...]
With words, prints only the passages around them."""
import io, json, os, re, sys, urllib.request

H = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(H, 'books_cache')
SRC = {'aljadwal': 'الجدول (صافي)', 'iraab-aldarweesh': 'درويش'}


def get(src, s, a):
    os.makedirs(CACHE, exist_ok=True)
    f = os.path.join(CACHE, f'{src}_{s}_{a}.json')
    if not os.path.exists(f):
        req = urllib.request.Request(f'https://tafsir.app/get.php?src={src}&s={s}&a={a}',
                                     headers={'User-Agent': 'Mozilla/5.0 (rafeeq-al-darb i\'rab check)'})
        open(f, 'wb').write(urllib.request.urlopen(req, timeout=30).read())
    return json.load(open(f, encoding='utf-8')).get('data', '')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    s, a, words = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3:]
    for src, name in SRC.items():
        t = get(src, s, a)
        print(f'== {name} {s}:{a} ({len(t)} chars)')
        if not words:
            print(t)
        for w in words:
            for m in re.finditer(re.escape(w), t):
                print(f'  [{w}] …{t[max(0, m.start() - 80):m.start() + 280]}…'.replace('\n', ' '))
