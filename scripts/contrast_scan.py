"""Find low-contrast text in screenshots, by measurement (WCAG 2 ratio).

    py -3 scripts/contrast_scan.py OUT_DIR shot1.png [shot2.png ...]

Each screenshot is cut into 40 px tiles. In a tile, the background is its
most common colour; "ink" is every pixel far from it. The ink's contrast is
taken at its 90th percentile - the core of a stroke, not the anti-aliased
edge. A tile with enough ink whose core is under 3:1 is flagged; the
flagged tiles are outlined in red on a copy of the screenshot written to
OUT_DIR, and listed. A photo or a gradient can raise false flags, so every
flag is looked at by eye before anything is changed (trap #15: contrast is
measured, never judged).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1]
T = 40          # tile size, px
MIN_INK = 40    # ink pixels needed before a tile counts as text
FLAG = 3.0      # below this the text is not clearly readable


def lum(rgb):
    c = rgb / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def scan(path):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    h, w, _ = im.shape
    L = lum(im)
    flags = []
    # skip the status bar (top 110 px) and the gesture bar
    for y in range(110, h - 60, T):
        for x in range(0, w - T + 1, T):
            tile = im[y:y + T, x:x + T].reshape(-1, 3)
            q = (tile // 8).astype(np.int64)
            key = q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]
            vals, counts = np.unique(key, return_counts=True)
            if counts.max() < len(key) * 0.45:
                continue  # no dominant ground: photo, gradient, busy art
            bg = tile[key == vals[counts.argmax()]].mean(axis=0)
            dist = np.abs(tile - bg).sum(axis=1)
            ink = dist > 60
            if ink.sum() < MIN_INK:
                continue
            # A card's hairline border is faint on purpose and is not text:
            # ink along one line (few rows or few columns) is skipped, and
            # so is ink that is really the edge of a filled shape.
            grid = ink.reshape(T, T)
            rows = int(grid.any(axis=1).sum())
            cols = int(grid.any(axis=0).sum())
            if rows < 10 or cols < 10:
                continue
            per_row = grid.sum(axis=1)
            if per_row.max() > T * 0.8 or grid.sum(axis=0).max() > T * 0.8:
                continue
            if ink.mean() > 0.55:
                continue
            lt = L[y:y + T, x:x + T].reshape(-1)[ink]
            lb = lum(bg[None, :])[0]
            ratios = (np.maximum(lt, lb) + 0.05) / (np.minimum(lt, lb) + 0.05)
            core = np.percentile(ratios, 90)
            if core < FLAG:
                flags.append((x, y, core))
    # A word is wider than a tile; a card's rounded corner is one tile on
    # its own. Keep only flags with a flagged neighbour on the same row.
    at = {(x, y) for x, y, _ in flags}
    return [f for f in flags
            if (f[0] - T, f[1]) in at or (f[0] + T, f[1]) in at]


os.makedirs(OUT, exist_ok=True)
for p in sys.argv[2:]:
    flags = scan(p)
    if not flags:
        continue
    img = Image.open(p).convert('RGB')
    d = ImageDraw.Draw(img)
    for x, y, r in flags:
        d.rectangle([x, y, x + T - 1, y + T - 1], outline=(255, 0, 0), width=3)
    name = os.path.basename(p)
    img.save(os.path.join(OUT, 'FLAG_' + name))
    worst = min(r for _, _, r in flags)
    print(f'{name}: {len(flags)} tiles, worst {worst:.2f}:1')
