"""Measure, page by page, whether the ayah highlight sits on the printed text.

    cd rafeeq_app && EDITIONS=build/hl/editions_borrowed.json flutter test --tags export --run-skipped test/export_highlight_rects_test.dart
    (editions_borrowed.json = editions.json as of 6c9f10f9, before the own maps)
    py -3 scripts/audit_highlight.py [edition ...] [--draw N,N,...]

Input: rafeeq_app/build/hl/rects.json (the rectangles exactly as
`_AyahHighlightPainter` draws them, in the page box's 0..1 space) and the
real page images in rafeeq_app/build/hl/pages/<folder>/NNN.(jpg|png).

The page is composed the way `MushafPageView` composes it: a box of the
fit's `pageAspect`, the scan `BoxFit.contain`-ed and centred in it. Then,
for every rectangle of every ayah:

* v   - vertical error: the ink-weighted centre of the text line under the
        rectangle, against the rectangle's own centre, in rectangle heights.
        0 = dead centre. The line is looked for within +-0.6 h.
* fill - share of the rectangle's columns that have any ink in them.
        A rectangle over blank paper scores low.
and for the page:
* recall - share of the text ink (inside the band the page's rectangles
        span) that some rectangle covers. Surah banners lower it on the pages
        that carry one, for every edition alike.

A page PASSES when |median v - BASE_V| <= 0.10, fill >= 0.80 and
recall >= 0.85. BASE_V is the Madinah (Hafs) median, where the highlight is
right by eye.
Writes rafeeq_app/build/hl/audit_<edition>.json and a summary, and with
--draw renders those pages with the rectangles over them for looking at.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HL = os.path.join(ROOT, 'rafeeq_app', 'build', 'hl')
FOLDER = {'tajweed_color': 'tajweed', 'madinah_gold': 'madinah_gold',
          'qatar': 'qatar', 'kuwait': 'kuwait', 'hafs_kfqc': 'hafs'}
BW = 1000  # box width in px
# Calibrated on hafs_kfqc (173 lines on 12 pages, highlight right by eye):
# the baseline sits 0.25 of a rectangle below its centre, and the rectangle
# reaches 2.4% / 2.3% of the page width past the ink on each side.
BASE_V = float(os.environ.get('BASE_V', '0.25'))
BASE_L = float(os.environ.get('BASE_L', '0.024'))
BASE_R = float(os.environ.get('BASE_R', '-0.0233'))
TOL_V, TOL_H = 0.16, 0.035


def page_file(ed, p):
    for ext in ('jpg', 'png'):
        f = os.path.join(HL, 'pages', FOLDER[ed], f'{p:03d}.{ext}')
        if os.path.exists(f) and os.path.getsize(f) > 0:
            return f
    return None


def compose(img, aspect):
    """The scan contain-fitted in a BW x BW/aspect box: (rgb box, ink mask)."""
    bh = int(round(BW / aspect))
    iw, ih = img.size
    s = min(BW / iw, bh / ih)
    w, h = max(1, int(round(iw * s))), max(1, int(round(ih * s)))
    ox, oy = (BW - w) // 2, (bh - h) // 2
    box = Image.new('RGB', (BW, bh), (0, 0, 0))
    box.paste(img.convert('RGB').resize((w, h), Image.LANCZOS), (ox, oy))
    a = np.asarray(box).astype(np.int16)
    gray = a.mean(axis=2)
    # Background = the commonest tone of the drawn page; ink = anything far
    # from it (dark ink on paper, or light ink on a dark page, or colour).
    region = gray[oy + h // 4: oy + 3 * h // 4, ox + w // 4: ox + 3 * w // 4]
    bg = np.median(region)
    colour = (a.max(axis=2) - a.min(axis=2)) > 90
    ink = (np.abs(gray - bg) > 70) | colour
    inside = np.zeros_like(ink)
    inside[oy:oy + h, ox:ox + w] = True
    return box, ink & inside


ALL = []


def lines_of(rects):
    """Rectangles grouped into printed lines (same vertical centre)."""
    rows = []
    for r in sorted(rects, key=lambda r: (r[1] + r[3]) / 2):
        cy = (r[1] + r[3]) / 2
        if rows and abs(rows[-1]['cy'] - cy) < (r[3] - r[1]) * 0.4:
            rows[-1]['r'].append(r)
        else:
            rows.append({'cy': cy, 'r': [r]})
    return rows


def measure(ed, p, entry):
    f = page_file(ed, p)
    if f is None:
        return None
    try:
        box, ink = compose(Image.open(f), entry['aspect'])
    except OSError:
        return None  # still downloading
    bh = ink.shape[0]
    rects = [r for a in entry['ayahs'] for r in a['r']
             if (r[2] - r[0]) * BW >= 3 and (r[3] - r[1]) * bh >= 3]
    if not rects:
        return None
    minx = min(r[0] for r in rects)
    maxx = max(r[2] for r in rects)
    bad = []
    covered = np.zeros_like(ink)
    for x0, y0, x1, y1 in rects:
        X0, X1 = int(round(x0 * BW)), int(round(x1 * BW))
        Y0, Y1 = int(round(y0 * bh)), int(round(y1 * bh))
        covered[Y0:Y1, X0:X1] = True
    vs, hs = [], []
    for line in lines_of(rects):
        y0 = min(r[1] for r in line['r']); y1 = max(r[3] for r in line['r'])
        Y0, Y1 = int(round(y0 * bh)), int(round(y1 * bh))
        h = Y1 - Y0
        cy = (Y0 + Y1) / 2
        L = min(r[0] for r in line['r']); R = max(r[2] for r in line['r'])
        X0, X1 = int(round(L * BW)), int(round(R * BW))
        # vertical: the line's BASELINE - in Arabic the densest ink row -
        # against the rectangle's centre, in rectangle heights
        a0, b0 = max(0, int(cy - 0.6 * h)), min(bh, int(cy + 0.6 * h))
        rows = ink[a0:b0, X0:X1].sum(axis=1).astype(float)
        k = max(1, h // 10)
        rows = np.convolve(rows, np.ones(k) / k, mode='same')
        v = ((a0 + int(np.argmax(rows))) - cy) / h if rows.max() > 0 else 1.0
        # horizontal: where the ink of this line starts and ends, searched a
        # little beyond the page's text block
        sa, sb = int(max(0, (minx - 0.04) * BW)), int(min(BW, (maxx + 0.04) * BW))
        core = ink[int(cy - 0.3 * h):int(cy + 0.3 * h), sa:sb]
        cols = np.where(core.sum(axis=0) >= 2)[0]
        if len(cols):
            il, ir = (sa + cols[0]) / BW, (sa + cols[-1]) / BW
            dl, dr = il - L - BASE_L, ir - R - BASE_R
        else:
            dl = dr = 1.0
        vs.append(v)
        hs.append(max(abs(dl), abs(dr)))
        ALL.append((ed, p, float(v), float(dl), float(dr)))
        if abs(v - BASE_V) > TOL_V or max(abs(dl), abs(dr)) > TOL_H:
            bad.append({'y': round(line['cy'], 3), 'v': round(float(v), 3),
                        'dl': round(float(dl), 4), 'dr': round(float(dr), 4)})
    ys = [r[1] for r in rects] + [r[3] for r in rects]
    band = np.zeros_like(ink)
    band[int(min(ys) * bh):int(max(ys) * bh), int(minx * BW):int(maxx * BW)] = True
    text = ink & band
    recall = float((text & covered).sum() / max(1, text.sum()))
    ok = not bad and recall >= 0.85
    return {'p': p, 'v': round(float(np.median(vs)), 3),
            'hmax': round(float(max(hs)), 4), 'recall': round(recall, 3),
            'bad_lines': bad, 'ok': bool(ok)}


def draw(ed, p, entry, out):
    f = page_file(ed, p)
    box, _ = compose(Image.open(f), entry['aspect'])
    over = Image.new('RGBA', box.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    bh = box.size[1]
    for i, a in enumerate(entry['ayahs']):
        c = (40, 200, 120, 90) if i % 2 == 0 else (230, 160, 40, 90)
        for x0, y0, x1, y1 in a['r']:
            d.rectangle([x0 * BW, y0 * bh, x1 * BW, y1 * bh], fill=c,
                        outline=(255, 0, 0, 255))
    Image.alpha_composite(box.convert('RGBA'), over).convert('RGB').save(out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    drawn = []
    if '--draw' in sys.argv:
        drawn = [int(x) for x in sys.argv[sys.argv.index('--draw') + 1].split(',')]
        args = [a for a in args if a != sys.argv[sys.argv.index('--draw') + 1]]
    data = json.load(open(os.path.join(HL, 'rects.json'), encoding='utf-8'))
    eds = args or [e for e in data if data[e]['raster']]
    lines = []
    for ed in eds:
        pages = data[ed]['pages']
        res = []
        for key, entry in pages.items():
            r = measure(ed, int(key), entry)
            if r:
                res.append(r)
        for p in drawn:
            if str(p) in pages and page_file(ed, p):
                draw(ed, p, pages[str(p)], os.path.join(HL, f'draw_{ed}_{p:03d}.png'))
        json.dump(res, open(os.path.join(HL, f'audit_{ed}.json'), 'w'))
        if not res:
            lines.append(f'{ed}: no pages measured')
            continue
        ok = sum(r['ok'] for r in res)
        med = lambda k: float(np.median([r[k] for r in res]))
        nb = sum(len(r['bad_lines']) for r in res)
        worst = sorted(res, key=lambda r: -r['hmax'])[:6]
        lines.append(
            f'{ed}: {ok}/{len(res)} pages pass ({100 * ok / len(res):.1f}%) | '
            f'bad lines {nb} | median v {med("v"):.3f} hmax {med("hmax"):.4f} '
            f'recall {med("recall"):.3f} | worst h: '
            + ', '.join(f'p{r["p"]}={r["hmax"]}' for r in worst))
    if os.environ.get('STATS'):
        for ed in eds:
            r = [x for x in ALL if x[0] == ed]
            for i, n in ((2, 'v'), (3, 'dl'), (4, 'dr')):
                col = sorted(x[i] for x in r)
                q = lambda f: col[int(f * (len(col) - 1))]
                lines.append(f'  {ed} {n}: p01 {q(.01):.4f} p05 {q(.05):.4f} '
                             f'median {q(.5):.4f} p95 {q(.95):.4f} '
                             f'p99 {q(.99):.4f} (n={len(col)})')
    report = '\n'.join(lines)
    open(os.path.join(HL, 'audit_summary.txt'), 'w', encoding='utf-8').write(report)
    print(report)


if __name__ == '__main__':
    main()
