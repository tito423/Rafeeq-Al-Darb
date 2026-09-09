"""Fit the Hafs ayah polygons onto a printing whose leaves were cropped
individually — one affine per page, derived from a fiducial the page carries.

WHY THIS EXISTS BESIDE `fit_mushaf_polygon_transform.py`
    That script fits ONE affine for a whole page group. It works for the
    Tajweed printing because every body page there is the same 861x1317 crop.

    مصحف قطر is not like that. Its embedded scans run 1720-1779 x 2294-2399 and,
    measured on nine pages spread over the mushaf, its printed frame keeps a
    near-constant SIZE (width 0.7148-0.7307, height 0.8094-0.8201 of the page,
    sd under 0.005) while its POSITION slides by up to 0.03 of the page width —
    26 px, about two letters. One affine cannot absorb that; the highlight
    would sit two letters off on some pages and be right on others.

THE METHOD
    The frame is the fiducial. It is printed, not scanned in, so its position
    on the page *is* the crop.

      1. Locate the frame on every page. Saturation, not darkness: the frame is
         red and gold, the Quran text is near-black and barely saturated, the
         paper is not saturated at all. Take each row's leftmost and rightmost
         saturated pixel and use the MEDIAN across rows, so a hizb ornament out
         in the margin (page 100 has one) is one row's outlier, not the answer.
      2. On the pages where the printed lines can be counted cleanly, fit
         hafs -> page coordinates the usual way, then re-express that fit in
         FRAME-RELATIVE coordinates: u = (x - left) / (right - left).
      3. Those frame-relative fits agree across pages — that is the thing being
         tested, and the run prints their spread so it can be judged.
      4. Every page then gets its own affine: hafs -> frame-relative -> that
         page's own measured frame box.

    Output: `scripts/<edition>_polygon_fit_pages.json`, one entry per page,
    ready to paste into `editions.json` under `polygon_fit.pages`.

    As always the numbers are not the evidence. `--proof` renders the mapped
    polygons over the real pages so they can be looked at.

    py -3 scripts/fit_mushaf_polygon_per_page.py qatar --fit
    py -3 scripts/fit_mushaf_polygon_per_page.py qatar --proof 1 50 100 300 604
"""

import argparse
import io
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "rafeeq_app")
POLY = json.load(io.open(os.path.join(
    APP, "assets", "data", "mushaf", "hafs_kfqc_polygons.json"), encoding="utf-8"))

EDITIONS = {
    "qatar": dict(
        dir=os.path.join(ROOT, "scripts", "mushaf_pdf_build", "qatar"),
        pages=604, sat_min=45, ink_max=150,
        # How far inside the printed frame to look for text. The side bands are
        # thick relative to the frame width, so x needs a bigger inset than y;
        # at a symmetric 0.09 every row still caught a band and the whole page
        # merged into one run, and at 0.09 on y the last line was cut in half.
        inset=(0.10, 0.025),
        # The two illuminated openings carry a much heavier frame, and
        # al-Baqarah's basmalah is a printed line with no ayah polygon behind
        # it (al-Fatiha's IS ayah 1, so page 1 drops nothing).
        # The two illuminated openings. `panel` is (top, bottom, left, right)
        # of the white text panel, measured off the rendered page. Page 1 is
        # al-Fatiha, whose basmalah IS ayah 1, so nothing is dropped; page 2 is
        # al-Baqarah, whose basmalah is a printed line with no ayah behind it.
        special={1: dict(panel=(0.333, 0.675, 0.203, 0.578), drop_leading=0),
                 2: dict(panel=(0.326, 0.668, 0.468, 0.838), drop_leading=1)},
    ),
}


# ---------------------------------------------------------------- the scan
def load(spec, page):
    path = os.path.join(spec["dir"], "%03d.jpg" % page)
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def frame_box(rgb, sat_min):
    """(top, bottom, left, right) of the printed frame, normalised 0..1."""
    H, W, _ = rgb.shape
    col = (rgb.max(axis=2) - rgb.min(axis=2)) > sat_min
    rows = np.where(col.any(axis=1))[0]
    cols = np.where(col.any(axis=0))[0]
    if rows.size < H * 0.3 or cols.size < W * 0.3:
        return None
    lefts = [np.where(col[y])[0][0] for y in rows]
    rights = [np.where(col[y])[0][-1] for y in rows]
    tops = [np.where(col[:, x])[0][0] for x in cols]
    bots = [np.where(col[:, x])[0][-1] for x in cols]
    return (float(np.median(tops)) / H, float(np.median(bots)) / H,
            float(np.median(lefts)) / W, float(np.median(rights)) / W)


def printed_lines(rgb, box, ink_max, inset=(0.10, 0.025)):
    """Ink row-runs strictly inside the frame, normalised to the whole page."""
    xi, yi = inset
    H, W, _ = rgb.shape
    t, b, l, r = box
    fh, fw = b - t, r - l
    y0, y1 = int((t + fh * yi) * H), int((b - fh * yi) * H)
    x0, x1 = int((l + fw * xi) * W), int((r - fw * xi) * W)
    core = rgb[y0:y1, x0:x1].mean(axis=2) < ink_max
    h, w = core.shape
    prof = core.sum(axis=1) / w
    runs, s = [], None
    for i, v in enumerate(list(prof > 0.02) + [False]):
        if v and s is None:
            s = i
        elif not v and s is not None:
            if i - s >= h * 0.015:
                cc = np.where(core[s:i].any(axis=0))[0]
                runs.append(dict(y0=(s + y0) / H, y1=(i - 1 + y0) / H,
                                 x0=(cc.min() + x0) / W, x1=(cc.max() + x0) / W))
            s = None
    return runs


def panel_lines(rgb, ink_max, panel, pad=0.004):
    """Text runs inside a hand-measured panel box.

    The two illuminated openings defeated every automatic attempt: the text
    panel is flanked left and right by full-height ornament columns, so every
    row inside the frame carries ink and the whole page comes back as one run;
    and the cream page margin outside the illumination is near-white, so a
    white-panel search returns the sheet. The panel was therefore read off the
    rendered page by eye — four numbers, once, for two pages — and is recorded
    in EDITIONS. Inside it the seven lines separate cleanly and evenly.
    """
    H, W, _ = rgb.shape
    t, b, l, r = panel
    y0, y1 = int((t + pad) * H), int((b - pad) * H)
    x0, x1 = int((l + pad) * W), int((r - pad) * W)
    core = rgb[y0:y1, x0:x1].mean(axis=2) < ink_max
    h, w = core.shape
    prof = core.sum(axis=1) / w
    runs, st = [], None
    for i, v in enumerate(list(prof > 0.02) + [False]):
        if v and st is None:
            st = i
        elif not v and st is not None:
            if i - st >= h * 0.02:
                cc = np.where(core[st:i].any(axis=0))[0]
                runs.append(dict(y0=(st + y0) / H, y1=(i - 1 + y0) / H,
                                 x0=(cc.min() + x0) / W,
                                 x1=(cc.max() + x0) / W))
            st = None
    return runs


# ---------------------------------------------------------------- the Hafs side
def hafs_lines(page, tol=0.004):
    rows = POLY["pages"].get(str(page))
    if not rows:
        return []
    edges, heights = set(), []
    for row in rows:
        for ring in row[2]:
            ys = [q[1] for q in ring]
            edges.add(min(ys)); edges.add(max(ys))
            heights.append(max(ys) - min(ys))
    e = sorted(edges)
    merged = [e[0]]
    for v in e[1:]:
        if v - merged[-1] > tol:
            merged.append(v)
    unit = min(h for h in heights if h > 0.02)
    out = []
    for t, b in zip(merged, merged[1:]):
        n = max(1, int(round((b - t) / unit)))
        step = (b - t) / n
        out += [(t + k * step, t + (k + 1) * step) for k in range(n)]
    return out


def hafs_x(page):
    xs = [q[0] for row in POLY["pages"][str(page)] for ring in row[2] for q in ring]
    return min(xs), max(xs)


def lsq(h, s):
    A = np.vstack([np.array(h), np.ones(len(h))]).T
    (a, b), *_ = np.linalg.lstsq(A, np.array(s), rcond=None)
    return float(a), float(b), np.array(s) - (a * np.array(h) + b)


# ---------------------------------------------------------------- the fit
def hafs_grid(sample=range(3, 605, 7), tol=0.012):
    """The Madinah 15-line grid, in Hafs normalised space.

    Recovered rather than assumed: collect every line-slot centre across a
    sample of pages and cluster them. They collapse to exactly 15 clusters,
    which is what makes a slot-for-slot match with the printed page legitimate.
    """
    # Only pages whose slots come out as a clean 15 contribute. `hafs_lines`
    # subdivides a tall ring by the shortest ring on that page, and on a page
    # whose shortest ring is a little short it over-splits — those spurious
    # centres fall between real grid positions and bridge the clusters
    # (clustering everything gave 26 groups instead of 15).
    vals = []
    for page in sample:
        if str(page) not in POLY["pages"]:
            continue
        slots = hafs_lines(page)
        if len(slots) == 15:
            vals += [(t + b) / 2 for t, b in slots]
    vals.sort()
    groups, cur = [], [vals[0]]
    for v in vals[1:]:
        if v - cur[-1] <= tol:
            cur.append(v)
        else:
            groups.append(cur); cur = [v]
    groups.append(cur)
    return [float(np.mean(g)) for g in groups], [len(g) for g in groups]


def fit(edition, verbose=True):
    """One affine per page.

    On a body page the fifteen detected ink runs ARE the fifteen slots of the
    Madinah grid — every slot holds something, whether a line of Quran, a surah
    header band or a basmalah — so slot k matches run k with no ambiguity and
    no need to guess which runs the polygons cover. That is measured, not
    assumed: the run count is checked to be 15 on every body page and the page
    is skipped (and reported) if it is not.
    """
    spec = EDITIONS[edition]
    grid, counts = hafs_grid()
    if len(grid) != 15:
        raise RuntimeError("expected a 15-line grid, clustered %d" % len(grid))
    if verbose:
        print("Hafs grid: %d slots, samples per slot %s" % (len(grid), counts))

    # the Hafs text block in x, taken over the whole mushaf rather than one page
    xs0, xs1 = [], []
    for page in range(3, 605, 7):
        if str(page) in POLY["pages"]:
            a, b = hafs_x(page)
            xs0.append(a); xs1.append(b)
    HX0, HX1 = float(np.median(xs0)), float(np.median(xs1))
    if verbose:
        print("Hafs block x: %.4f - %.4f" % (HX0, HX1))

    out, skipped, resid = {}, [], []
    boxes, shapes = {}, {}
    for page in range(1, spec["pages"] + 1):
        rgb = load(spec, page)
        H, W, _ = rgb.shape
        box = frame_box(rgb, spec["sat_min"])
        if box is None:
            raise RuntimeError("page %d: no frame found" % page)
        boxes[page], shapes[page] = box, (H, W)

        sp = spec.get("special", {}).get(page)
        if sp and sp.get("panel"):
            runs = panel_lines(rgb, spec["ink_max"], sp["panel"])
        else:
            runs = printed_lines(rgb, box, spec["ink_max"],
                                 inset=sp["inset"] if sp else spec["inset"])
        if sp:
            runs = runs[sp["drop_leading"]:]
            targets = [(t + b) / 2 for t, b in hafs_lines(page)]
            hx0, hx1 = hafs_x(page)
        else:
            targets = grid
            hx0, hx1 = HX0, HX1

        if len(runs) != len(targets):
            skipped.append((page, len(runs), len(targets)))
            continue

        ay, by, ry = lsq(targets, [(L["y0"] + L["y1"]) / 2 for L in runs])
        sx0 = float(np.median([L["x0"] for L in runs]))
        sx1 = float(np.median([L["x1"] for L in runs]))
        ax = (sx1 - sx0) / (hx1 - hx0)
        bx = sx0 - ax * hx0
        resid.append(abs(ry).max())
        out[str(page)] = dict(sx=round(ax, 6), dx=round(bx, 6),
                              sy=round(ay, 6), dy=round(by, 6),
                              page_aspect=round(W / H, 5))
        if verbose and page % 100 == 0:
            print("  fitted %d/%d" % (page, spec["pages"]))

    # ---- reject a page whose own fit is an outlier -----------------------
    # A page can produce 15 runs and still be wrong: two lines merging while a
    # header splits leaves the count right and the assignment shifted. Such a
    # page shows up as a large residual, so it is thrown back into the same
    # bucket as the pages that never matched.
    if resid:
        cut = float(np.median(resid) * 6)
        for page, rr in list(zip([int(k) for k in out], resid)):
            if rr > cut:
                skipped.append((page, "residual %.4f > %.4f" % (rr, cut), 15))
                del out[str(page)]

    # ---- fill every remaining page from the frame ------------------------
    # Each fitted page's affine, re-expressed against its own frame box, gives
    # the same numbers to within a hair — that agreement IS the evidence the
    # frame is a valid fiducial, and it is printed below. The median of those
    # is then applied to the frame box of every page that has no fit of its own.
    # Only body pages. The two illuminated openings set a different block
    # entirely, and including them widened the spread tenfold — they are not
    # evidence about where a body page's text sits relative to its frame.
    rel = []
    for k, f in out.items():
        if int(k) in spec.get("special", {}):
            continue
        t, b, l, r = boxes[int(k)]
        rel.append((f["sx"] / (r - l), (f["dx"] - l) / (r - l),
                    f["sy"] / (b - t), (f["dy"] - t) / (b - t)))
    rel = np.array(rel)
    med = rel.mean(axis=0)
    if verbose:
        print("\nhafs -> FRAME-RELATIVE, from %d fitted pages:" % len(rel))
        for i, name in enumerate(("sx", "dx", "sy", "dy")):
            print("   %-3s mean %.6f  sd %.6f  spread %.6f"
                  % (name, rel[:, i].mean(), rel[:, i].std(),
                     rel[:, i].max() - rel[:, i].min()))

    # A page whose frame box is itself implausible cannot be filled from it.
    # Page 210 is a case in point: its source image is corrupt (a flat green
    # block over most of the sheet), so the saturation search returned the
    # whole page as the "frame" and the fill produced polygons four times too
    # large. Such a page takes the affine of the nearest page that WAS fitted
    # directly — consecutive leaves are cropped alike — and is reported.
    ws = np.array([boxes[p][3] - boxes[p][2] for p in boxes
                   if p not in spec.get("special", {})])
    hs = np.array([boxes[p][1] - boxes[p][0] for p in boxes
                   if p not in spec.get("special", {})])
    wlo, whi = np.median(ws) * 0.93, np.median(ws) * 1.07
    hlo, hhi = np.median(hs) * 0.93, np.median(hs) * 1.07

    direct = sorted(int(k) for k in out)
    filled, borrowed = [], []
    for page, *_ in skipped:
        t, b, l, r = boxes[page]
        fw, fh = r - l, b - t
        H, W = shapes[page]
        if wlo <= fw <= whi and hlo <= fh <= hhi:
            out[str(page)] = dict(sx=round(med[0] * fw, 6),
                                  dx=round(med[1] * fw + l, 6),
                                  sy=round(med[2] * fh, 6),
                                  dy=round(med[3] * fh + t, 6),
                                  page_aspect=round(W / H, 5))
            filled.append(page)
        else:
            near = min(direct, key=lambda q: abs(q - page))
            e = dict(out[str(near)])
            e["page_aspect"] = round(W / H, 5)
            out[str(page)] = e
            borrowed.append((page, near, round(fw, 4), round(fh, 4)))

    if verbose and borrowed:
        print("   frame box implausible, affine borrowed from the nearest "
              "directly-fitted page: %s" % (borrowed,))

    if verbose:
        r = np.array(resid)
        print("\nfitted directly: %d pages   filled from the frame: %d"
              % (len(out) - len(filled), len(filled)))
        print("   direct residual: median %.5f  95th %.5f  max %.5f"
              % (np.median(r), np.percentile(r, 95), r.max()))
        if filled:
            print("   filled pages: %s" % (sorted(filled)[:40],))
    return out, skipped, filled


def render(edition, page, fit_entry, out_dir):
    spec = EDITIONS[edition]
    im = Image.open(os.path.join(spec["dir"], "%03d.jpg" % page)).convert("RGB")
    W, H = im.size
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    cols = [(220, 30, 30), (30, 120, 220), (30, 170, 60), (200, 130, 0),
            (150, 40, 190), (0, 160, 170)]
    for i, row in enumerate(POLY["pages"][str(page)]):
        c = cols[i % len(cols)]
        for ring in row[2]:
            d.polygon([((q[0] * fit_entry["sx"] + fit_entry["dx"]) * W,
                        (q[1] * fit_entry["sy"] + fit_entry["dy"]) * H)
                       for q in ring], fill=c + (70,), outline=c + (255,))
    os.makedirs(out_dir, exist_ok=True)
    p = os.path.join(out_dir, "overlay_%03d.png" % page)
    Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB").save(p)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("edition", choices=sorted(EDITIONS))
    ap.add_argument("--fit", action="store_true")
    ap.add_argument("--proof", nargs="*", type=int)
    a = ap.parse_args()

    out_path = os.path.join(ROOT, "scripts",
                            "%s_polygon_fit_pages.json" % a.edition)
    if a.fit:
        fits, skipped, filled = fit(a.edition)
        io.open(out_path, "w", encoding="utf-8").write(
            json.dumps(fits, ensure_ascii=False, indent=1))
        print("\nwrote %s (%d pages)" % (out_path, len(fits)))

    if a.proof is not None:
        fits = json.load(io.open(out_path, encoding="utf-8"))
        d = os.path.join(EDITIONS[a.edition]["dir"], "proof")
        for p in (a.proof or [1, 50, 100, 300, 604]):
            print("  ", render(a.edition, p, fits[str(p)], d))
        print("\nLOOK AT THOSE IMAGES.")


if __name__ == "__main__":
    main()
