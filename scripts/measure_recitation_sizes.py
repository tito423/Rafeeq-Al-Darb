"""Measure the real download size of every per-ayah reciter the app offers.

Stage 1 of PLAN.md shows each reciter's full size on the first-run
«التحميلات المبدئية» page, and recommends the smallest. The sizes must be
measured, never typed: this reads every folder's everyayah.com listing,
whose rows carry each file's exact byte count (`<td data-order="26624">`,
checked 2026-09-24 on Ibrahim_Akhdar_32kbps), and sums the 6,236
`SSSAAA.mp3` files. A folder missing any ayah is reported and left out -
a size for a reciter that cannot be fully downloaded would be a false claim.

The R2 mirrors under recitations/ayah/<folder>/ are byte-for-byte copies of
the same folders (r2_mirror_recitations.py checks each byte count), so the
everyayah figure is the figure for both hosts.

Run:  py -3 scripts/measure_recitation_sizes.py
Writes rafeeq_app/assets/data/catalogs/ayah_recitation_sizes.json
"""
import datetime
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DART = ROOT / 'rafeeq_app/lib/core/services/recitation_source.dart'
OUT = ROOT / 'rafeeq_app/assets/data/catalogs/ayah_recitation_sizes.json'
TOTAL_AYAHS = 6236

ROW = re.compile(
    r'<span class="name">(\d{6})\.mp3</span>.*?<td data-order="(\d+)">',
    re.S)


def expected():
    src = (ROOT / 'rafeeq_app/lib/features/quran_audio/data/'
           'ayah_recitation_library.dart').read_text(encoding='utf-8')
    block = src[src.index('_ayahCounts = ['):]
    block = block[block.index('\n'):block.index('];')]
    counts = [int(n) for n in re.findall(r'\b(\d+)\b', re.sub(r'//.*', '', block))]
    assert counts[0] == 0 and len(counts) == 115 and sum(counts) == TOTAL_AYAHS
    return {f'{s:03d}{a:03d}' for s in range(1, 115)
            for a in range(1, counts[s] + 1)}


EXPECTED = expected()


def folders():
    src = DART.read_text(encoding='utf-8')
    block = src[src.index('_everyAyahFolders = {'):]
    block = block[:block.index('};')]
    return dict(re.findall(r"'(ar\.[\w]+)'\s*:\s*'([^']+)'", block))


def measure(folder):
    req = urllib.request.Request(
        f'https://everyayah.com/data/{folder}/',
        headers={'User-Agent': 'RafeeqAlDarb-size-check (+https://github.com/tito423/Rafeeq-Al-Darb)'})
    html = urllib.request.urlopen(req, timeout=120).read().decode('utf-8')
    sizes = {name: int(b) for name, b in ROW.findall(html)
             if name in EXPECTED and int(b) > 0}
    return len(sizes), sum(sizes.values())


def main():
    out = {}
    for edition, folder in sorted(folders().items()):
        try:
            n, total = measure(folder)
        except Exception as e:  # noqa: BLE001 - report and move on
            print(f'FAIL {edition} {folder}: {e}', file=sys.stderr)
            continue
        ok = n == TOTAL_AYAHS
        print(f'{"ok  " if ok else "GAP "}{edition:32} {folder:45} '
              f'{n:5} files {total / 1e6:9.1f} MB')
        if ok:
            out[edition] = total
    OUT.write_text(json.dumps({
        'measured': datetime.datetime.now(datetime.timezone.utc)
                    .strftime('%Y-%m-%dT%H:%MZ'),
        'source': 'everyayah.com folder listings, sum of 6236 SSSAAA.mp3',
        'bytes': out,
    }, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    print(f'wrote {len(out)} reciters to {OUT}')


if __name__ == '__main__':
    main()
