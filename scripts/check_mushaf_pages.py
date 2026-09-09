"""Two checks a rendered mushaf page set must pass before it is uploaded.

Written because «604 pages verified» was once claimed for مصحف قطر when what
had actually been verified was that all 604 were FETCHABLE. Four of them were
not legible: a green block, a pink wash, a grey wash and a torn orange band.
Fetchable is not the same as printed correctly.

  1. DEFECTS — a page carrying a large flat coloured area that is neither the
     paper nor the ink. This is what caught all four Qatar pages.
  2. PAGE DIVISION — the page's own printed header, compared with the surah
     the bundled Hafs polygon layer puts on that page number. Anything that
     paginates differently must not claim `hafs_pagination`, and an off-by-one
     in `first_index` shows up here immediately.
     (The header is reported for a human to read; it is not OCR'd.)

    py -3 scripts/check_mushaf_pages.py kuwait
    py -3 scripts/check_mushaf_pages.py kuwait --headers 50 100 200 300 400 500
"""

import argparse
import io
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "scripts", "mushaf_pdf_build")
POLY = json.load(io.open(os.path.join(
    ROOT, "rafeeq_app", "assets", "data", "mushaf", "hafs_kfqc_polygons.json"),
    encoding="utf-8"))


def defects(edition, pages):
    d = os.path.join(WORK, edition)
    rows = []
    for page in range(1, pages + 1):
        a = np.asarray(Image.open(os.path.join(d, "%03d.jpg" % page))
                       .convert("RGB").resize((176, 245)), dtype=np.int16)
        lum = a.mean(axis=2)
        sat = a.max(axis=2) - a.min(axis=2)
        rows.append((page,
                     float(((sat > 90) & (lum > 60) & (lum < 230)).mean()),
                     float(lum.mean())))
    blocks = np.array([r[1] for r in rows])
    bright = np.array([r[2] for r in rows])
    print("coloured-block fraction: median %.4f  99th %.4f  max %.4f"
          % (np.median(blocks), np.percentile(blocks, 99), blocks.max()))
    print("page brightness:         median %.1f  min %.1f  max %.1f"
          % (np.median(bright), bright.min(), bright.max()))
    bad = [r for r in rows
           if r[1] > 0.10 or r[2] < np.median(bright) - 25]
    print("suspect pages: %s" % ([(p, round(b, 3), round(l, 1))
                                  for p, b, l in bad] or "none"))
    return bad


def headers(edition, pages_to_show, top=0.03, bottom=0.13):
    """Crop each page's printed header beside the surah the Hafs layer expects."""
    d = os.path.join(WORK, edition)
    tiles = []
    for page in pages_to_show:
        rows = POLY["pages"].get(str(page), [])
        surahs = sorted({r[0] for r in rows})
        im = Image.open(os.path.join(d, "%03d.jpg" % page))
        # Not from y=0: printings differ in how deep the top margin is, and
        # the Kuwait volume sets its running header a good way down the page.
        strip = im.crop((0, int(im.height * top), im.width,
                         int(im.height * bottom)))
        strip = strip.resize((640, int(640 * strip.height / strip.width)))
        tiles.append((page, surahs, strip))
        print("  p%-4d hafs layer puts surah(s) %s on this page" % (page, surahs))
    h = sum(t[2].height for t in tiles)
    out = Image.new("RGB", (640, h), "white")
    y = 0
    for _, _, s in tiles:
        out.paste(s, (0, y))
        y += s.height
    path = os.path.join(WORK, "%s_headers.png" % edition)
    out.save(path)
    print("header strips -> %s  (read them against the list above)" % path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("edition")
    ap.add_argument("--pages", type=int, default=604)
    ap.add_argument("--headers", nargs="*", type=int)
    ap.add_argument("--band", nargs=2, type=float, default=(0.03, 0.13),
                    help="top and bottom of the header crop, as a fraction")
    a = ap.parse_args()
    defects(a.edition, a.pages)
    if a.headers is not None:
        headers(a.edition, a.headers or [50, 100, 200, 300, 400, 500, 550],
                top=a.band[0], bottom=a.band[1])


if __name__ == "__main__":
    main()
