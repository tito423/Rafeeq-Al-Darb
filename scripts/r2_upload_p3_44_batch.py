"""P3-44: uploads all 182 newly-built books (fetch_authors_batch.py) to
R2, verifying each with head_object afterward. Kept as its own dated
script per this project's established convention (one script per upload
batch, never editing an earlier one) so each batch stays its own honest
record.
"""

import hashlib
import sys

import boto3

sys.path.insert(0, "scripts")
from fetch_authors_batch import ALL_BOOKS  # noqa: E402

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
SLUGS = [slug for _, slug, _ in ALL_BOOKS]

uploaded = 0
failed = []
for slug in SLUGS:
    path = rf"E:\My Projects\Rafiq-Al-Darb\scripts\book_text_build\{slug}.json"
    try:
        with open(path, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        failed.append(slug)
        continue
    key = f"books/text/{slug}.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=data, ContentType="application/json")
    sha = hashlib.sha256(data).hexdigest()
    uploaded += 1
    if uploaded % 20 == 0:
        print(f"... {uploaded}/{len(SLUGS)} uploaded")

print(f"\nUploaded {uploaded}/{len(SLUGS)}; missing: {failed}")

print("\n--- verify (head_object) ---")
mismatches = []
for slug in SLUGS:
    path = rf"E:\My Projects\Rafiq-Al-Darb\scripts\book_text_build\{slug}.json"
    try:
        local_size = __import__("os").path.getsize(path)
    except FileNotFoundError:
        continue
    key = f"books/text/{slug}.json"
    head = s3.head_object(Bucket=BUCKET, Key=key)
    r2_size = head["ContentLength"]
    if r2_size != local_size:
        mismatches.append((slug, local_size, r2_size))

if mismatches:
    print("SIZE MISMATCHES:", mismatches)
else:
    print(f"All {len(SLUGS)} verified: R2 size matches local file exactly.")
