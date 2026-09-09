"""Mirror the five recorded ruqyahs onto R2 under `ruqyah/<id>.mp3`.

Sourced from archive.org, one item per reciter, each verified before it was
listed in `ruqyah_catalog.dart`: the item's own metadata gave the byte size and
duration, a range request against the real file answered 206 `audio/mpeg`, and
the downloaded bytes matched the declared size exactly.

They are mirrored rather than linked because an archive.org item can be
replaced or taken down by whoever uploaded it, and the "listen to the ruqyah"
section should not go dark when that happens.

Uploads with an explicit `audio/mpeg` content type (R2 will otherwise serve
`application/octet-stream`, which some players refuse to stream), then reads
each object back with `head_object` and fails loudly on any size mismatch —
the catalogue must never claim a size the bucket does not actually hold.

    set RUQ_DIR=<folder holding afasy.mp3 ...> && py -3 scripts/r2_upload_ruqyah.py
"""

import os
import sys

from r2_common import BUCKET, r2_client

# id -> (reciter, expected bytes) — the sizes archive.org's metadata declared
# and the download produced. A mismatch here means the upload is not what the
# app's catalogue promises, so it is a hard failure, not a warning.
EXPECTED = {
    "afasy": ("Mishary Rashid Alafasy", 60462176),
    "ajami": ("Ahmad Al-'Ajami", 90244212),
    "abkar": ("Idris Abkar", 108436721),
    "muaiqly": ("Maher Al-Muaiqly", 54721861),
    "sudais": ("Abdul Rahman Al-Sudais", 41576448),
}


def main():
    src = os.environ.get("RUQ_DIR")
    if not src or not os.path.isdir(src):
        sys.exit("Set RUQ_DIR to the folder holding <id>.mp3")

    s3 = r2_client()

    failures = []
    for rid, (reciter, expected) in EXPECTED.items():
        path = os.path.join(src, rid + ".mp3")
        if not os.path.isfile(path):
            failures.append(f"{rid}: missing {path}")
            continue
        local = os.path.getsize(path)
        if local != expected:
            failures.append(f"{rid}: local {local} != expected {expected}")
            continue

        key = f"ruqyah/{rid}.mp3"
        print(f"uploading {key}  ({local/1e6:.1f} MB, {reciter}) ...", flush=True)
        with open(path, "rb") as fh:
            s3.upload_fileobj(
                fh, BUCKET, key, ExtraArgs={"ContentType": "audio/mpeg"}
            )

        head = s3.head_object(Bucket=BUCKET, Key=key)
        remote = head["ContentLength"]
        ctype = head.get("ContentType")
        ok = remote == expected and ctype == "audio/mpeg"
        print(f"  -> {remote} bytes, {ctype} {'OK' if ok else 'MISMATCH'}")
        if not ok:
            failures.append(f"{rid}: remote {remote}/{ctype}")

    if failures:
        print("\nFAILED:")
        for f in failures:
            print("  " + f)
        sys.exit(1)
    print("\nall five uploaded and verified byte-exact")


if __name__ == "__main__":
    main()
