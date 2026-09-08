"""Upload the archive.org-sourced mushaf PRINTINGS to R2.

The owner's ask was for real printings (طبعات) — distinct published mushafs —
not more riwāyāt of the same typesetting. `r2_upload_mushaf_editions.py`
handles the Quran-for-Android sourced sets (warsh, qaloon, shamarly); this one
handles the two that need a transform archive.org items don't give for free:

  * madinah_gold — the King Fahd Complex Madinah mushaf in its fully
      gold-illuminated setting, archive.org item `smartmushaf`, 604 numbered
      JPEGs, 1769x2598. Downscaled to 1200px wide here: at ~800 KB a page the
      original set is ~490 MB, which is absurd to stream to a phone whose
      screen is barely 1080 px across.

  * indopak_tajweed — "تجویدی القرآن الكريم رنگین" (Zia-ul-Quran Publications,
      Lahore/Karachi), the Indo-Pak Nastaleeq colour-coded tajweed printing,
      from that item's `Quran-colored-LQ.pdf`. It is a pure scan with no text
      layer, so pages are rendered with PyMuPDF. The PDF carries five leading
      cover/title pages — verified by rendering them — so mushaf page N is PDF
      index N+4, giving 564 mushaf pages.

Both are page-for-page real scans; nothing here is generated or interpolated.
Note their page COUNTS differ from Hafs's 604 because a different printing
genuinely paginates differently — `editions.json` records each edition's own
`pages`, so the reader navigates within that printing's own numbering.

Usage:  py scripts/r2_upload_mushaf_printings.py [name ...] [--force]
"""

import io
import os
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import boto3
import pymupdf
from botocore.exceptions import ClientError
from PIL import Image

REPO = r"E:\My Projects\Rafiq-Al-Darb"
SCRATCH = os.environ.get("RAFEEQ_SCRATCH", os.path.join(REPO, "scripts", "_tmp"))
BUCKET = "rafeeq-content"
WORKERS = 12
FORCE = "--force" in sys.argv
TARGET_WIDTH = 1200
JPEG_QUALITY = 84

env = {}
with open(os.path.join(REPO, "scripts", ".env")) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k] = v

_local = threading.local()


def client():
    if not hasattr(_local, "s3"):
        _local.s3 = boto3.client(
            "s3",
            endpoint_url=env["R2_ENDPOINT"],
            aws_access_key_id=env["R2_ACCESS_KEY_ID"],
            aws_secret_access_key=env["R2_SECRET_ACCESS_KEY"],
            region_name="auto",
        )
    return _local.s3


def to_jpeg(img):
    """Flatten to white, downscale to TARGET_WIDTH, encode JPEG."""
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        flat = Image.new("RGB", img.size, (255, 255, 255))
        flat.paste(img, mask=img.split()[-1])
        img = flat
    else:
        img = img.convert("RGB")
    if img.width > TARGET_WIDTH:
        h = round(img.height * TARGET_WIDTH / img.width)
        img = img.resize((TARGET_WIDTH, h), Image.LANCZOS)
    out = io.BytesIO()
    img.save(out, "JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
    return out.getvalue()


def put(folder, page, body):
    client().put_object(
        Bucket=BUCKET,
        Key=f"mushaf/{folder}/{page:03d}.jpg",
        Body=body,
        ContentType="image/jpeg",
    )


def already(folder, page):
    if FORCE:
        return False
    try:
        h = client().head_object(Bucket=BUCKET, Key=f"mushaf/{folder}/{page:03d}.jpg")
        return h["ContentLength"] > 5000
    except ClientError:
        return False


# ── madinah_gold: numbered JPEGs straight off archive.org ──────────────────
def upload_madinah_gold():
    folder, first, last = "madinah_gold", 1, 604
    src = "https://archive.org/download/smartmushaf/{}.jpg"
    print(f"=== madinah_gold -> mushaf/{folder}/ ({first}..{last}) ===", flush=True)
    done = {"n": 0}
    failed = []
    lock = threading.Lock()

    def one(page):
        if already(folder, page):
            with lock:
                done["n"] += 1
            return
        for attempt in range(3):
            try:
                req = urllib.request.Request(
                    src.format(page), headers={"User-Agent": "rafeeq-uploader"}
                )
                with urllib.request.urlopen(req, timeout=120) as r:
                    raw = r.read()
                    ctype = r.headers.get("Content-Type", "")
                if "image" not in ctype or len(raw) < 5000:
                    raise ValueError(f"not an image ({ctype}, {len(raw)} B)")
                body = to_jpeg(Image.open(io.BytesIO(raw)))
                put(folder, page, body)
                with lock:
                    done["n"] += 1
                    if done["n"] % 50 == 0 or done["n"] == last:
                        print(
                            f"  {done['n']}/{last} ({len(body)} B last)", flush=True
                        )
                return
            except Exception as e:  # noqa: BLE001
                if attempt == 2:
                    with lock:
                        failed.append(page)
                    print(f"  FAILED {page}: {e}", flush=True)
                else:
                    time.sleep(2)

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(one, range(first, last + 1)))
    print(f"madinah_gold: failed={len(failed)}", flush=True)
    return failed


# ── indopak_tajweed: rendered out of the scanned PDF ───────────────────────
PDF_URL = (
    "https://archive.org/download/TajweediColor-codedQuranByZia-ul-quran/"
    "Quran-colored-LQ.pdf"
)
PDF_OFFSET = 5  # PDF index of mushaf page 1 (five cover/title pages precede it)
PDF_PAGES = 564


def upload_indopak():
    folder = "indopak_tajweed"
    os.makedirs(SCRATCH, exist_ok=True)
    local = os.path.join(SCRATCH, "tajpak.pdf")
    if not os.path.exists(local) or os.path.getsize(local) < 10_000_000:
        print("downloading source PDF (~93 MB)...", flush=True)
        urllib.request.urlretrieve(PDF_URL, local)
    doc = pymupdf.open(local)
    print(
        f"=== indopak_tajweed -> mushaf/{folder}/ (1..{PDF_PAGES}) ===", flush=True
    )
    failed = []
    # PyMuPDF documents are not thread-safe, so rendering stays single-threaded
    # and only the uploads fan out.
    pending = []

    def flush(batch):
        def send(item):
            page, body = item
            for attempt in range(3):
                try:
                    put(folder, page, body)
                    return
                except Exception:  # noqa: BLE001
                    if attempt == 2:
                        failed.append(page)
                    else:
                        time.sleep(2)

        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            list(pool.map(send, batch))

    for page in range(1, PDF_PAGES + 1):
        if already(folder, page):
            continue
        pix = doc[page - 1 + PDF_OFFSET].get_pixmap(dpi=160)
        body = to_jpeg(Image.open(io.BytesIO(pix.tobytes("png"))))
        pending.append((page, body))
        if len(pending) >= 24:
            flush(pending)
            pending = []
            if page % 48 == 0:
                print(f"  {page}/{PDF_PAGES}", flush=True)
    if pending:
        flush(pending)
    print(f"indopak_tajweed: failed={len(failed)}", flush=True)
    return failed


JOBS = {"madinah_gold": upload_madinah_gold, "indopak_tajweed": upload_indopak}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    wanted = args or list(JOBS)
    bad = [w for w in wanted if w not in JOBS]
    if bad:
        sys.exit(f"unknown: {bad}; known: {list(JOBS)}")
    allf = {}
    for name in wanted:
        f = JOBS[name]()
        if f:
            allf[name] = f
    print("\n--- verify ---", flush=True)
    for name in wanted:
        folder = "madinah_gold" if name == "madinah_gold" else "indopak_tajweed"
        last = 604 if name == "madinah_gold" else PDF_PAGES
        for p in (1, 2, last // 2, last):
            try:
                h = client().head_object(
                    Bucket=BUCKET, Key=f"mushaf/{folder}/{p:03d}.jpg"
                )
                print(f"  {folder} p{p}: {h['ContentLength']} B", flush=True)
            except ClientError:
                print(f"  {folder} p{p}: MISSING", flush=True)
    if allf:
        print("INCOMPLETE:", allf, flush=True)
        sys.exit(1)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
