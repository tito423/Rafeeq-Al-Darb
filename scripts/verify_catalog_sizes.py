"""Does every book's catalogued `sizeBytes` equal what the bucket actually holds?

This is the question a staleness check has to be able to trust. The app is
about to decide «this downloaded book is out of date» by comparing the local
file's length to the catalogue's `sizeBytes`, so a single stale number in the
catalogue would tell a reader to re-download a book that is perfectly fine.

One HEAD per book, no bodies.
"""

import concurrent.futures
import io
import re
import sys
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb/3.31 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
CATALOG = (r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\library"
           r"\data\book_catalog.dart")


def head(path):
    """The object's real length.

    A plain HEAD is not enough: R2 answers five of these books without a
    Content-Length header at all, which the first version of this script
    reported as a size mismatch. A one-byte range GET carries the authoritative
    total in Content-Range, and falls back to reading the body.
    """
    req = urllib.request.Request(
        BASE + path, headers={"User-Agent": UA, "Range": "bytes=0-0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        m = re.search(r"/(\d+)$", r.headers.get("Content-Range", ""))
        if m:
            return int(m.group(1))
    req = urllib.request.Request(BASE + path, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=300) as r:
        return len(r.read())


def main():
    src = open(CATALOG, encoding="utf-8").read()
    # Each entry declares its url then its sizeBytes, in that order.
    pairs = re.findall(
        r"contentBaseUrl\}(/books/text/([A-Za-z0-9_]+)\.json)'[^)]*?"
        r"sizeBytes: (\d+)", src, flags=re.S)
    print("entries parsed:", len(pairs))

    def check(p):
        path, bid, declared = p
        try:
            return bid, int(declared), head(path)
        except Exception as exc:                    # noqa: BLE001 - reported
            return bid, int(declared), str(exc)[:60]

    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
        rows = list(ex.map(check, pairs))

    bad = [r for r in rows if r[1] != r[2]]
    with io.open("_catalog_sizes.txt", "w", encoding="utf-8") as f:
        f.write("books checked: %d\nmismatches: %d\n\n" % (len(rows), len(bad)))
        for bid, declared, real in bad:
            f.write("%-48s catalogue %-10s bucket %s\n" % (bid, declared, real))
    print("checked %d, mismatches %d -> _catalog_sizes.txt" % (len(rows), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
