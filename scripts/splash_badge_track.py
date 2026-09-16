"""Find the medallion as a CIRCLE, which is what it is.

The colour tracker locked onto the crescent inside the badge (r=180) because
that is the most saturated gold in the frame; the badge itself is the whole
medallion — outer gold rim, ornamented navy ring, crescent and Quran inside —
about 245 px in radius on the same frame. A Hough circle finds the rim.

    py -3 badge_hough.py <frame.png|frames_dir> <out.png|out.txt>
"""
import os
import sys

import cv2
import numpy as np


def find(im):
    g = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY)
    g = cv2.medianBlur(g, 5)
    h, w = g.shape
    circles = cv2.HoughCircles(
        g, cv2.HOUGH_GRADIENT, dp=1.5, minDist=w // 2,
        param1=120, param2=60, minRadius=40, maxRadius=int(w * 0.48),
    )
    if circles is None:
        return None
    best = None
    for x, y, r in np.round(circles[0]).astype(int):
        # The medallion is the one near the middle of the frame, in the upper
        # two thirds — the wordmark and the cloud line are lower.
        if abs(x - w / 2) > w * 0.22 or not (h * 0.2 < y < h * 0.72):
            continue
        if best is None or r > best[2]:
            best = (x, y, r)
    return best


def main():
    src, out = sys.argv[1], sys.argv[2]
    if os.path.isdir(src):
        rows = []
        for f in sorted(os.listdir(src)):
            if not f.endswith(".png"):
                continue
            c = find(cv2.imread(os.path.join(src, f)))
            rows.append((f, c))
        with open(out, "w", encoding="utf-8") as fh:
            for f, c in rows:
                fh.write("%s %s\n" % (f, "%d %d %d" % c if c else "none"))
        got = [c for _, c in rows if c]
        print("frames", len(rows), "found", len(got))
        if got:
            print("r %d..%d  cx %d..%d  cy %d..%d"
                  % (min(c[2] for c in got), max(c[2] for c in got),
                     min(c[0] for c in got), max(c[0] for c in got),
                     min(c[1] for c in got), max(c[1] for c in got)))
    else:
        im = cv2.imread(src)
        c = find(im)
        print("circle:", c)
        if c:
            cv2.circle(im, (c[0], c[1]), c[2], (0, 0, 255), 3)
            cv2.circle(im, (c[0], c[1]), 4, (0, 255, 0), -1)
        cv2.imwrite(out, im)


if __name__ == "__main__":
    main()
