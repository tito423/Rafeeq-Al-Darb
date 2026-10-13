"""Upload the 302 per-dhikr voice files to R2 and verify them publicly.

Source: scripts/out/azkar_voice/items/<id>.mp3 with items.json (seconds,
bytes, sha1), built by azkar_voice_all.py and azkar_voice_138.py.
Target: azkar/rafeeq_voice/items/v1/<id>.mp3 on rafeeq-content. Each object
is checked after upload (size and sha1 of the bytes read back from the
public r2.dev URL), then rafeeq_app/assets/data/azkar_voice.json is written:
id -> {seconds, bytes} for the app.

    py -3 scripts/upload_azkar_voice_items.py      (from the repo root)
"""
import hashlib, json, os, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import r2_common  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'scripts', 'out', 'azkar_voice')
PREFIX = 'azkar/rafeeq_voice/items/v1/'
PUBLIC = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/'
APP_JSON = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'azkar_voice.json')


def main():
    items = json.load(open(os.path.join(SRC, 'items.json'), encoding='utf-8'))
    s3 = r2_client = r2_common.r2_client()
    existing = {}
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket='rafeeq-content', Prefix=PREFIX):
        for o in page.get('Contents', []):
            existing[o['Key']] = o['Size']
    bad = []
    for n, (iid, meta) in enumerate(sorted(items.items(), key=lambda kv: int(kv[0])), 1):
        path = os.path.join(SRC, 'items', f'{iid}.mp3')
        data = open(path, 'rb').read()
        if len(data) != meta['bytes'] or hashlib.sha1(data).hexdigest() != meta['sha1']:
            bad.append((iid, 'local file differs from items.json'))
            continue
        key = f'{PREFIX}{iid}.mp3'
        if existing.get(key) != len(data):
            s3.put_object(Bucket='rafeeq-content', Key=key, Body=data, ContentType='audio/mpeg',
                          CacheControl='public, max-age=31536000, immutable')
        req = urllib.request.Request(PUBLIC + key, headers={'User-Agent': 'RafeeqAlDarb (tito423 on GitHub)'})
        got = urllib.request.urlopen(req, timeout=120, context=None).read()
        if len(got) != len(data) or hashlib.sha1(got).hexdigest() != meta['sha1']:
            bad.append((iid, f'public copy differs ({len(got)} bytes)'))
        if n % 25 == 0:
            print(f'{n}/{len(items)} verified', flush=True)
    if bad:
        print('FAILED:', bad)
        sys.exit(1)
    out = {'source': PREFIX, 'items': {iid: {'seconds': m['seconds'], 'bytes': m['bytes']}
                                       for iid, m in sorted(items.items(), key=lambda kv: int(kv[0]))}}
    json.dump(out, open(APP_JSON, 'w', encoding='utf-8'), indent=0, separators=(',', ':'))
    print(f'ALL {len(items)} uploaded and verified from the public URL; wrote {APP_JSON}')


if __name__ == '__main__':
    main()
