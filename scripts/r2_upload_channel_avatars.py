"""Mirror the Islamic-channel avatars onto R2 under `channels/<id>.jpg`.

The avatars come from each channel's own YouTube page (verified by
`verify_youtube_channels.py`, which is what produced the channel ids that go
in `islamic_channels.dart`). They are mirrored rather than hot-linked for the
reason every other asset in this app is: the app is offline-first, and a grid
of channel cards whose pictures only appear when the network answers is a grid
that looks broken on a plane or in a masjid basement.

    set AVA_DIR=<folder of <id>.jpg> && py -3 scripts/r2_upload_channel_avatars.py

Verifies every upload with head_object and fails on any size mismatch.
"""

import os
import sys

from r2_common import BUCKET, r2_client


def main():
    src = os.environ.get("AVA_DIR")
    if not src or not os.path.isdir(src):
        sys.exit("Set AVA_DIR to the folder holding <id>.jpg")

    s3 = r2_client()
    files = sorted(f for f in os.listdir(src) if f.endswith(".jpg"))
    if not files:
        sys.exit(f"no .jpg files in {src}")

    failures = []
    for name in files:
        path = os.path.join(src, name)
        local = os.path.getsize(path)
        key = f"channels/{name}"
        with open(path, "rb") as fh:
            s3.upload_fileobj(
                fh, BUCKET, key, ExtraArgs={"ContentType": "image/jpeg"}
            )
        head = s3.head_object(Bucket=BUCKET, Key=key)
        remote, ctype = head["ContentLength"], head.get("ContentType")
        ok = remote == local and ctype == "image/jpeg"
        print(f"{key:<34} {remote:>7} bytes  {ctype}  {'OK' if ok else 'MISMATCH'}")
        if not ok:
            failures.append(key)

    if failures:
        sys.exit("FAILED: " + ", ".join(failures))
    print(f"\n{len(files)} avatars uploaded and verified")


if __name__ == "__main__":
    main()
