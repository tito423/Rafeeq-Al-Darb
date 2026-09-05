"""P3-44 follow-up: the owner asked to make gzip compression a standing
rule for every book text edition on R2 (real bandwidth savings for a
reader on mobile data — this JSON is heavy on repeated structure and
Arabic text, which compresses very well). Applies it retroactively to
every book already uploaded (the original ~11 curated ones + the 182
from this same session), not just future ones.

For each local scripts/book_text_build/<slug>.json:
  1. gzip-compress it (same content, same R2 key — the app's own
     `BookText.fromFile` now detects gzip by magic bytes, not the
     filename, and still handles a plain-JSON file exactly as before,
     so this is safe to roll out without breaking anything already
     downloaded on a real device).
  2. Re-upload to R2, overwriting the same key.
  3. Record the real compressed size (for the catalog's
     `approxSizeBytes`, which must reflect what's actually downloaded).

Writes scripts/compressed_sizes.jsonl (slug -> compressed size) so
generate_catalog_entries.py can pick up the real numbers.
"""

import gzip
import json
import os

import boto3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD_DIR = os.path.join(ROOT, "scripts", "book_text_build")

env = {}
with open(os.path.join(ROOT, "scripts", ".env")) as f:
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

files = sorted(f for f in os.listdir(BUILD_DIR) if f.endswith(".json"))
print(f"found {len(files)} local book files")

results = []
total_before = 0
total_after = 0
for fname in files:
    slug = fname[:-5]
    path = os.path.join(BUILD_DIR, fname)
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:2] == b"\x1f\x8b":
        # already gzip on disk from a previous run of this script
        compressed = raw
    else:
        compressed = gzip.compress(raw, compresslevel=9)
        # keep the on-disk file gzip too, so a re-run of this script is a
        # no-op and any future re-upload script reads the same real bytes
        with open(path, "wb") as f:
            f.write(compressed)

    key = f"books/text/{slug}.json"
    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=compressed,
        ContentType="application/json",
    )
    total_before += len(raw)
    total_after += len(compressed)
    results.append({"slug": slug, "before": len(raw), "after": len(compressed)})

out_path = os.path.join(ROOT, "scripts", "compressed_sizes.jsonl")
with open(out_path, "w", encoding="utf-8") as f:
    for r in results:
        f.write(json.dumps(r) + "\n")

print(f"uploaded {len(results)} compressed files")
print(f"total before: {total_before/1024/1024:.1f} MB, after: {total_after/1024/1024:.1f} MB "
      f"({100*(1-total_after/total_before):.0f}% smaller)")

print("\n--- verify (head_object) ---")
mismatches = []
for r in results:
    head = s3.head_object(Bucket=BUCKET, Key=f"books/text/{r['slug']}.json")
    if head["ContentLength"] != r["after"]:
        mismatches.append(r["slug"])
print("mismatches:", mismatches if mismatches else "none — all verified")
