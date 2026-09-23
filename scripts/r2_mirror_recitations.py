# -*- coding: utf-8 -*-
"""Mirror a small, chosen set of MURATTAL recitations onto R2 — as the app's
primary source, with the public origins kept as the fallback.

The owner, 2026-09-23: «ارفع المرتل بس … بحيث ان الحجم الكامل للرفع
لايتجاوز ٦ جيجا … انا مش عاوز ادفع فلس واحد». So two limits, and both are
enforced HERE rather than promised:

  * the set is fixed below and measures 5.76 GB (from everyayah's directory
    index, byte-exact, and from mp3quran's Content-Length for all 114 surahs);
  * before any byte moves, the bucket is measured live, and the run refuses
    to start if bucket + remaining would pass FREE_TIER_GUARD. R2's free tier
    is 10 GB-month of storage; the guard sits at 9.5 GB.

Per ayah (everyayah.com, the 6,236 Hafs ayah files — the app plays 1:1 for
a basmala, so the `SSS000` basmala files are not needed):
    recitations/ayah/<folder>/SSSAAA.mp3
Whole surahs (mp3quran.net, murattal Hafs):
    recitations/surah/<slug>/NNN.mp3

Resumable: an object already on R2 with a plausible size is skipped, so a
killed run is simply started again. Every upload is read back with
`head_object` and must match the downloaded size exactly. Content-Type is
`audio/mpeg`, and NO Content-Encoding (trap #6's lesson applies to any
binary the device downloads).

    py -3 scripts/r2_mirror_recitations.py            # run (resumes)
    py -3 scripts/r2_mirror_recitations.py --plan     # measure only

Provenance and the owner's decision are recorded in CONTENT-LICENSES.md.
"""

import concurrent.futures as cf
import io
import os
import subprocess
import sys
import tempfile
import threading
import time

from r2_common import BUCKET, r2_client

UA = "RafeeqAlDarb/3.57 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
FREE_TIER_GUARD = 9.5e9
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG = os.path.join(ROOT, "_mirror_log.txt")

# Hafs ayah counts, 114 surahs, summing to 6,236 — the same table
# test/ayah_counts_test.dart pins from quran_local.db.
COUNTS = [7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99,
          128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
          34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38,
          29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18,
          12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29,
          19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8,
          11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6]
assert sum(COUNTS) == 6236

# everyayah folder -> measured bytes (directory index, 2026-09-23)
AYAH_SETS = {
    "Alafasy_128kbps": 1.72e9,
    "MaherAlMuaiqly128kbps": 1.21e9,
    "Minshawy_Murattal_128kbps": 1.67e9,
}
# slug -> (mp3quran folder, measured bytes for all 114, 2026-09-23)
SURAH_SETS = {
    "basit_murattal": ("https://server7.mp3quran.net/basit/", 0.45e9),
    "maher_murattal": ("https://server12.mp3quran.net/maher/", 0.71e9),
}

_lock = threading.Lock()


def log(msg):
    line = time.strftime("%H:%M:%S ") + msg
    with _lock:
        with io.open(LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")


def jobs():
    for folder in AYAH_SETS:
        for s, n in enumerate(COUNTS, 1):
            for a in range(1, n + 1):
                name = "%03d%03d.mp3" % (s, a)
                yield ("https://everyayah.com/data/%s/%s" % (folder, name),
                       "recitations/ayah/%s/%s" % (folder, name))
    for slug, (base, _) in SURAH_SETS.items():
        for s in range(1, 115):
            name = "%03d.mp3" % s
            yield (base + name, "recitations/surah/%s/%s" % (slug, name))


def bucket_bytes(s3):
    total = 0
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=BUCKET):
        for o in page.get("Contents", []):
            total += o["Size"]
    return total


def existing(s3, prefix):
    have = {}
    for page in s3.get_paginator("list_objects_v2").paginate(
            Bucket=BUCKET, Prefix=prefix):
        for o in page.get("Contents", []):
            have[o["Key"]] = o["Size"]
    return have


def fetch(url, dest):
    """curl, because it trusts this machine's store (Avast, trap #13) and
    fails loudly on a short body. Returns (bytes, content-type)."""
    p = subprocess.run(
        ["curl", "-sS", "--fail", "-L", "-A", UA, "--max-time", "300",
         "--retry", "3", "--retry-delay", "3", "-o", dest,
         "-w", "%{size_download} %{content_type}", url],
        capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError("curl %d: %s" % (p.returncode, p.stderr.strip()[:200]))
    size, _, ctype = p.stdout.strip().partition(" ")
    return int(size), ctype


def one(s3, url, key, tmpdir):
    dest = os.path.join(tmpdir, key.replace("/", "_"))
    try:
        size, ctype = fetch(url, dest)
        # A soft-404 is an HTML page with a 200 (trap #5). Refuse it.
        if "audio" not in ctype or size < 1000:
            raise RuntimeError("not audio: %s %d bytes" % (ctype, size))
        with open(dest, "rb") as fh:
            s3.upload_fileobj(fh, BUCKET, key,
                              ExtraArgs={"ContentType": "audio/mpeg"})
        got = s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
        if got != size:
            raise RuntimeError("R2 holds %d, downloaded %d" % (got, size))
        return size
    finally:
        try:
            os.remove(dest)
        except OSError:
            pass


def main():
    plan_only = "--plan" in sys.argv
    s3 = r2_client()
    now = bucket_bytes(s3)
    have = existing(s3, "recitations/")
    planned = sum(AYAH_SETS.values()) + sum(v[1] for v in SURAH_SETS.values())
    already = sum(have.values())
    remaining = max(0.0, planned - already)
    print("bucket now      %.3f GB" % (now / 1e9))
    print("set, measured   %.3f GB" % (planned / 1e9))
    print("already mirrored %.3f GB in %d objects" % (already / 1e9, len(have)))
    print("after this run  ~%.3f GB   (guard %.1f GB)"
          % ((now + remaining) / 1e9, FREE_TIER_GUARD / 1e9))
    if now + remaining > FREE_TIER_GUARD:
        sys.exit("REFUSED: this would take the bucket past the free-tier guard.")
    if plan_only:
        return

    todo = [(u, k) for u, k in jobs() if have.get(k, 0) < 1000]
    total = len(todo)
    log("start: %d files to mirror, %d already there" % (total, len(have)))
    done = failed = moved = 0
    t0 = time.time()
    tmpdir = tempfile.mkdtemp(prefix="rafeeq_mirror_")
    with cf.ThreadPoolExecutor(8) as ex:
        futs = {ex.submit(one, s3, u, k, tmpdir): k for u, k in todo}
        for f in cf.as_completed(futs):
            k = futs[f]
            try:
                moved += f.result()
                done += 1
            except Exception as e:  # noqa: BLE001 - logged, run continues
                failed += 1
                log("FAIL %s: %s" % (k, e))
            if (done + failed) % 250 == 0 or done + failed == total:
                rate = moved / max(1.0, time.time() - t0) / 1e6
                log("progress %d/%d  failed %d  %.2f GB  %.1f MB/s"
                    % (done + failed, total, failed, moved / 1e9, rate))
    log("end: %d ok, %d failed, %.3f GB moved" % (done, failed, moved / 1e9))
    print("done: %d ok, %d failed" % (done, failed))


if __name__ == "__main__":
    main()
