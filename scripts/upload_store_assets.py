"""Keep the Play Store listing assets on R2, out of the app.

«شيل الشاشات اللي احنا كنا عاملينها عشان البلاي ستور ... وخليها عندك على
جنب على الار تو ... بحيث لما نيجي نرفع التطبيق على بلاي ستور نلاقيها»
(owner, 2026-09-25). The in-app gallery that showed them was removed the same
day; the picture tour replaced it. The originals stay in git under
store/google_play/ as well - R2 is the second copy.

Uploads store/google_play/** to `store/google_play/...` and the 540x960 JPEGs
the gallery used to `store/google_play/in_app_540/`, then range-requests every
object on the public endpoint (curl: trap #19, a bare urllib gets 403).

    py -3 scripts/upload_store_assets.py
"""
import mimetypes
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/'


def files():
    base = os.path.join(ROOT, 'store', 'google_play')
    for d, _, fs in os.walk(base):
        for f in fs:
            p = os.path.join(d, f)
            yield p, 'store/google_play/' + os.path.relpath(p, base).replace(os.sep, '/')
    shots = os.path.join(ROOT, 'rafeeq_app', 'assets', 'tutorial_shots')
    if os.path.isdir(shots):
        for f in sorted(os.listdir(shots)):
            yield os.path.join(shots, f), 'store/google_play/in_app_540/' + f


def main():
    client = r2_client()
    bad = 0
    for path, key in files():
        ctype = mimetypes.guess_type(path)[0] or 'application/octet-stream'
        if path.endswith('.md'):
            ctype = 'text/markdown; charset=utf-8'
        client.upload_file(path, BUCKET, key, ExtraArgs={'ContentType': ctype})
        r = subprocess.run(['curl', '-s', '-o', os.devnull, '-r', '0-1023', '-w',
                            '%{http_code}', PUBLIC + key], capture_output=True, text=True)
        size = client.head_object(Bucket=BUCKET, Key=key)['ContentLength']
        ok = r.stdout == '206' and size == os.path.getsize(path)
        bad += not ok
        print(f"{'OK ' if ok else 'BAD'} {r.stdout} {size:>9} {key}")
    print('all verified' if not bad else f'{bad} FAILED')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
