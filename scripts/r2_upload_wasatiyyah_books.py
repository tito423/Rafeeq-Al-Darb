"""Upload the 2026-09-17 batch of books to R2 and print the byte counts the
catalogue has to carry.

Two rules this obeys, both of which have cost time on this project before:

  * `r2_client()` from `r2_common.py`, never a hand-rolled boto3 client and
    never `verify=False` — Avast re-signs TLS on this machine, and those
    requests carry the bucket's key and secret (trap #13).
  * The file is uploaded **verbatim**. `build_book_text.py` already gzips it
    and the bucket serves it with **no** `Content-Encoding`, because the app
    sniffs the two magic bytes `1f 8b` itself (trap #6). Setting the header
    here would make the CDN decompress it and the sniff would fail.

Every object is HEAD-checked after the put, and the size printed is the one
read back from the bucket — `book_catalog.dart`'s `sizeBytes` must equal it or
`isBookDownloaded` treats a complete download as stale for ever.
"""

import hashlib
import io
import json
import os
import sys

from r2_common import BUCKET, r2_client

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "book_text_build")


def main():
    want = sys.argv[1:]
    if not want:
        sys.exit("usage: r2_upload_wasatiyyah_books.py <id> [<id> …]")

    missing = [i for i in want
               if not os.path.exists(os.path.join(BUILD, "%s.json" % i))]
    if missing:
        sys.exit("REFUSED: not built yet: %s" % ", ".join(missing))

    s3 = r2_client()
    sizes = {}
    for book_id in want:
        path = os.path.join(BUILD, "%s.json" % book_id)
        data = open(path, "rb").read()
        if data[:2] != b"\x1f\x8b":
            sys.exit("REFUSED: %s is not gzip — the app sniffs for 1f 8b"
                     % book_id)
        key = "books/text/%s.json" % book_id
        s3.put_object(Bucket=BUCKET, Key=key, Body=data,
                      ContentType="application/json")
        back = s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
        ok = back == len(data)
        sizes[book_id] = back
        print("%-44s %8d bytes  sha %s  %s"
              % (key, back, hashlib.sha256(data).hexdigest()[:12],
                 "ok" if ok else "SIZE MISMATCH (local %d)" % len(data)))
        if not ok:
            sys.exit(1)

    # MERGE, do not overwrite. This is run in batches as the builds finish,
    # and `write_catalog_entries.py` reads this file for every book's
    # `sizeBytes` — a run that replaced the file would silently drop the
    # earlier batch's sizes and the generator would skip those books.
    out = os.path.join(HERE, "_uploaded_sizes.json")
    merged = {}
    if os.path.exists(out):
        merged = json.load(open(out, encoding="utf-8"))
    merged.update(sizes)
    json.dump(merged, io.open(out, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    sizes = merged
    print()
    print("%d objects, %s bytes total -> %s"
          % (len(sizes), format(sum(sizes.values()), ","), out))


if __name__ == "__main__":
    main()
