# -*- coding: utf-8 -*-
"""Publish the second filtering round, and record what it changed.

Twelve books were found carrying a modern editor's apparatus on 2026-09-17 by
the WIDENED audit — the first pass that day had missed them because its editor
detector knew eleven label forms and the library uses thirty-six.

Eleven are published filtered. `tuhfat_at_talib` is NOT: the filter leaves 45
empty pages inside it and a 32-page run of nothing, which is the same verdict
`al_ijaz_fi_sharh_sunan_abi_dawud` got this morning — a book that survives as a
scatter of fragments should be removed, not shipped hollow.

The catalogue is updated from what R2 answers on a HEAD after each put, never
from the local file, because `isBookDownloaded` compares against the hosted
object and a stale `sizeBytes` makes every finished download look stale.
"""

import gzip
import io
import json
import os
import re
import sys

from r2_common import BUCKET, r2_client

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
STRIPPED = os.path.join(HERE, "_stripped")
CAT = os.path.join(HERE, "..", "rafeeq_app", "lib", "features", "library",
                   "data", "book_catalog.dart")

PUBLISH = [
    # The third round, 2026-09-17 evening: the four books added last were
    # audited like every other, and three carried their editor's apparatus.
    # al_muwafaqat keeps 89% of its text with the longest gap 7 pages in
    # 3,211 — a book, unlike tuhfat_at_talib's 32-page hole in 486.
    "muqaddimat_ibn_al_salah",
    "al_risalah_lil_shafii",
    "al_muwafaqat",
]


def main():
    s3 = r2_client()
    sizes = {}
    for bid in PUBLISH:
        path = os.path.join(STRIPPED, bid + ".json")
        if not os.path.exists(path):
            sys.exit("REFUSED: not stripped: %s" % bid)
        raw = open(path, "rb").read()
        if raw[:2] != b"\x1f\x8b":
            raw = gzip.compress(raw, 9)
        key = "books/text/%s.json" % bid
        s3.put_object(Bucket=BUCKET, Key=key, Body=raw,
                      ContentType="application/json")
        back = s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
        if back != len(raw):
            sys.exit("REFUSED: %s uploaded %d, bucket says %d"
                     % (bid, len(raw), back))
        sizes[bid] = back
        print("%-46s %9d bytes" % (key, back))

    src = open(CAT, encoding="utf-8").read()
    changed = 0
    for bid, size in sizes.items():
        # Rewrite this entry's sizeBytes and add the flag if it is missing.
        pat = re.compile(
            r"(id: '%s',.*?sizeBytes: )(\d+)(,)" % re.escape(bid), re.S)
        m = pat.search(src)
        if not m:
            sys.exit("REFUSED: no sizeBytes for %s in the catalogue" % bid)
        src = src[:m.start(2)] + str(size) + src[m.end(2):]
        changed += 1

        block = re.search(
            r"id: '%s',.*?\n  \),\n" % re.escape(bid), src, re.S)
        if "editorNotesRemoved: true" not in block.group(0):
            at = src.index("sizeBytes: %d," % size, block.start())
            line_end = src.index("\n", at) + 1
            indent = " " * 6
            src = (src[:line_end] + indent + "editorNotesRemoved: true,\n"
                   + src[line_end:])

    open(CAT, "w", encoding="utf-8").write(src)
    print()
    print("catalogue: %d sizeBytes rewritten, flags ensured" % changed)
    json.dump(sizes, io.open(os.path.join(HERE, "_stripped_sizes_b.json"),
                             "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
