"""Upload the quran.com Madinah page images to R2 as the `madinah_qc` mushaf.

604 PNGs at 1260x2038, ~62 MB in all. They replace the 286 MB `hafs_kfqc`
SVG set as the app's one paper mushaf, and their ayah coordinates come from
the same publisher (see `build_madinah_qc_polygons.py`).

NO `ContentEncoding` is ever set (trap #6): a PNG is already compressed, and
an encoding header makes Dio unpack the body transparently, which breaks every
size check the client makes on the stored file.

Usage:  py -3 scripts/upload_madinah_qc_pages.py <pages-dir> [--verify-only]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

PREFIX = 'mushaf/madinah_qc'


def main():
    pages_dir = sys.argv[1]
    verify_only = '--verify-only' in sys.argv
    s3 = r2_client()

    have = {}
    token = None
    while True:
        kw = {'Bucket': BUCKET, 'Prefix': PREFIX + '/', 'MaxKeys': 1000}
        if token:
            kw['ContinuationToken'] = token
        r = s3.list_objects_v2(**kw)
        for o in r.get('Contents', []):
            have[o['Key']] = o['Size']
        if not r.get('IsTruncated'):
            break
        token = r['NextContinuationToken']
    print('already on the bucket: %d objects' % len(have))

    sent = skipped = 0
    total = 0
    for page in range(1, 605):
        name = '%03d.png' % page
        path = os.path.join(pages_dir, name)
        size = os.path.getsize(path)
        total += size
        key = '%s/%s' % (PREFIX, name)
        if have.get(key) == size:
            skipped += 1
            continue
        if verify_only:
            print('MISSING or WRONG SIZE: %s (local %d, remote %s)'
                  % (key, size, have.get(key)))
            continue
        with open(path, 'rb') as f:
            s3.put_object(Bucket=BUCKET, Key=key, Body=f.read(),
                          ContentType='image/png')
        sent += 1
        if sent % 100 == 0:
            print('  sent %d' % sent)

    print('uploaded : %d' % sent)
    print('already  : %d' % skipped)
    print('bytes    : %d (%.1f MB)' % (total, total / 1048576))


main()
