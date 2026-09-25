"""Second digital copy of al-Da'as's i'rab, one ayah per page, from e-quran.com.

Why a second copy: Shamela 23584 (and tafsir.app, which serves the same
text) is damaged in places - page 234 opens «لَنْ يَسْتَنْكِفَ» as
`'َنْ يَسْتَنْكِفَ الْمَسِيحُ»` with the lines shuffled. e-quran.com serves the
book under the slug `eerab`, the same slug the King Saud University
electronic mushaf (Ayat) uses, and its 4:172 reads clean. It has no bulk
file (its tafseer.js fetches /pages/tafseer/<slug>/<s>/<a>.html), so the
pages are stored verbatim, resumably, and parsed separately.

    py -3 scripts/fetch_irab_daas_equran.py   -> scripts/shamela_raw/irab_daas_equran.jsonl
"""
import io
import json
import os
import queue
import sqlite3
import subprocess
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'scripts', 'shamela_raw', 'irab_daas_equran.jsonl')
QDB = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db')
WORKERS = 6
lock = threading.Lock()


def fetch(s, a):
    url = f'https://e-quran.com/pages/tafseer/eerab/{s}/{a}.html'
    for _ in range(5):
        r = subprocess.run(['curl', '-s', '-L', '--max-time', '60', '-A',
                            'Mozilla/5.0 (rafeeq-al-darb content check)',
                            '-w', '\n%{http_code}', url], capture_output=True)
        body, _, code = r.stdout.rpartition(b'\n')
        if code == b'200' and len(body) > 5000:
            return body.decode('utf-8', 'replace')
    return None


def main():
    counts = sqlite3.connect(QDB).execute(
        'select surah_id, max(ayah_number) from ayahs group by surah_id').fetchall()
    have = set()
    if os.path.exists(OUT):
        for l in io.open(OUT, encoding='utf-8'):
            d = json.loads(l)
            have.add((d['s'], d['a']))
    q = queue.Queue()
    for s, n in counts:
        for a in range(1, n + 1):
            if (s, a) not in have:
                q.put((s, a))
    total = q.qsize()
    print(f'{len(have)} stored, {total} to fetch', flush=True)
    out = io.open(OUT, 'a', encoding='utf-8')
    done = [0]
    failed = []

    def work():
        while True:
            try:
                s, a = q.get_nowait()
            except queue.Empty:
                return
            html = fetch(s, a)
            with lock:
                if html is None:
                    failed.append((s, a))
                else:
                    out.write(json.dumps({'s': s, 'a': a, 'html': html},
                                         ensure_ascii=False) + '\n')
                    out.flush()
                done[0] += 1
                if done[0] % 500 == 0:
                    print(f'  {done[0]}/{total}', flush=True)

    ts = [threading.Thread(target=work) for _ in range(WORKERS)]
    [t.start() for t in ts]
    [t.join() for t in ts]
    print(f'done, failed {len(failed)}: {failed[:20]}', flush=True)


if __name__ == '__main__':
    main()
