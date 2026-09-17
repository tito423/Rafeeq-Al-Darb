# -*- coding: utf-8 -*-
"""Re-point the Hajj guide's step boundaries after «الإيضاح» is filtered.

WHY THIS EXISTS. `hajj_guide.dart` addresses the book by **printed page and
paragraph index inside that page** — `hajj_screen.dart` slices with
`p.printedPage == step.fromPage ? step.fromPara : 0`. Removing a paragraph
therefore RENUMBERS every index on that page, and 39% of this file is not
an-Nawawi at all: the printing carries «الإفصاح على مسائل الإيضاح» by
**عبد الفتاح حسين رواه المكي** alongside it, which is a second living author's
whole book, not a footnote apparatus.

Filtering it without re-pointing would leave nineteen steps each starting or
ending a few paragraphs out — and nothing would look broken. Every step would
still render text; it would just be the wrong text, on a screen whose whole
claim is that it prints an-Nawawi's manual verbatim. That is the worst kind
of defect this project has: invisible and scripture-adjacent.

HOW. Each boundary is re-pointed by its own TEXT, not by arithmetic. The
anchor paragraph is read from the ORIGINAL file, then found again in the
FILTERED one, and the new index is whatever position it now holds. A boundary
whose anchor was itself removed is reported and NOT guessed at — that is a
human decision, because it means the step used to begin or end inside the
editor's work.
"""

import gzip
import io
import json
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

HERE = os.path.dirname(os.path.abspath(__file__))
BOOK = "al_idah_fi_manasik_al_hajj_wal_umrah"
ORIG = os.path.join(HERE, "book_text_build", BOOK + ".json")
FILT = os.path.join(HERE, "_stripped", BOOK + ".json")
GUIDE = os.path.join(HERE, "..", "rafeeq_app", "lib", "features", "hajj",
                     "data", "hajj_guide.dart")

STEP = re.compile(
    r"key: '([a-z]+)', fromPage: (\d+), fromPara: (\d+), toPage: (\d+),\s*"
    r"toPara: (\d+)", re.S)


NOISE = re.compile(r"[\s٠-٩\d()\[\]=*.،,:؛]+")


def key_of(t):
    return NOISE.sub("", t)[:60]


def load(path):
    raw = open(path, "rb").read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    doc = json.loads(raw.decode("utf-8"))
    by_page = {}
    for page in doc["pages"]:
        try:
            n = int(page["p"])
        except (KeyError, ValueError, TypeError):
            continue
        by_page[n] = [(pa.get("t") or "").strip() for pa in page["paras"]]
    return by_page


def main():
    orig, filt = load(ORIG), load(FILT)
    src = open(GUIDE, encoding="utf-8").read()
    steps = STEP.findall(src)
    print("steps found in hajj_guide.dart: %d" % len(steps))

    moves, lost = [], []
    for key, fp, fpara, tp, tpara in steps:
        for which, page, idx in (("from", int(fp), int(fpara)),
                                 ("to", int(tp), int(tpara))):
            old = orig.get(page, [])
            if idx >= len(old):
                lost.append((key, which, page, idx, 0,
                             "index out of range in the original"))
                continue
            anchor = old[idx]
            new = filt.get(page, [])
            newkeys = [key_of(t) for t in new]
            k = key_of(anchor)
            if k in newkeys:
                j = newkeys.index(k)
                moves.append((key, which, page, idx, j, anchor[:70]))
                continue
            # The anchor was the commentator's and is gone. Snap INWARDS, so
            # the step can only ever shrink onto an-Nawawi's text and never
            # grow into someone else's: a "from" moves to the first surviving
            # paragraph at or after it, a "to" to the last surviving one at or
            # before it. Guessing outwards would put the commentator back.
            surviving_before = [i for i, t in enumerate(old[:idx + 1])
                                if key_of(t) in newkeys]
            if which == "to":
                j = (newkeys.index(key_of(old[surviving_before[-1]]))
                     if surviving_before else max(len(new) - 1, 0))
            else:
                after = [i for i, t in enumerate(old) if i >= idx
                         and key_of(t) in newkeys]
                j = newkeys.index(key_of(old[after[0]])) if after else 0
            lost.append((key, which, page, idx, j, anchor[:90]))

    print()
    print("=" * 74)
    print("BOUNDARIES THAT MOVED  (%d)" % sum(
        1 for m in moves if m[3] != m[4]))
    print("=" * 74)
    for key, which, page, old_i, new_i, txt in moves:
        if old_i != new_i:
            print("  %-12s %-4s p%-4d  %2d -> %2d   «%s»"
                  % (key, which, page, old_i, new_i, txt))

    print()
    print("=" * 74)
    print("BOUNDARIES WHOSE ANCHOR WAS THE COMMENTATOR'S  (%d)"
          % len(lost))
    print("=" * 74)
    for key, which, page, idx, j, txt in lost:
        print("  %-12s %-4s p%-4d  %2d -> %2d (snapped inwards)\n      «%s»"
              % (key, which, page, idx, j, txt))

    out = os.path.join(HERE, "_hajj_bounds_remap.json")
    json.dump({"moves": [list(m) for m in moves],
               "lost": [list(l) for l in lost]},
              io.open(out, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print()
    print("-> %s" % out)
    return 1 if lost else 0


if __name__ == "__main__":
    raise SystemExit(main())
