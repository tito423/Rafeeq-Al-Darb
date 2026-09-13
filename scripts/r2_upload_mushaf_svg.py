import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

from botocore.exceptions import ClientError
from r2_common import r2_client

BUCKET = "rafeeq-content"
SRC_DIR = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\mushaf\hafs_kfqc"
DST_KEY = "mushaf/hafs/kfqc/svg/{:03d}.svg"

WORKERS = 16
FORCE = "--force" in sys.argv

def upload_svgs():
    print(f"\n=== Uploading SVGs -> mushaf/hafs/kfqc/svg/ ===", flush=True)

    counts = {"uploaded": 0, "skipped": 0}
    failed = []
    lock = threading.Lock()
    local = threading.local()

    def client():
        if not hasattr(local, "s3"):
            local.s3 = r2_client()
        return local.s3

    def one_page(page):
        key = DST_KEY.format(page)
        c = client()
        if not FORCE:
            try:
                h = c.head_object(Bucket=BUCKET, Key=key)
                if h["ContentLength"] > 100:
                    with lock:
                        counts["skipped"] += 1
                    return
            except ClientError:
                pass

        src_path = os.path.join(SRC_DIR, f"{page:03d}.svg")
        if not os.path.exists(src_path):
            with lock:
                failed.append(page)
            print(f"  FAILED page {page}: {src_path} not found", flush=True)
            return

        for attempt in range(3):
            try:
                with open(src_path, "rb") as f:
                    body = f.read()
                
                c.put_object(
                    Bucket=BUCKET, Key=key, Body=body, ContentType="image/svg+xml"
                )
                with lock:
                    counts["uploaded"] += 1
                    done = counts["uploaded"] + counts["skipped"]
                    if done % 50 == 0 or done == 604:
                        print(
                            f"  {done}/604 pages ({len(body)} bytes last)",
                            flush=True,
                        )
                return
            except Exception as e:
                if attempt == 2:
                    with lock:
                        failed.append(page)
                    print(f"  FAILED page {page}: {e}", flush=True)
                else:
                    time.sleep(1.5)

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(one_page, range(1, 605)))

    print(
        f"SVG upload: uploaded={counts['uploaded']} skipped={counts['skipped']} "
        f"failed={len(failed)}",
        flush=True,
    )
    if failed:
        print(f"Failed pages:", sorted(failed), flush=True)
    return sorted(failed)

def main():
    if not os.path.isdir(SRC_DIR):
        sys.exit(f"Source directory not found: {SRC_DIR}")

    failed = upload_svgs()
    
    print("\n--- head verify sample ---", flush=True)
    c = r2_client()
    for p in (1, 2, 300, 604):
        try:
            h = c.head_object(Bucket=BUCKET, Key=DST_KEY.format(p))
            print(f"page {p}: {h['ContentLength']} bytes", flush=True)
        except ClientError as e:
            print(f"page {p}: MISSING ({e})", flush=True)

    if failed:
        print("\nINCOMPLETE:", failed, flush=True)
        sys.exit(1)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
