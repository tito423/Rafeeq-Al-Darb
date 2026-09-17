# -*- coding: utf-8 -*-
"""How much of what the Hajj screen prints is NOT an-Nawawi's?

The printing the guide reads (Shamela 96232) is the only one Shamela has, and
its own card says so plainly:

    الكتاب: الإيضاح في مناسك الحج والعمرة
    المؤلف: … النووي (ت ٦٧٦هـ)
    وعليه: الإفصاح على مسائل الإيضاح … لـ عبد الفتاح حسين

«وعليه» — a second author's commentary printed around an-Nawawi's text, not a
footnote apparatus. The Hajj screen's caption says «النص من كتاب الإيضاح …
للإمام النووي», so anything of عبد الفتاح حسين's that renders there is
attributed to an-Nawawi, which §1.2 does not allow whatever the rights
position is.

This walks the nineteen steps exactly as `hajj_screen.dart` does — same page
range, same paragraph indexes — and counts how many of the paragraphs it would
render are ones `strip_editor_apparatus.py` identifies as the commentator's.
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


def load(path):
    raw = open(path, "rb").read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    doc = json.loads(raw.decode("utf-8"))
    out = {}
    for page in doc["pages"]:
        try:
            n = int(page["p"])
        except (KeyError, ValueError, TypeError):
            continue
        out[n] = [(pa.get("t") or "").strip() for pa in page["paras"]]
    return out


NOISE = re.compile(r"[\s٠-٩0-9()\[\]=*.،,:؛]+")


def key_of(t):
    return NOISE.sub("", t)[:60]


def main():
    orig, filt = load(ORIG), load(FILT)
    steps = STEP.findall(open(GUIDE, encoding="utf-8").read())

    total = kept = 0
    rows = []
    for key, fp, fpara, tp, tpara in steps:
        fp, fpara, tp, tpara = int(fp), int(fpara), int(tp), int(tpara)
        shown = []
        for page in range(fp, tp + 1):
            paras = orig.get(page)
            if not paras:
                continue
            # exactly hajj_screen.dart's slice
            first = fpara if page == fp else 0
            last = tpara if page == tp else len(paras) - 1
            for i in range(first, min(last, len(paras) - 1) + 1):
                shown.append((page, paras[i]))
        # NOT exact string equality. The stripper also removes INLINE
        # footnote markers, so a paragraph that survived intact still fails an
        # equality test and would be counted as deleted - which is how a first
        # run of this script reported 78.6%% when the audit had measured 39%%
        # for the whole file. Compare on a key that ignores what the marker
        # pass touches: digits, brackets and whitespace.
        survivors = {p: set(map(key_of, filt.get(p, [])))
                     for p in {pg for pg, _ in shown}}
        good = sum(1 for pg, t in shown
                   if key_of(t) in survivors.get(pg, ()))
        total += len(shown)
        kept += good
        pct = 100.0 * (len(shown) - good) / len(shown) if shown else 0.0
        rows.append((key, len(shown), len(shown) - good, pct))

    print("%-14s %8s %10s %9s" % ("step", "shown", "commentator", "share"))
    for key, n, bad, pct in rows:
        print("%-14s %8d %10d %8.1f%%" % (key, n, bad, pct))
    print()
    print("TOTAL %d paragraphs rendered across the nineteen steps; %d of them "
          "(%.1f%%) are the commentator's, not an-Nawawi's."
          % (total, total - kept, 100.0 * (total - kept) / total))


if __name__ == "__main__":
    main()
