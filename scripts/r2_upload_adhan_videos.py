"""P3-48: uploads the new adhan background videos (curated copyright-free
Pixabay clips, Pixabay Content License — free for commercial use, no
attribution required) to R2 under adhan/video/<id>.mp4, then verifies each
with head_object. The clips themselves were downloaded to the session
scratchpad and passed here by path; this script only uploads + verifies.
"""

import os
import sys

import boto3

# id -> local file path
VIDEOS = {
    "kaaba_tawaf": sys.argv[1] if len(sys.argv) > 1 else None,
}

VID_DIR = os.environ.get("VID_DIR")
if not VID_DIR or not os.path.isdir(VID_DIR):
    print("Set VID_DIR to the folder holding <id>.mp4 files")
    sys.exit(1)

IDS = [
    "kaaba_tawaf",
    "haram_makkah2",
    "kaaba_close",
    "madina_haram",
    "mosque_minaret",
    "mosque_view",
]

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

sizes = {}
for vid in IDS:
    path = os.path.join(VID_DIR, f"{vid}.mp4")
    if not os.path.exists(path):
        print("MISSING", path)
        continue
    with open(path, "rb") as fh:
        data = fh.read()
    s3.put_object(
        Bucket=BUCKET,
        Key=f"adhan/video/{vid}.mp4",
        Body=data,
        ContentType="video/mp4",
    )
    sizes[vid] = len(data)
    print(f"uploaded {vid} ({len(data)} bytes)")

print("\n--- verify ---")
for vid in IDS:
    if vid not in sizes:
        continue
    head = s3.head_object(Bucket=BUCKET, Key=f"adhan/video/{vid}.mp4")
    ok = head["ContentLength"] == sizes[vid]
    print(f"{vid}: r2={head['ContentLength']} local={sizes[vid]} {'OK' if ok else 'MISMATCH'}")

# Emit the Dart approxSizeBytes lines for the catalog.
print("\n--- sizes for catalog ---")
for vid in IDS:
    if vid in sizes:
        print(f"{vid} = {sizes[vid]}")
