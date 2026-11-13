"""Cut the owner's four quarter/hizb medallions out of his sheet.

Source: `owner_source_2026-11-13.jpg` (the owner sent it in chat on
2026-11-13 and asked for it on the TEXT mushaf in place of the drawn
plate). Top row, right to left as printed: «الحزب» eight-point star,
«ثلاثة أرباع الحزب» twelve-point star, «نصف الحزب» flower, «ربع الحزب»
circle. The small «الحزب ١..١٥» coins are not used: the mushaf has 60
ahzab, so the app writes the number itself.

For each medallion: crop, make the dark sheet background transparent
(flood fill from the crop border over background-coloured pixels, with a
soft edge and the navy spill taken back out of edge pixels so no dark
halo shows on the light theme), then paint the centre disc over in its
own navy so the baked-in Arabic words are gone: the app writes the words
in the reader's language (seven languages). Nothing else is redrawn.

Run: py -3 scripts/rub_medallions/build_rub_medallions.py
Writes rafeeq_app/assets/rub_medallions/{quarter,half,three_quarters,hizb}.png
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = Path(__file__).resolve().parent
SRC = HERE / "owner_source_2026-11-13.jpg"
OUT = HERE.parent.parent / "rafeeq_app" / "assets" / "rub_medallions"

# (name, crop box, centre-disc radius) measured on the 2752x1536 sheet:
# boxes from the bright-pixel extents of the top row, radii where the dark
# centre meets the inner gold ring (median over 24 rays, checked by eye).
MEDALLIONS = [
    ("quarter", (66, 61, 675, 669), 160),
    ("half", (747, 62, 1358, 673), 150),
    ("three_quarters", (1428, 60, 2026, 667), 140),
    ("hizb", (2092, 65, 2686, 666), 141),
]
PAD = 24  # keep the glow that spills past the bright extent
SIZE = 384  # output square, px (plate is at most ~100 dp, 3x)
BG_TOL = 34.0  # colour distance still counted as sheet background
EDGE = 30.0  # soft-edge width in the same colour distance


def cut(img: np.ndarray, box, radius):
    x0, y0, x1, y1 = box
    x0, y0, x1, y1 = x0 - PAD, y0 - PAD, x1 + PAD, y1 + PAD
    a = img[y0:y1, x0:x1].astype(np.float64)
    h, w, _ = a.shape
    # Background colour: the median of the crop's border (a gentle gradient).
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    # Background = background-like pixels connected to the crop border.
    like = dist < BG_TOL + EDGE
    lab, _ = ndimage.label(like)
    edge_labels = np.unique(
        np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outside = np.isin(lab, edge_labels[edge_labels > 0])
    alpha = np.ones((h, w))
    ramp = np.clip((dist - BG_TOL) / EDGE, 0, 1)
    alpha[outside] = ramp[outside]
    # Take the navy back out of semi-transparent edge pixels.
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.where(alpha[..., None] < 1, (a - (1 - alpha[..., None]) * bg) / safe, a)
    rgb = np.clip(rgb, 0, 255)

    # Centre disc: painted over in the median navy of a thin band just
    # inside the ring, with a feathered rim so the join does not show.
    cx, cy = (x1 - x0) / 2, (y1 - y0) / 2
    yy, xx = np.mgrid[0:h, 0:w]
    rr = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    band = (rr > radius - 22) & (rr < radius - 6)
    dark = a[band][a[band].max(axis=1) < 80]
    navy = np.median(dark, axis=0)
    inner = radius - 4
    feather = 6.0
    k = np.clip((inner - rr) / feather, 0, 1)
    # The eight-point star's centre is itself star-shaped: take in the dark
    # pockets joined to the disc (inside the ring only) so its points stay.
    pocket = (a.max(axis=2) < 80) & (rr < radius * 1.3)
    lab, _ = ndimage.label(pocket | (rr < inner))
    joined = lab == lab[int(cy), int(cx)]
    joined = ndimage.binary_erosion(joined, iterations=3)
    k = np.maximum(k, ndimage.gaussian_filter(joined.astype(float), 2))
    k = k[..., None]
    rgb = rgb * (1 - k) + navy * k

    out = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    disc = (inner - feather / 2) / side  # centre disc radius / side
    return sq.resize((SIZE, SIZE), Image.LANCZOS), disc, navy


def main():
    img = np.asarray(Image.open(SRC).convert("RGB"))
    OUT.mkdir(parents=True, exist_ok=True)
    for name, box, radius in MEDALLIONS:
        im, disc, navy = cut(img, box, radius)
        im.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}: disc radius = {disc:.4f} of side, navy = "
              f"#{int(navy[0]):02x}{int(navy[1]):02x}{int(navy[2]):02x}")


if __name__ == "__main__":
    main()
