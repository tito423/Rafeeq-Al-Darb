"""Flag, in the catalogue, every book whose hosted file was filtered.

The source label on those 47 books still names the muhaqqiq — «تحقيق عبد القادر
الأرنؤوط» — which is true about where the text came from and is what §1.2 asks
for. On its own, though, it reads as «this is his edition», and after the
filtering it is not. So each of them gets `editorNotesRemoved: true` and the
reader prints a line saying what the reader is actually holding.

The list is not typed here. It is exactly the set of files under `_stripped/`
that were uploaded, so the flag cannot drift from what was done.
"""

import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

CATALOG = (r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\library"
           r"\data\book_catalog.dart")
STRIPPED = "_stripped"


def entry_span(src, bid):
    m = re.search(r"LibraryBook\(\s*\n\s*id: '%s'" % re.escape(bid), src)
    if not m:
        return None
    start = src.index("LibraryBook(", m.start())
    i, depth = start + len("LibraryBook("), 1
    while depth:
        c = src[i]
        depth += 1 if c == "(" else -1 if c == ")" else 0
        i += 1
    return start, i


def main():
    ids = sorted(f[:-5] for f in os.listdir(STRIPPED) if f.endswith(".json"))
    src = io.open(CATALOG, encoding="utf-8").read()
    done, missing, already = 0, [], 0
    for bid in ids:
        span = entry_span(src, bid)
        if span is None:
            missing.append(bid)
            continue
        block = src[span[0]:span[1]]
        if "editorNotesRemoved" in block:
            already += 1
            continue
        # Put it right after sizeBytes, inside the TextEdition(...).
        new_block, n = re.subn(
            r"(sizeBytes: \d+,)", r"\1\n      editorNotesRemoved: true,",
            block, count=1)
        if n != 1:
            missing.append(bid + " (no sizeBytes line)")
            continue
        src = src[:span[0]] + new_block + src[span[1]:]
        done += 1
    io.open(CATALOG, "w", encoding="utf-8").write(src)
    print("flagged %d books, %d already flagged" % (done, already))
    if missing:
        print("NOT FLAGGED:", missing)


if __name__ == "__main__":
    main()
