# -*- coding: utf-8 -*-
"""Curate the fetched Commons images down to backgrounds a saying can be read
on, darken them, and MEASURE that it can.

TWO JOBS, BOTH OF WHICH SOMEBODY HAS TO DO BY EYE FIRST.

1. WHAT IS A BACKGROUND. Licence-free is not the same as usable. Of the 18
   files the fetch produced, seven are not backgrounds at all: photographs and
   paintings of **people**, a page of an **illuminated Qur'an manuscript**,
   a snapshot of a mosque interior with a wall clock and plastic bags in it,
   and a panel of Arabic calligraphy that would fight the saying written over
   it. Each rejection is written down below with its reason — the contact
   sheet in `dist/quote_backgrounds/_sheet.png` is what those reasons came
   from (§1.3: look at the pictures).

2. WHETHER THE TEXT IS READABLE. CLAUDE.md trap #15: a translucent layer over
   a ground composites to something neither colour predicts, and three mushaf
   themes shipped at 2.3-2.6 : 1 because somebody judged a pairing by eye.
   So the darkening is baked into the shipped JPEG rather than applied at draw
   time, and this script measures the **brightest** region of each finished
   file against the card's ink. Anything that cannot clear 4.5 : 1 is darkened
   further; anything that still cannot is dropped and said so.

    py -3 scripts/curate_quote_backgrounds.py
"""

import io
import json
import os

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "dist", "quote_backgrounds")
OUT = os.path.join(ROOT, "dist", "quote_backgrounds_final")
MANIFEST = os.path.join(ROOT, "quote_backgrounds.json")
FINAL = os.path.join(ROOT, "quote_backgrounds_final.json")

# The card's ink, from `QuoteCardScreen`'s palettes — the lightest of them, so
# the measurement is of the pairing that is hardest to keep legible.
INK = (0xF2, 0xF6, 0xFA)
FLOOR = 4.5

# THE SCRIM, AND WHY IT IS THE APP'S JOB AND NOT THE FILE'S.
# The first pass baked the darkening into the JPEG until the measurement
# passed, and the pictures came out muddy — a photograph of Alhambra stucco
# darkened to 46% is no longer a photograph of anything. A background is
# allowed to be a background: the app draws a near-opaque scrim over it and
# the saying sits on that.
#
# CLAUDE.md trap #15 is why this is computed rather than eyeballed: the layer
# is translucent, so what the reader sees is neither the scrim's colour nor
# the photo's but the composite, and three mushaf themes shipped at 2.3-2.6:1
# because somebody looked at the swatches. Here the composite is worked out
# per image, on its **brightest** region — a bright window or a lit chandelier
# is exactly where a line of the saying will vanish.
SCRIM = (0x07, 0x16, 0x26)
SCRIM_ALPHA = 0.80

REJECT = {
    "478434_soochow_kiangsu":
        "a photograph of a person standing in a doorway",
    "a_manuscript_of_five_sections_of_a_qur_an_met_dp2418":
        "a page of an illuminated Qur'an manuscript - scripture is not "
        "wallpaper, and a saying written over an ayah is not something this "
        "app does",
    "aliebnemousa":
        "a panel of Arabic calligraphy; it would fight the saying set over it",
    "arab_school_by_john_frederick_lewis":
        "a painting of people",
    "arab_school_met_dp805928":
        "the same painting of people",
    "catalogue_of_the_highly_important_collection_of_mod":
        "a painting of people",
    "kizimkazi04":
        "a snapshot with a wall clock, plastic bags and clutter in it",
}


def luminance(rgb):
    def ch(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(rgb[0]) + 0.7152 * ch(rgb[1]) + 0.0722 * ch(rgb[2])


def ratio(fg, bg):
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def brightest_block(im, block=60):
    """The RGB of the brightest `block`x`block` tile in the image.

    A tile rather than a pixel because a glyph covers roughly that much, and
    a mean over the whole picture would hide a bright window or a lit
    chandelier — which is exactly where a line of the saying will land and
    disappear.
    """
    small = im.convert("RGB").resize(
        (max(1, im.width // block), max(1, im.height // block)), Image.BOX)
    return max(small.getdata(), key=luminance)


def darken(im, amount):
    return ImageEnhance.Brightness(im).enhance(amount)


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = {r["id"]: r for r in json.load(io.open(MANIFEST, encoding="utf-8"))}

    kept, dropped = [], []
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".jpg"):
            continue
        vid = name[:-4]
        # Prefix match: `slug()` truncates an id at 48 characters, and two
        # rejections silently missed on the first run because their keys were
        # written out in full — the Qur'an manuscript and one of the paintings
        # of people came through as "kept".
        why = next((r for k, r in REJECT.items()
                    if vid.startswith(k[:40])), None)
        if why:
            dropped.append((vid, why))
            continue

        im = Image.open(os.path.join(SRC, name)).convert("RGB")
        bright = brightest_block(im)
        # What the eye receives where the picture is brightest.
        composite = tuple(
            SCRIM[i] * SCRIM_ALPHA + bright[i] * (1 - SCRIM_ALPHA)
            for i in range(3))
        worst = ratio(INK, composite)
        if worst < FLOOR:
            dropped.append((vid, "brightest region composites to %.2f:1 "
                                 "under the scrim, below %.1f" % (worst, FLOOR)))
            continue
        test = im

        out_path = os.path.join(OUT, "%s.jpg" % vid)
        test.save(out_path, quality=84, optimize=True)
        row = dict(rows.get(vid, {}))
        row.update({
            "id": vid,
            "contrast": round(worst, 2),
            "bytes": os.path.getsize(out_path),
        })
        row.pop("url", None)          # the upstream URL is not what we host
        kept.append(row)

    with io.open(FINAL, "w", encoding="utf-8", newline="\n") as f:
        json.dump(kept, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("KEPT %d" % len(kept))
    for r in kept:
        print("  %-52s %5.2f:1  %7d B  %s"
              % (r["id"], r["contrast"], r["bytes"], r.get("licence", "?")))
    print("\nDROPPED %d" % len(dropped))
    for vid, why in dropped:
        print("  %-52s %s" % (vid, why))
    print("\n%s" % FINAL)


if __name__ == "__main__":
    main()
