"""Host the adhkar recordings that passed scripts/verify_adhkar_recordings.py
on R2, the way the five archive.org ones were on 2026-10-02 (owner: host on
R2 whatever the app takes from archive.org - archive.org is slow).

Usage: py -3 scripts/upload_adhkar_recordings.py name/part [name/part ...]
Uploads E:\\DevEnv\\adhkar_verify\\<name>_<part>.mp3 (the very bytes the
verification transcribed) to azkar/recitations/<name>_<part>.mp3, then reads
each back from the public endpoint with curl (trap #19: a bare urllib gets
403) and checks the size.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from r2_common import BUCKET, r2_client  # noqa: E402

sys.stdout.reconfigure(encoding='utf-8')
CACHE = r'E:\DevEnv\adhkar_verify'
PUBLIC = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'


def main(keys):
    s3 = r2_client()
    for k in keys:
        name, part = k.split('/')
        src = os.path.join(CACHE, f'{name}_{part}.mp3')
        key = f'azkar/recitations/{name}_{part}.mp3'
        size = os.path.getsize(src)
        s3.upload_file(src, BUCKET, key, ExtraArgs={'ContentType': 'audio/mpeg'})
        head = subprocess.run(
            ['curl', '-sI', '-m', '60', f'{PUBLIC}/{key}'],
            capture_output=True, text=True).stdout
        length = next((ln.split(':', 1)[1].strip() for ln in head.splitlines()
                       if ln.lower().startswith('content-length')), '?')
        code = head.split('\n', 1)[0].strip()
        ok = str(size) == length
        print(f'{key} {size} B -> {code} len={length} {"OK" if ok else "MISMATCH"}', flush=True)
        if not ok:
            sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1:])
