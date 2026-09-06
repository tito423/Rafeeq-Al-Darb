"""P3-53: rehost the colored Tajweed mushaf (604 pages) to R2 so the app has a
stable, first-party source for the new Tajweed edition instead of depending on
a third-party GitHub repo that could disappear.

Source: github.com/Imomzoda8/tajweed-quran-images (page_NNN.jpg, 1..604) — the
classic Dar Al-Maarifa colored-tajweed typesetting. Streams each page straight
from GitHub raw into R2 at mushaf/tajweed/NNN.jpg (no local hoard), skips pages
already present at the right-ish size (resumable), and head_object-verifies.
"""

import io
import os
import sys
import time
import urllib.request

import boto3
from botocore.exceptions import ClientError

SRC = "https://raw.githubusercontent.com/Imomzoda8/tajweed-quran-images/main/page_{:03d}.jpg"
DST_KEY = "mushaf/tajweed/{:03d}.jpg"
FIRST, LAST = 1, 604

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
        return h["ContentLength"] > 10000
    except ClientError:
        return False


uploaded = 0
skipped = 0
failed = []
for page in range(FIRST, LAST + 1):
    key = DST_KEY.format(page)
    if already_there(key):
        skipped += 1
        continue
    url = SRC.format(page)
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "rafeeq-uploader"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = resp.read()
            if len(data) < 10000:
                raise ValueError(f"too small ({len(data)} bytes)")
            s3.put_object(
                Bucket=BUCKET, Key=key, Body=data, ContentType="image/jpeg"
            )
            uploaded += 1
            if page % 25 == 0 or page == LAST:
                print(f"  page {page}/{LAST} ok ({len(data)} bytes)", flush=True)
            break
        except Exception as e:  # noqa: BLE001
            if attempt == 2:
                failed.append(page)
                print(f"  FAILED page {page}: {e}", flush=True)
            else:
                time.sleep(1.5)

print(f"\nuploaded={uploaded} skipped={skipped} failed={len(failed)}", flush=True)
if failed:
    print("failed pages:", failed, flush=True)
    sys.exit(1)

# Final spot-verify a few pages actually resolve on the public endpoint shape.
print("--- head verify sample ---", flush=True)
for p in (1, 2, 300, 604):
    h = s3.head_object(Bucket=BUCKET, Key=DST_KEY.format(p))
    print(f"page {p}: {h['ContentLength']} bytes", flush=True)
print("DONE", flush=True)
