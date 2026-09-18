"""How vowelled is every book in the library, measured not guessed.

WHY. The owner asked for a spoken reader for the library, «متقن». Arabic
without harakat is genuinely ambiguous — the same consonantal skeleton is
several different words — and in a scholarly religious text a wrong vowel is
a wrong MEANING, not a wrong accent. So whether a given book can be read
aloud correctly depends on whether THAT BOOK carries its vowels.

A sample of 24 books already showed the corpus is bimodal: median 35.6%, ten
under 20%, seven over 60%. This measures all of them, so the feature can be
gated per book on a real number rather than on a hope.

    py -3 scripts/measure_diacritisation.py

Writes `_diacritisation.json` (id -> percent) next to the repo root and
prints the distribution. The Dart catalogue is generated from that file by
`apply_diacritisation.py`, so the number in the app is the number measured
here and cannot drift by being retyped.

Counts a mark as any of the Arabic combining vowels and sukun (U+064B-U+0652)
plus the dagger alef (U+0670), over the Arabic letters (U+0621-U+064A). Both
ranges are deliberate: the shadda counts, because a doubled consonant changes
the word, and the dagger alef counts because it is a vowel the reader needs.
"""

from __future__ import annotations

import gzip
import io
import json
import os
import re
import statistics
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/books/text"
UA = "RafeeqAlDarb/3.35 (https://github.com/tito423/Rafeeq-Al-Darb)"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library",
                       "data", "book_catalog.dart")
OUT = os.path.join(ROOT, "_diacritisation.json")

MARKS = re.compile(r"[ً-ْٰ]")
LETTERS = re.compile(r"[ء-ي]")


def book_ids() -> list[str]:
    src = io.open(CATALOG, encoding="utf-8").read()
    ids = re.findall(r"id:\s*'([a-z0-9_]+)'", src)
    seen, out = set(), []
    for i in ids:
        if i not in seen:
            seen.add(i)
            out.append(i)
    return out


def fetch(bid: str) -> tuple[str, float, int]:
    """(id, percent diacritised, Arabic letters counted)."""
    url = "%s/%s.json" % (BASE, bid)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(3):
        try:
            raw = urllib.request.urlopen(req, timeout=180).read()
            break
        except Exception:
            if attempt == 2:
                return (bid, -1.0, 0)
    if raw[:2] == b"\x1f\x8b":          # trap #6: gzip with no header
        raw = gzip.decompress(raw)
    doc = json.loads(raw.decode("utf-8"))

    parts = []
    for page in doc.get("pages", []):
        for para in page.get("paras", []):
            parts.append(para if isinstance(para, str) else para.get("t", ""))
    text = " ".join(parts)

    letters = len(LETTERS.findall(text))
    marks = len(MARKS.findall(text))
    if letters == 0:
        return (bid, -1.0, 0)
    return (bid, round(100.0 * marks / letters, 1), letters)


def main() -> int:
    ids = book_ids()
    print("measuring %d books" % len(ids))
    rows: dict[str, float] = {}
    sizes: dict[str, int] = {}

    with ThreadPoolExecutor(max_workers=6) as pool:
        for n, (bid, pct, letters) in enumerate(pool.map(fetch, ids), 1):
            rows[bid] = pct
            sizes[bid] = letters
            if n % 25 == 0:
                print("  %d/%d" % (n, len(ids)))

    ok = {k: v for k, v in rows.items() if v >= 0}
    failed = [k for k, v in rows.items() if v < 0]

    io.open(OUT, "w", encoding="utf-8").write(
        json.dumps(rows, ensure_ascii=False, indent=1, sort_keys=True) + "\n")

    vals = sorted(ok.values())
    print("\nmeasured %d, unreadable %d" % (len(ok), len(failed)))
    for f in failed:
        print("  UNREADABLE %s" % f)
    if not vals:
        return 1
    print("median %.1f%%  mean %.1f%%" % (statistics.median(vals),
                                          statistics.mean(vals)))
    bands = [(0, 5), (5, 20), (20, 50), (50, 80), (80, 101)]
    for lo, hi in bands:
        n = sum(1 for v in vals if lo <= v < hi)
        print("  %3d-%3d%%  %3d books  %s" % (lo, hi, n, "#" * (n // 2)))
    print("\n-> %s" % OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
