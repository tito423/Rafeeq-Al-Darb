"""Publish the filtered books and keep the catalogue honest about them.

`strip_editor_apparatus.py` writes cleaned copies into `_stripped/`. This
uploads them over the same R2 keys, reads back what the bucket actually holds,
and rewrites `sizeBytes` and `pages` in `book_catalog.dart` from the readback —
never from what we intended to upload. A card that claims «الحجم: 1.0 MB»
because a number was written by hand is the defect §1.1 was written for.

Conventions it follows, both already standing policy:
  * gzip with **no** `Content-Encoding` header, `ContentType: application/json`
    — `BookText.fromFile` sniffs the two magic bytes (trap #6), so the header
    would be wrong here, not missing.
  * `r2_client()` from `r2_common`, because Avast re-signs TLS on this machine
    and every other boto3 path fails (trap #13). Never `verify=False`.

Run `--dry-run` first. It prints what would change and touches nothing.
"""

import argparse
import gzip
import io
import json
import os
import re
import sys

from r2_common import BUCKET, r2_client

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

STRIPPED = "_stripped"
CATALOG = (r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\library"
           r"\data\book_catalog.dart")


def entry_span(src, bid):
    """(start, end) of the LibraryBook(...) block that declares `bid`."""
    m = re.search(r"LibraryBook\(\s*\n\s*id: '%s'" % re.escape(bid), src)
    if not m:
        return None
    start = src.index("LibraryBook(", m.start())
    i = start + len("LibraryBook(")
    depth = 1
    while depth:
        c = src[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        i += 1
    return start, i


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", help="one book id, for the first careful run")
    ap.add_argument("--report", default="_upload_stripped_report.txt")
    args = ap.parse_args()

    files = sorted(f for f in os.listdir(STRIPPED) if f.endswith(".json"))
    if args.only:
        files = [args.only + ".json"]
    s3 = None if args.dry_run else r2_client()

    src = io.open(CATALOG, encoding="utf-8").read()
    report = io.open(args.report, "w", encoding="utf-8")
    changed = 0

    for fn in files:
        bid = fn[:-5]
        doc = json.load(io.open(os.path.join(STRIPPED, fn), encoding="utf-8"))
        pages = len(doc["pages"])
        raw = json.dumps(doc, ensure_ascii=False).encode("utf-8")
        body = gzip.compress(raw, compresslevel=9)
        key = "books/text/%s.json" % bid

        span = entry_span(src, bid)
        if span is None:
            report.write("%-48s NOT IN THE CATALOGUE — skipped\n" % bid)
            continue
        block = src[span[0]:span[1]]
        old_size = re.search(r"sizeBytes: (\d+)", block)
        old_pages = re.search(r"pages: (\d+)", block)

        if args.dry_run:
            report.write("%-48s pages %s -> %d   sizeBytes %s -> %d (gzip)\n"
                         % (bid, old_pages.group(1) if old_pages else "-",
                            pages, old_size.group(1) if old_size else "-",
                            len(body)))
            continue

        s3.put_object(Bucket=BUCKET, Key=key, Body=body,
                      ContentType="application/json")
        real = s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
        if real != len(body):
            report.write("%-48s READBACK MISMATCH %d != %d — STOPPING\n"
                         % (bid, real, len(body)))
            break

        new_block = re.sub(r"sizeBytes: \d+", "sizeBytes: %d" % real, block)
        if old_pages:
            new_block = re.sub(r"pages: \d+", "pages: %d" % pages, new_block, 1)
        src = src[:span[0]] + new_block + src[span[1]:]
        changed += 1
        report.write("%-48s uploaded %8d bytes, pages %s -> %d\n"
                     % (bid, real, old_pages.group(1) if old_pages else "-",
                        pages))

    if not args.dry_run and changed:
        io.open(CATALOG, "w", encoding="utf-8").write(src)
    report.write("\n%d books %s\n"
                 % (changed if not args.dry_run else len(files),
                    "updated" if not args.dry_run else "would change"))
    report.close()
    print(open(args.report, encoding="utf-8").read()[-800:])


if __name__ == "__main__":
    main()
