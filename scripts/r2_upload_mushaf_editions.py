"""Rehost real, verified per-page mushaf scans to R2 for the raster editions.

Background: `editions.json` had picked up eight raster editions (shamarly,
qatar, amiriya, indo_pak, kazan, muallim, kfqc_new, sahaba) whose pages had
never been uploaded — every page 404'd, so choosing any of them opened an empty
reader. Those entries are removed; this script uploads the editions whose page
images were actually found and verified:

  * warsh  — Riwayat Warsh an Nafi, 604 pages, from the Quran-for-Android
             content host (android.quran.com/data/warsh/width_1024/pageNNN.png)
  * qaloon — Riwayat Qalun an Nafi, 604 pages, same host

Both were probed first (content-type image/png, real byte sizes, first
AND last page present) before being wired into the catalog — no source is
listed in `editions.json` until its pages resolve here.

These pages are palette ("P" mode) PNGs — the right encoding for black-on-white
script, and already small (50-70 KB a page). They are uploaded byte-for-byte
with no transcode: re-encoding them as JPEG made each page roughly 4x LARGER
and smeared the Arabic letterforms with ringing artifacts. The editions
therefore declare `"image_ext": "png"` in `editions.json`, which
`AppConfig.mushafImageUrl` honours (it still defaults to jpg, so the existing
Tajweed edition's real JPEGs are untouched).

Streams upstream -> memory -> R2 with no local hoard, skips pages already
present (so it is resumable), and head_object-verifies a sample at the end.

Usage:  py scripts/r2_upload_mushaf_editions.py [edition ...]
        (no args = both)
"""

import io
import sys
import time
import urllib.request

import boto3
from botocore.exceptions import ClientError
from PIL import Image

# name -> (source URL template, destination folder under mushaf/, page range)
EDITIONS = {
    "warsh": (
        "https://android.quran.com/data/warsh/width_1024/page{:03d}.png",
        "warsh",
        (1, 604),
    ),
    "qaloon": (
        "https://android.quran.com/data/qaloon/width_1024/page{:03d}.png",
        "qaloon",
        (1, 604),
    ),
}

DST_KEY = "mushaf/{}/{:03d}.png"
MIN_BYTES = 5000  # anything smaller upstream is a soft-404 HTML page, not a scan

env = {}
with open(r"E:\My Projects\Rafiq-Al-Darb\scripts\.env") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k] = v

s3 = boto3.client(
    "s3",
    endpoint_url=env["R2_ENDPOINT"],
    aws_access_key_id=env["R2_ACCESS_KEY_ID"],
    aws_secret_access_key=env["R2_SECRET_ACCESS_KEY"],
    region_name="auto",
)
BUCKET = "rafeeq-content"


def already_there(key):
    try:
        h = s3.head_object(Bucket=BUCKET, Key=key)
        return h["ContentLength"] > MIN_BYTES
    except ClientError:
        return False


def verify_png(data):
    """Confirm the bytes really are a decodable image before they go to R2."""
    Image.open(io.BytesIO(data)).verify()


def upload_edition(name):
    src_tpl, folder, (first, last) = EDITIONS[name]
    print(f"\n=== {name} -> mushaf/{folder}/ ({first}..{last}) ===", flush=True)
    uploaded = skipped = 0
    failed = []
    for page in range(first, last + 1):
        key = DST_KEY.format(folder, page)
        if already_there(key):
            skipped += 1
            continue
        url = src_tpl.format(page)
        for attempt in range(3):
            try:
                req = urllib.request.Request(
                    url, headers={"User-Agent": "rafeeq-uploader"}
                )
                with urllib.request.urlopen(req, timeout=60) as resp:
                    raw = resp.read()
                    ctype = resp.headers.get("Content-Type", "")
                # A soft-404 comes back as the host's HTML homepage with a 200.
                if "image" not in ctype or len(raw) < MIN_BYTES:
                    raise ValueError(f"not an image ({ctype}, {len(raw)} bytes)")
                verify_png(raw)
                data = raw
                s3.put_object(
                    Bucket=BUCKET, Key=key, Body=data, ContentType="image/png"
                )
                uploaded += 1
                if page % 50 == 0 or page == last:
                    print(f"  page {page}/{last} ok ({len(data)} bytes)", flush=True)
                break
            except Exception as e:  # noqa: BLE001
                if attempt == 2:
                    failed.append(page)
                    print(f"  FAILED page {page}: {e}", flush=True)
                else:
                    time.sleep(1.5)
    print(
        f"{name}: uploaded={uploaded} skipped={skipped} failed={len(failed)}",
        flush=True,
    )
    if failed:
        print(f"{name} failed pages:", failed, flush=True)
    return failed


def main():
    wanted = sys.argv[1:] or list(EDITIONS)
    bad = [w for w in wanted if w not in EDITIONS]
    if bad:
        sys.exit(f"unknown edition(s): {bad}; known: {list(EDITIONS)}")

    all_failed = {}
    for name in wanted:
        f = upload_edition(name)
        if f:
            all_failed[name] = f

    print("\n--- head verify sample ---", flush=True)
    for name in wanted:
        folder = EDITIONS[name][1]
        for p in (1, 2, 300, 604):
            try:
                h = s3.head_object(Bucket=BUCKET, Key=DST_KEY.format(folder, p))
                print(f"{name} page {p}: {h['ContentLength']} bytes", flush=True)
            except ClientError as e:
                print(f"{name} page {p}: MISSING ({e})", flush=True)

    if all_failed:
        print("\nINCOMPLETE:", all_failed, flush=True)
        sys.exit(1)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
