"""Measure the download size of every whole-surah recitation in reciters_full.json.

    py -3 scripts/measure_full_recitation_sizes.py

mp3quran's serverN folders used to answer with an nginx index listing every
file's size; on 2026-10-02 they began to 301 to cdn.mp3quran.net, which has
no listings. So each surah file is asked for its size (a 1-byte range
request; Content-Range carries the total) and a reciter's size is the sum
over the surahs that moshaf actually has (its surah_list) - read off the
server, not estimated from a bitrate.
A moshaf whose listing cannot be read, or which misses a listed surah, is
written WITHOUT a size (the app then shows none) and printed.

Writes rafeeq_app/assets/data/catalogs/full_recitation_sizes.json:
  {"measured": ISO time, "source": ..., "bytes": {server_url: total}}
"""
import concurrent.futures as cf
import datetime
import json
import os
import re
import sys
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'catalogs')
ROW = re.compile(r'<a href="(\d{3})\.mp3">\d{3}\.mp3</a>\s+\S+\s+\S+\s+(\d+)')


def listing(server):
    req = urllib.request.Request(server, headers={'User-Agent': 'Mozilla/5.0 (RafeeqAlDarb size check)'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return {int(n): int(b) for n, b in ROW.findall(r.read().decode('utf-8', 'replace'))}


def size_of(url):
    for _ in range(4):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (RafeeqAlDarb size check)', 'Range': 'bytes=0-0'})
            with urllib.request.urlopen(req, timeout=60) as r:
                cr = r.headers.get('Content-Range', '')
                if '/' in cr:
                    return int(cr.rsplit('/', 1)[1])
                return int(r.headers['Content-Length'])
        except Exception:  # noqa: BLE001 - retried, then reported
            continue
    return None


def measure(m):
    want = [int(x) for x in str(m['surah_list']).split(',') if x.strip()]
    with cf.ThreadPoolExecutor(8) as ex:
        sizes = list(ex.map(lambda s: size_of(f"{m['server']}{s:03d}.mp3"), want))
    missing = [s for s, b in zip(want, sizes) if b is None]
    if missing:
        return m['server'], None, f'{len(missing)} surahs without a size, e.g. {missing[:5]}'
    return m['server'], sum(sizes), None


def main():
    reciters = json.load(open(os.path.join(CAT, 'reciters_full.json'), encoding='utf-8'))
    moshafs = [m for r in reciters for m in r['moshaf']]
    out, bad = {}, []
    with cf.ThreadPoolExecutor(4) as ex:
        for server, total, err in ex.map(measure, moshafs):
            if total is not None:
                out[server] = total
            else:
                bad.append((server, err))
    json.dump({'measured': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ'),
               'source': 'mp3quran.net, one 1-byte range request per surah file (Content-Range total), summed over each moshaf\'s surah_list',
               'bytes': dict(sorted(out.items()))},
              open(os.path.join(CAT, 'full_recitation_sizes.json'), 'w', encoding='utf-8'), indent=1)
    print(f'{len(out)} of {len(moshafs)} moshafs measured, {sum(out.values()) / 1e9:.1f} GB in all')
    for s, e in bad:
        print('NO SIZE', s, e)


if __name__ == '__main__':
    main()
