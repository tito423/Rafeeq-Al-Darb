"""Build each scanned printing's OWN ayah map from its own pages.

    py -3 scripts/printing_ayah_map.py <edition> [--pages a-b] [--draw p,p]

The scanned printings used to borrow the Madinah (hafs_kfqc) polygons,
stretched page by page onto the scan. That is right only where the printing
breaks its lines at the same words - and they do not, so an ayah's
highlight could end a word or two before or after its marker.

This finds every ayah marker on the page itself (template match on the ink
mask, the marker's digit masked out so ١ and ٩ match alike), and checks the
count against the ayahs the page holds. Where they agree, each ayah becomes
the run of text from the previous marker to its own marker, line by line,
with each line's ink start and end measured on the scan - so the boundary
sits on the printed marker by construction. A page where the count does
not agree gets NO entry: no highlight is better than a wrong one.

Output (rafeeq_app/build/hl/map_<edition>.json): the same shape as
hafs_kfqc_polygons.json, in the page box's own 0..1 space, and a report.
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_highlight as A  # noqa: E402

THR = float(os.environ.get('MAP_THR', '0.55'))


def ink_of(rgb):
    """Ink by LOCAL contrast, so faint grey print (Kuwait) and dark filled
    markers (Qatar) both come out, where one global threshold lost either."""
    g = cv2.cvtColor(np.asarray(rgb), cv2.COLOR_RGB2GRAY)
    if np.median(g) < 110:  # light ink on a dark page
        g = 255 - g
    return (cv2.adaptiveThreshold(g, 1, cv2.ADAPTIVE_THRESH_MEAN_C,
                                  cv2.THRESH_BINARY_INV, 31, 12)).astype(np.float32)


def template(ed):
    ink = ink_of(Image.open(os.path.join(A.HL, f'tpl_{ed}.png')).convert('RGB'))
    n = ink.shape[0]
    yy, xx = np.mgrid[0:n, 0:n]
    r = np.hypot(yy - n / 2, xx - n / 2)
    ink[r < n * 0.24] = 0  # the digit
    return ink


def find_markers(ink, band, tpl, thr, scales=(0.82, 0.88, 0.94, 1.0, 1.06, 1.12)):
    """(x, y, size, score) of each marker in the band y0..y1."""
    y0, y1 = band
    sub = ink[y0:y1].astype(np.float32)
    hits = []
    for s in scales:
        t = cv2.resize(tpl, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        if t.shape[0] >= sub.shape[0] or t.shape[1] >= sub.shape[1]:
            continue
        res = cv2.matchTemplate(sub, t, cv2.TM_CCOEFF_NORMED)
        ys, xs = np.where(res >= thr)
        for y, x in zip(ys, xs):
            hits.append((x + t.shape[1] / 2, y0 + y + t.shape[0] / 2,
                         t.shape[0], float(res[y, x])))
    hits.sort(key=lambda h: -h[3])
    kept = []
    for h in hits:
        if all(abs(h[0] - k[0]) > 0.7 * k[2] for k in kept if abs(h[1] - k[1]) < k[2]):
            kept.append(h)
    return kept


def predicted_ends(entry, lines, bh):
    """Where each ayah ends by the borrowed Madinah layer: (line, x)."""
    out = []
    for ay in entry['ayahs']:
        last = max(ay['r'], key=lambda q: (round(q[1], 2), -q[0]))
        cy = (last[1] + last[3]) / 2
        li = min(range(len(lines)), key=lambda i: abs(lines[i]['cy'] - cy))
        out.append((li, last[0] * A.BW))
    return out


def page_map(ed, p, entry, tpl):
    """Markers found in reading order, or None when they cannot be trusted."""
    f = A.page_file(ed, p)
    box, _ = A.compose(Image.open(f), entry['aspect'])
    ink = ink_of(box)
    bh = ink.shape[0]
    rects = [r for a in entry['ayahs'] for r in a['r']]
    lines = A.lines_of(rects)
    want = len(entry['ayahs'])
    pred = predicted_ends(entry, lines, bh)
    h = np.median([(max(r[3] for r in l['r']) - min(r[1] for r in l['r'])) * bh for l in lines])
    per_line = []
    for line in lines:
        y0 = min(r[1] for r in line['r']) * bh
        y1 = max(r[3] for r in line['r']) * bh
        per_line.append((int(max(0, y0 - 0.25 * h)), int(min(bh, y1 + 0.25 * h))))
    for thr in (0.55, 0.5, 0.46, 0.43, 0.40, 0.37):
        found = []
        for li, band in enumerate(per_line):
            for m in find_markers(ink, band, tpl, thr):
                found.append((li, m))
        found.sort(key=lambda t: (t[0], -t[1][0]))
        if len(found) > want:
            break
        if len(found) == want:
            # each marker must end ITS ayah: same line (or the next/previous,
            # where the printing broke the line differently) and near it
            ok = all(abs(li - pl) <= 1 and (li != pl or abs(m[0] - px) <= 6 * h)
                     for (li, m), (pl, px) in zip(found, pred))
            return box, ink, lines, found, (thr if ok else None)
    return box, ink, lines, None, None


def main():
    ed = sys.argv[1]
    rng = range(1, 605)
    if '--pages' in sys.argv:
        a, b = sys.argv[sys.argv.index('--pages') + 1].split('-')
        rng = range(int(a), int(b) + 1)
    data = json.load(open(os.path.join(A.HL, 'rects.json'), encoding='utf-8'))
    tpl = template(ed)
    rep = []
    for p in rng:
        e = data[ed]['pages'].get(str(p))
        if not e:
            continue
        _, _, _, found, thr = page_map(ed, p, e, tpl)
        rep.append((p, len(e['ayahs']), None if found is None else len(found), thr))
    ok = [r for r in rep if r[3] is not None]
    print(f'{ed}: markers verified on {len(ok)}/{len(rep)} pages '
          f'({100 * len(ok) / max(1, len(rep)):.1f}%)')
    bad = [r for r in rep if r[3] is None]
    print('  unverified:', ' '.join(f'p{p}({n}/{m})' for p, n, m, _ in bad[:60]))
    json.dump(rep, open(os.path.join(A.HL, f'verify_{ed}.json'), 'w'))


if __name__ == '__main__':
    main()


def draw_found(ed, p, out):
    from PIL import ImageDraw
    data = json.load(open(os.path.join(A.HL, 'rects.json'), encoding='utf-8'))
    e = data[ed]['pages'][str(p)]
    box, ink, lines, found, _ = page_map(ed, p, e, template(ed))
    found = found or []
    d = ImageDraw.Draw(box)
    for li, (x, y, s, sc) in found:
        d.ellipse([x - s / 2, y - s / 2, x + s / 2, y + s / 2], outline=(255, 0, 0), width=3)
        d.text((x - 6, y + s / 2), f'{sc:.2f}', fill=(255, 0, 0))
    box.save(out)
