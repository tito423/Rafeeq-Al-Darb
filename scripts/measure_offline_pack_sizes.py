"""Measure, from the bucket itself, the packs the first-run page offers.

«التحميلات المبدئية» (PLAN.md Stage 1) shows each pack's size and a total;
every figure there must be measured. This lists the R2 folders (one
list_objects_v2 page per 1,000 objects) and sums their real byte counts:

- mushaf/madinah_qc/            the paper mushaf, 604 pages
- recitations/surah/<slug>/     the two whole recitations mirrored on R2

A folder that does not hold exactly the files the app fetches is reported
and left out, never rounded into a figure.

Run:  py -3 scripts/measure_offline_pack_sizes.py
Writes rafeeq_app/assets/data/catalogs/offline_pack_sizes.json
"""
import datetime
import json
import pathlib
import re

from r2_common import BUCKET, r2_client

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'rafeeq_app/assets/data/catalogs/offline_pack_sizes.json'

# prefix -> (key regex of the files the app fetches, how many there must be)
FOLDERS = {
    'mushaf/madinah_qc/': (r'^\d{3}\.(?:png|jpg|webp)$', 604),
    'recitations/surah/basit_murattal/': (r'^\d{3}\.mp3$', 114),
    'recitations/surah/maher_murattal/': (r'^\d{3}\.mp3$', 114),
}


def main():
    s3 = r2_client()
    out = {}
    for prefix, (pattern, want) in FOLDERS.items():
        rx = re.compile(pattern)
        files = {}
        for page in s3.get_paginator('list_objects_v2').paginate(
                Bucket=BUCKET, Prefix=prefix):
            for o in page.get('Contents', []):
                name = o['Key'][len(prefix):]
                if rx.match(name) and o['Size'] > 0:
                    files[name] = o['Size']
        total = sum(files.values())
        ok = len(files) == want
        print(f'{"ok  " if ok else "GAP "}{prefix:40} {len(files):4}/{want} '
              f'{total / 1e6:8.1f} MB')
        if ok:
            out[prefix.rstrip('/')] = total
    OUT.write_text(json.dumps({
        'measured': datetime.datetime.now(datetime.timezone.utc)
                    .strftime('%Y-%m-%dT%H:%MZ'),
        'source': f'R2 bucket {BUCKET}, list_objects_v2 sizes',
        'bytes': out,
    }, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    print(f'wrote {len(out)} packs to {OUT}')


if __name__ == '__main__':
    main()
