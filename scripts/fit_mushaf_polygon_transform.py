"""Fit the affine that carries the Hafs/Madinah ayah polygons onto another
printing, so a raster edition gets real ayah highlighting and tap-to-sciences
without a coordinate layer of its own.

WHY THIS IS EVEN POSSIBLE
    The KFQC vector edition ships an `ayahPolygon` hit layer, normalised 0..1
    of the page box. A printing that sets the SAME 15-line Madinah grid differs
    from it only by a uniform scale and offset -- its decorative border eats
    margin, nothing else moves. Where that holds, one axis-aligned affine per
    page GROUP maps every polygon onto the scan.

    It does NOT hold for a printing that typesets its own way. Measured this
    session: `madinah_gold` sets 6 lines on its page 2 where the Madinah mushaf
    sets 15, and `shamarly` (521 pages) and `indopak_tajweed` (564) paginate
    differently again. No transform can fix a different typesetting; those
    three need a coordinate layer built from scratch, and until they have one
    they honestly ship without a highlight.

HOW THE FIT IS MADE (tajweed_color, verified)
    1. Census every page's real pixel size. Two groups, no exceptions:
       602 pages at 861x1317 and pages 1-2 at 901x1476 (the two illuminated
       opening pages, which carry their own frame and their own text block).
    2. On the Hafs side, recover the LINE BOUNDARIES. The polygon rings
       collapse runs of whole lines into one tall rectangle, so a tall ring is
       subdivided by the shortest ring on the page -- which is exactly one line.
    3. On the scan, read the printed lines as ink row-runs inside the border,
       keeping only lines that span the block (a basmalah or a surah name is
       narrower and would drag the grid).
    4. Least-squares fit y' = sy*y + dy on the line centres, and x' = sx*x + dx
       on the block edges.
    5. RENDER the mapped polygons over the real scans and look at them. The
       numbers are not the evidence; the pictures are.

    Measured result: worst residual 23 px on a 1317 px page = 0.28 of a line,
    and every ayah band sits on its own ayah on pages 1, 2, 50, 200, 400, 604
    -- including page 604, which carries three surah headers and three
    basmalahs that the polygons correctly skip.

    py -3 scripts/fit_mushaf_polygon_transform.py            # fit + render
    py -3 scripts/fit_mushaf_polygon_transform.py --census   # page sizes only
"""

import concurrent.futures as cf
import io
import json
import os
import struct
import sys
import time
import urllib.request

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "rafeeq_app")
POLY_PATH = os.path.join(APP, "assets", "data", "mushaf", "hafs_kfqc_polygons.json")
BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/mushaf/tajweed"
WORK = os.path.join(ROOT, "scripts", "mushaf_fit_build")

# Pages the fit is measured on. A spread across the whole mushaf, plus the two
# opening pages, plus 604 -- the worst case, three surahs on one page.
BODY_SAMPLE = [3, 4, 11, 25, 50, 77, 99, 123, 150, 177, 200, 222, 250, 277,
               300, 333, 355, 380, 400, 420, 455, 480, 500, 522, 545, 560,
               580, 590, 600, 604]
PROOF = [1, 2, 50, 200, 400, 604]

POLY = json.load(io.open(POLY_PATH, encoding="utf-8"))


# --------------------------------------------------------------------------
# fetching
# --------------------------------------------------------------------------
def fetch(page, byte_range=None):
    """R2 answers a bare urllib request with 403; it wants a User-Agent."""
    headers = {"User-Agent": "rafeeq-mushaf-fit/1.0"}
    if byte_range:
        headers["Range"] = byte_range
    last = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(f"{BASE}/{page:03d}.jpg", headers=headers)
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read()
        except Exception as e:                                   # noqa: BLE001
            last = e
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError(f"page {page}: {last}")


def local(page):
    os.makedirs(WORK, exist_ok=True)
    path = os.path.join(WORK, "%03d.jpg" % page)
    if not os.path.isfile(path):
        _, body = fetch(page)
        with open(path, "wb") as f:
            f.write(body)
    return path


def jpeg_size(buf):
    i = 2
    while i < len(buf) - 9:
        if buf[i] != 0xFF:
            i += 1
            continue
        m = buf[i + 1]
        if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
            h, w = struct.unpack(">HH", buf[i + 5:i + 9])
            return w, h
        i += 2 + struct.unpack(">H", buf[i + 2:i + 4])[0]
    return None


def census(pages=604):
    """Every page's real size, read from its JPEG header. 128 KB is enough to
    reach the SOF marker past this scan's colour-profile segments."""
    def one(p):
        st, buf = fetch(p, "bytes=0-131071")
        return p, st, jpeg_size(buf)

    groups = {}
    with cf.ThreadPoolExecutor(8) as ex:
        for p, st, sz in ex.map(one, range(1, pages + 1)):
            if st not in (200, 206) or sz is None:
                raise RuntimeError(f"page {p}: status {st}, size {sz}")
            groups.setdefault(sz, []).append(p)
    return {k: sorted(v) for k, v in groups.items()}


# --------------------------------------------------------------------------
# the Hafs side
# --------------------------------------------------------------------------
def hafs_lines(page, tol=0.004):
    """Line slots (top, bottom) on a Hafs page, in its normalised space."""
    edges, heights = set(), []
    for row in POLY["pages"][str(page)]:
        for ring in row[2]:
            ys = [q[1] for q in ring]
            edges.add(min(ys)); edges.add(max(ys))
            heights.append(max(ys) - min(ys))
    e = sorted(edges)
    merged = [e[0]]
    for v in e[1:]:
        if v - merged[-1] > tol:
            merged.append(v)
    # A one-line ring is the SHORTEST kind on the page; anything taller is a
    # run of whole lines. The median is useless where a page has only one short
    # ring -- page 2 has exactly one.
    unit = min(h for h in heights if h > 0.02)
    out = []
    for t, b in zip(merged, merged[1:]):
        n = max(1, int(round((b - t) / unit)))
        step = (b - t) / n
        out += [(t + k * step, t + (k + 1) * step) for k in range(n)]
    return out


def hafs_block_x(page):
    xs = [q[0] for row in POLY["pages"][str(page)] for ring in row[2] for q in ring]
    return min(xs), max(xs)


# --------------------------------------------------------------------------
# the scan side
# --------------------------------------------------------------------------
def scan_body_lines(path, thresh=205):
    """Printed lines on a body page, with the ornament bands and the page
    rules masked off first. >90% of the row inked is the solid ornament band;
    a Quran line, however dense, never fills a row edge to edge."""
    a = np.asarray(Image.open(path).convert("L"), dtype=np.uint8)
    H, W = a.shape
    ink = a < thresh

    rowf = ink.sum(axis=1) / W
    dense = np.where(rowf > 0.90)[0]
    top = dense[dense < H * 0.10].max() + 1 if (dense < H * 0.10).any() else 0
    bot = dense[dense > H * 0.90].min() if (dense > H * 0.90).any() else H

    colf = ink[top:bot].sum(axis=0) / max(1, bot - top)
    rules = np.where(colf > 0.90)[0]
    left = rules[rules < W * 0.10].max() + 1 if (rules < W * 0.10).any() else 0
    right = rules[rules > W * 0.90].min() if (rules > W * 0.90).any() else W

    return _runs(ink[top:bot, left:right], top, left, H, W)


def scan_opening_lines(path):
    """The two illuminated pages instead. Their inner panel is found as the
    band of rows carrying a long unbroken white run -- the ornament never has
    one -- so the tajweed colour legend and the footnotes printed BELOW the
    panel cannot be mistaken for Quran lines."""
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
    H, W, _ = rgb.shape
    lum = rgb.mean(axis=2)
    white = (lum > 225) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 30)

    def longest(row):
        best = c = 0
        for v in row:
            c = c + 1 if v else 0
            best = max(best, c)
        return best

    rows = np.where(np.array([longest(white[i]) for i in range(H)]) > W * 0.5)[0]
    r0, r1 = rows.min(), rows.max()
    cols = np.where(white[r0:r1 + 1].mean(axis=0) > 0.5)[0]
    return _runs(lum[r0:r1 + 1, cols.min():cols.max() + 1] < 150,
                 r0, cols.min(), H, W)


def _runs(mask, off_y, off_x, H, W, min_frac=0.015):
    h, w = mask.shape
    prof = mask.sum(axis=1) / w
    out, s = [], None
    for i, v in enumerate(list(prof > min_frac) + [False]):
        if v and s is None:
            s = i
        elif not v and s is not None:
            if i - s >= h * 0.012:
                cc = np.where(mask[s:i].any(axis=0))[0]
                out.append(dict(y0=(s + off_y) / H, y1=(i - 1 + off_y) / H,
                                x0=(cc.min() + off_x) / W,
                                x1=(cc.max() + off_x) / W))
            s = None
    return out


# --------------------------------------------------------------------------
# the fit
# --------------------------------------------------------------------------
def lsq(h, s):
    A = np.vstack([np.array(h), np.ones(len(h))]).T
    (a, b), *_ = np.linalg.lstsq(A, np.array(s), rcond=None)
    return float(a), float(b), np.array(s) - (a * np.array(h) + b)


def fit_body():
    hy, sy, hx, sx = [], [], [], []
    used = 0
    for page in BODY_SAMPLE:
        if page <= 2:
            continue
        lines = [L for L in scan_body_lines(local(page)) if L["x1"] - L["x0"] > 0.90]
        slots = hafs_lines(page)
        if len(lines) == len(slots):
            used += 1
            hy += [(t + b) / 2 for t, b in slots]
            sy += [(L["y0"] + L["y1"]) / 2 for L in lines]
        sx += [(L["x0"], L["x1"]) for L in lines]
        hx.append(hafs_block_x(page))
    a, b, res = lsq(hy, sy)
    h0 = np.median([p[0] for p in hx]); h1 = np.median([p[1] for p in hx])
    s0 = np.median([p[0] for p in sx]); s1 = np.median([p[1] for p in sx])
    ax = (s1 - s0) / (h1 - h0)
    return dict(sx=float(ax), dx=float(s0 - ax * h0), sy=a, dy=b), res, used, len(hy)


def fit_opening(page, drop_leading):
    """`drop_leading` skips the surah-header band, and on page 2 the basmalah
    as well -- al-Baqarah's basmalah is not an ayah, while al-Fatiha's IS
    ayah 1 and must be kept."""
    lines = scan_opening_lines(local(page))[1 + drop_leading:]
    slots = hafs_lines(page)
    if len(lines) != len(slots):
        raise RuntimeError(f"page {page}: {len(lines)} scan lines vs "
                           f"{len(slots)} hafs lines")
    a, b, res = lsq([(t + bb) / 2 for t, bb in slots],
                    [(L["y0"] + L["y1"]) / 2 for L in lines])
    h0, h1 = hafs_block_x(page)
    s0 = np.median([L["x0"] for L in lines]); s1 = np.median([L["x1"] for L in lines])
    ax = (s1 - s0) / (h1 - h0)
    return dict(sx=float(ax), dx=float(s0 - ax * h0), sy=a, dy=b), res


def render(page, fit, out_dir):
    im = Image.open(local(page)).convert("RGB")
    W, H = im.size
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    cols = [(220, 30, 30), (30, 120, 220), (30, 170, 60), (200, 130, 0),
            (150, 40, 190), (0, 160, 170)]
    for i, row in enumerate(POLY["pages"][str(page)]):
        c = cols[i % len(cols)]
        for ring in row[2]:
            d.polygon([((q[0] * fit["sx"] + fit["dx"]) * W,
                        (q[1] * fit["sy"] + fit["dy"]) * H) for q in ring],
                      fill=c + (70,), outline=c + (255,))
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "overlay_%03d.png" % page)
    Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB").save(out)
    return out


def main():
    if "--census" in sys.argv:
        for sz, ps in sorted(census().items(), key=lambda kv: -len(kv[1])):
            print(f"{sz[0]}x{sz[1]}  aspect {sz[0] / sz[1]:.5f}  {len(ps)} pages "
                  f"({ps[0]}..{ps[-1]})")
        return

    body, res, used, n = fit_body()
    pitch = 0.0639                      # measured line pitch on a body scan
    print(f"BODY  ({used}/{len(BODY_SAMPLE)} sample pages matched, {n} lines)")
    print(f"  x' = {body['sx']:.6f}*x + {body['dx']:.6f}")
    print(f"  y' = {body['sy']:.6f}*y + {body['dy']:.6f}")
    print(f"  worst residual {abs(res).max():.5f} = {abs(res).max() / pitch:.3f} "
          f"line = {abs(res).max() * 1317:.1f} px of 1317")

    pages = {}
    for page, drop in ((1, 0), (2, 1)):
        f, r = fit_opening(page, drop)
        pages[str(page)] = f
        print(f"OPENING page {page}")
        print(f"  x' = {f['sx']:.6f}*x + {f['dx']:.6f}")
        print(f"  y' = {f['sy']:.6f}*y + {f['dy']:.6f}")
        print(f"  worst residual {abs(r).max():.5f} = {abs(r).max() * 1476:.1f} px of 1476")

    body["page_aspect"] = round(861 / 1317, 5)
    for p in pages.values():
        p["page_aspect"] = round(901 / 1476, 5)

    out = os.path.join(ROOT, "scripts", "mushaf_polygon_fit.json")
    io.open(out, "w", encoding="utf-8").write(
        json.dumps({"edition": "tajweed_color",
                    "source_polygons": "hafs_kfqc",
                    "default": body, "pages": pages},
                   ensure_ascii=False, indent=1))
    print(f"\nwrote {out}")

    proof_dir = os.path.join(WORK, "proof")
    for p in PROOF:
        print("  proof ->", render(p, pages.get(str(p), body), proof_dir))
    print("\nLOOK AT THOSE IMAGES. The numbers above are not the evidence.")


if __name__ == "__main__":
    main()
