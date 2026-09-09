# -*- coding: utf-8 -*-
"""Upload one or more built book text editions to R2, and verify each lands.

Reads `scripts/book_text_build/<id>.json` (already gzipped by
`build_book_text.py`) and puts it at `books/text/<id>.json` — stored
compressed with **no** `Content-Encoding` header, which is the standing policy
for this bucket (CLAUDE.md trap #6: 207 of 215 books are stored that way and
the client sniffs the two magic bytes `1f 8b`).

Then reads the first bytes back over the public endpoint and prints the size
the bucket actually reports, so the number that goes into `book_catalog.dart`
is measured rather than typed — §1.1, «الحجم: 1.0 MB» on every card.

Uses `r2_client()` from `r2_common`, which is where the Avast/CA problem was
solved once (trap #13). `curl` for the read-back, because the public endpoint
403s a bare `urllib` request (trap #19).

    py -3 scripts/r2_upload_book_text.py <book_id> [<book_id> ...]
"""

import os
import subprocess
import sys

from r2_common import BUCKET, r2_client

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "scripts", "book_text_build")
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"


def check(url):
    """(first two bytes, Content-Length) as the public endpoint answers."""
    got = subprocess.run(["curl", "-sS", "--fail", "-r", "0-1", url],
                         capture_output=True)
    head = subprocess.run(["curl", "-sSI", "--fail", url],
                          capture_output=True)
    if got.returncode != 0 or head.returncode != 0:
        return None, None
    size = None
    for line in head.stdout.decode("utf-8", "replace").splitlines():
        if line.lower().startswith("content-length:"):
            size = int(line.split(":", 1)[1].strip())
    return got.stdout, size


def main():
    ids = sys.argv[1:]
    if not ids:
        sys.exit(__doc__)

    s3 = r2_client()
    failed = []
    for book_id in ids:
        path = os.path.join(BUILD, "%s.json" % book_id)
        with open(path, "rb") as f:
            body = f.read()
        if body[:2] != b"\x1f\x8b":
            sys.exit("%s is not gzipped — build_book_text.py writes gzip and "
                     "the client sniffs for it" % path)
        key = "books/text/%s.json" % book_id
        s3.put_object(Bucket=BUCKET, Key=key, Body=body,
                      ContentType="application/json")
        magic, size = check("%s/%s" % (PUBLIC, key))
        ok = magic == b"\x1f\x8b" and size == len(body)
        print("%-24s %-28s %9d bytes  magic=%s  remote=%s  %s"
              % (book_id, key, len(body),
                 magic.hex() if magic else "-", size,
                 "OK" if ok else "FAILED"))
        if not ok:
            failed.append(book_id)

    if failed:
        sys.exit("failed to verify: %s" % ", ".join(failed))
    print("\nsizeBytes for book_catalog.dart are the 'bytes' column above.")


if __name__ == "__main__":
    main()
