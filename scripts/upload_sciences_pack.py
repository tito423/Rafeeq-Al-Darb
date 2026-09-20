"""Pack `quran_sciences.db` and put it on R2 as a downloadable content pack.

Stage two of «تصغير التطبيق». The database is 131.68 MB of the APK's 246.67
MB of bundled assets - seven tafsirs, six translations, 75,973 i'rab rows and
83,665 word meanings - and deflate takes it to about 32 MB, so it leaves the
install and becomes a download.

The archive is named `quran_sciences.zip` on purpose. `DownloadManager.
_unzipToDatabases` writes `basename(zip) + '.db'` and ignores what the entry
inside is called (trap #27 in CLAUDE.md: the HadeethEnc packs were saved as
`ar.zip`, unpacked to `ar.db`, and the tab sat on its download button for
ever). Naming the archive after the database it becomes is what keeps the
two from drifting.

No `ContentEncoding` is set - trap #6: Dio unpacks a gzip-labelled response
transparently, the stored file is then the wrong size, and the install check
fails for ever.

    py -3 scripts/upload_sciences_pack.py            # build + upload + verify
    py -3 scripts/upload_sciences_pack.py --check    # verify what is there
"""
import os
import sys
import time
import zipfile

sys.path.insert(0, 'scripts')
from r2_common import r2_client  # noqa: E402

BUCKET = 'rafeeq-content'
KEY = 'sciences/quran_sciences.zip'
PUBLIC = ('https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/' + KEY)
SRC = os.path.join('rafeeq_app', 'assets', 'data', 'quran_sciences.db')
ZIP = os.path.join('build', 'quran_sciences.zip')
UA = 'RafeeqAlDarb/3.45 (https://github.com/tito423/Rafeeq-Al-Darb)'


def check(client) -> int:
    """Range-request the real object the way the app will fetch it."""
    head = client.head_object(Bucket=BUCKET, Key=KEY)
    got = client.get_object(Bucket=BUCKET, Key=KEY, Range='bytes=0-1')
    magic = got['Body'].read()
    print('%s  %d bytes  %s' % (KEY, head['ContentLength'],
                                head.get('ContentType')))
    print('first two bytes: %r (a zip starts PK)' % magic)
    print('ContentEncoding: %r (must be None - trap #6)'
          % head.get('ContentEncoding'))
    ok = magic == b'PK' and head.get('ContentEncoding') is None
    print('public url: %s' % PUBLIC)
    return 0 if ok else 1


def main() -> int:
    client = r2_client()
    if '--check' in sys.argv:
        return check(client)

    if not os.path.exists(SRC):
        print('missing %s' % SRC)
        return 1
    os.makedirs(os.path.dirname(ZIP), exist_ok=True)

    raw = os.path.getsize(SRC)
    t = time.time()
    with zipfile.ZipFile(ZIP, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(SRC, arcname='quran_sciences.db')
    packed = os.path.getsize(ZIP)
    print('%.2f MB -> %.2f MB in %.0fs' % (raw / 1048576, packed / 1048576,
                                           time.time() - t))

    # Read it back before uploading: a zip that does not open is not a pack.
    with zipfile.ZipFile(ZIP) as z:
        names = z.namelist()
        info = z.getinfo('quran_sciences.db')
    print('entries: %s, uncompressed %d bytes' % (names, info.file_size))
    if names != ['quran_sciences.db'] or info.file_size != raw:
        print('the archive does not hold exactly the source database')
        return 1

    t = time.time()
    client.upload_file(ZIP, BUCKET, KEY,
                       ExtraArgs={'ContentType': 'application/zip'})
    print('uploaded in %.0fs' % (time.time() - t))
    return check(client)


if __name__ == '__main__':
    raise SystemExit(main())
