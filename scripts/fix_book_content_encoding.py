"""Strip a stray `Content-Encoding: gzip` from hosted book objects.

The standing policy (trap #6, gzip_and_reupload_all_books.py) is gzip bytes
served WITHOUT a Content-Encoding header, so the client receives the stored
bytes verbatim and sniffs `1f 8b` itself. Four books were found carrying the
header (2026-09-18): Dio then unpacks them transparently, the file written to
the device is the decompressed JSON (1,406,613 bytes for al_adab_al_mufrad
against 229,674 in the catalogue), `isBookDownloaded`'s size check fails, and
the book downloads, indexes all its pages, and still shows «تنزيل» for ever.

This rewrites each object's metadata in place (copy onto itself, REPLACE)
with Content-Type application/json and no Content-Encoding. The bytes are
not touched. Every book in the catalogue is checked afterwards.

    py -3 scripts/fix_book_content_encoding.py
"""
import os
import re
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                       "rafeeq_app", "lib", "features", "library", "data",
                       "book_catalog.dart")


def head(key):
    req = urllib.request.Request(PUBLIC + "/" + key, method="HEAD", headers={
        "Accept-Encoding": "gzip", "User-Agent": "RafeeqAlDarb/3.36 fix-check"})
    with urllib.request.urlopen(req) as r:
        return r.headers.get("Content-Encoding"), r.headers.get("Content-Length")


def main():
    keys = sorted(set(re.findall(r"books/text/[a-z0-9_]+\.json",
                                 open(CATALOG, encoding="utf-8").read())))
    s3 = r2_client()
    fixed = 0
    for key in keys:
        meta = s3.head_object(Bucket=BUCKET, Key=key)
        if not meta.get("ContentEncoding"):
            continue
        s3.copy_object(Bucket=BUCKET, Key=key,
                       CopySource={"Bucket": BUCKET, "Key": key},
                       MetadataDirective="REPLACE",
                       ContentType="application/json")
        fixed += 1
        print("fixed", key, "was", meta.get("ContentEncoding"))
    bad = [k for k in keys if head(k)[0]]
    print(f"{fixed} rewritten; {len(keys)} books checked on the public "
          f"endpoint, {len(bad)} still carry Content-Encoding: {bad}")


if __name__ == "__main__":
    main()
