"""Ayah by ayah: does each ayah's highlight END on its printed ayah marker?

    py -3 scripts/audit_ayah_markers.py [edition ...] [--pages 1-604]

Every ayah ends at its round number marker. For each ayah on each page,
the end of its highlight (the left edge of its last line - Arabic runs
right to left) is compared with the nearest round marker the image really
has on that line, found with a Hough circle search in a window around it.
Distances are in line heights (h), which makes printings of different
scale comparable, and are reported against hafs_kfqc - the vector Madinah
edition, right by eye - as the reference offset.

Writes rafeeq_app/build/hl/markers_<edition>.json and prints, per edition:
how many ayahs were measured, how many were within tolerance, and the
worst pages.
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_highlight as A  # noqa: E402

TOL = float(os.environ.get('MARK_TOL', '0.30'))  # in line heights


def markers_on_page(ed, p, entry):
    f = A.page_file(ed, p)
    if f is None:
        return None
    box, _ = A.compose(Image.open(f), entry['aspect'])
    gray = cv2.cvtColor(np.asarray(box), cv2.COLOR_RGB2GRAY)
    bh = gray.shape[0]
    out = []
    ayahs = entry['ayahs']
    for ay in ayahs:
        if not ay['r']:
            continue
        last = max(ay['r'], key=lambda q: (round(q[1], 2), -q[0]))
        x0, y0, x1, y1 = last[0] * A.BW, last[1] * bh, last[2] * A.BW, last[3] * bh
        h = y1 - y0
        if h < 8:
            continue
        # search window: the line band, 1.8 h either side of the predicted end
        wx0, wx1 = int(max(0, x0 - 1.8 * h)), int(min(A.BW, x0 + 1.8 * h))
        wy0, wy1 = int(max(0, y0 - 0.35 * h)), int(min(bh, y1 + 0.35 * h))
        win = cv2.GaussianBlur(gray[wy0:wy1, wx0:wx1], (3, 3), 0)
        circles = cv2.HoughCircles(
            win, cv2.HOUGH_GRADIENT, dp=1, minDist=h * 0.6,
            param1=120, param2=max(10, int(h * 0.28)),
            minRadius=int(h * 0.22), maxRadius=int(h * 0.62))
        if circles is None:
            out.append({'s': ay['s'], 'a': ay['a'], 'dx': None})
            continue
        cands = [(wx0 + c[0], wy0 + c[1], c[2]) for c in circles[0]]
        # the marker ending THIS ayah: nearest circle to the predicted end,
        # vertically on the line
        cx, cy, r = min(cands, key=lambda c: abs(c[0] - x0) + 0.5 * abs(c[1] - (y0 + y1) / 2))
        out.append({'s': ay['s'], 'a': ay['a'],
                    'dx': round(float((cx - x0) / h), 3),
                    'dy': round(float((cy - (y0 + y1) / 2) / h), 3),
                    'r': round(float(r / h), 3)})
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    rng = range(1, 605)
    if '--pages' in sys.argv:
        a, b = sys.argv[sys.argv.index('--pages') + 1].split('-')
        rng = range(int(a), int(b) + 1)
        args = [x for x in args if x != f'{a}-{b}']
    data = json.load(open(os.path.join(A.HL, 'rects.json'), encoding='utf-8'))
    eds = args or ['hafs_kfqc', 'tajweed_color', 'madinah_gold', 'qatar', 'kuwait']
    res = {}
    for ed in eds:
        per = {}
        for p in rng:
            e = data[ed]['pages'].get(str(p))
            if not e:
                continue
            m = markers_on_page(ed, p, e)
            if m is not None:
                per[p] = m
        res[ed] = per
        json.dump(per, open(os.path.join(A.HL, f'markers_{ed}.json'), 'w'))
    ref = [m['dx'] for ms in res.get('hafs_kfqc', {}).values() for m in ms if m['dx'] is not None]
    base = float(np.median(ref)) if ref else float(os.environ.get('MARK_BASE', '0'))
    lines = [f'reference dx (hafs_kfqc) = {base:.3f} h over {len(ref)} ayahs; tolerance +-{TOL} h']
    for ed, per in res.items():
        all_ = [(p, m) for p, ms in per.items() for m in ms]
        found = [(p, m) for p, m in all_ if m['dx'] is not None]
        good = [x for x in found if abs(x[1]['dx'] - base) <= TOL]
        badp = {}
        for p, m in found:
            if abs(m['dx'] - base) > TOL:
                badp[p] = badp.get(p, 0) + 1
        dxs = np.array([m['dx'] for _, m in found]) - base if found else np.array([0])
        worst = sorted(badp.items(), key=lambda x: -x[1])[:8]
        lines.append(
            f'{ed}: ayahs {len(all_)}, marker found {len(found)}, within tol {len(good)} '
            f'({100 * len(good) / max(1, len(found)):.1f}%) | error median {np.median(np.abs(dxs)):.3f} h '
            f'p95 {np.percentile(np.abs(dxs), 95):.3f} h | pages with a miss: {len(badp)} '
            f'| worst {worst}')
    rep = '\n'.join(lines)
    open(os.path.join(A.HL, 'markers_summary.txt'), 'w', encoding='utf-8').write(rep)
    print(rep)


if __name__ == '__main__':
    main()
