"""Put the app's own icon where the clip's medallion is, frame by frame.

«الايقونة اللي بتظهر جواه وحواليها التاثيرات تقدر تغيرها لايقونة التطبيق
الجديدة» — so the storm, the rays, the sparks and the wordmark all stay exactly
as his clip made them, and only the badge in the middle becomes the icon the
app actually wears.

HOW THE PLACE IS FOUND. `badge_hough.py` reads the medallion as a circle, which
is what it is — centre and radius per frame. That track is then cleaned here,
because a Hough circle occasionally prefers a cloud: anything more than 40 px
from the running median centre, or whose radius jumps more than 25 px from its
neighbours, is dropped and interpolated over. The badge's real motion is slow
and monotonic — it rises and grows — so a spike is never real.

HOW IT IS DRAWN. A square tile replacing a round medallion has to COVER it:
side = 2r × 1.04, so the old gold rim disappears under the new one rather than
peeking out at the tangents. The tile is then brightness-matched to the badge
it replaces — the clip fades the badge in and the lightning flashes across it,
and a tile pasted at full strength through all of that would look stuck on.

    py -3 badge_swap.py <frames_dir> <track.txt> <icon.png> <out_dir> [--only 45,60,100]
"""
import os
import sys

import cv2
import numpy as np

frames_dir, track_path, icon_path, out_dir = sys.argv[1:5]
only = None
if "--only" in sys.argv:
    only = {int(v) for v in sys.argv[sys.argv.index("--only") + 1].split(",")}

os.makedirs(out_dir, exist_ok=True)

# ---- read and clean the track -------------------------------------------
raw = {}
order = []
for line in open(track_path, encoding="utf-8"):
    parts = line.split()
    order.append(parts[0])
    raw[parts[0]] = None if parts[1] == "none" else tuple(int(v) for v in parts[1:4])

found = [(i, raw[f]) for i, f in enumerate(order) if raw[f]]
if not found:
    sys.exit("no badge found in any frame")

med_cx = float(np.median([c[0] for _, c in found]))
med_cy = float(np.median([c[1] for _, c in found]))
clean = {}
for i, c in found:
    if abs(c[0] - med_cx) > 40 or abs(c[1] - med_cy) > 120:
        continue
    clean[i] = c

# A radius that disagrees with both neighbours by more than 25 px is a miss.
idx = sorted(clean)
radii = dict(clean)
for i in idx:
    n = [radii[j][2] for j in idx if 0 < abs(j - i) <= 3]
    if n and abs(radii[i][2] - float(np.median(n))) > 25:
        clean.pop(i, None)

# SMOOTH IT, or the icon pulses. Hough returns whole pixels and its radius
# wobbles by a few between neighbouring frames; on a badge that is otherwise
# growing steadily, that wobble is the only motion the eye would notice. A
# seven-frame mean over centre and radius removes it without touching the rise.
idx = sorted(clean)
smoothed = {}
for i in idx:
    win = [clean[j] for j in idx if abs(j - i) <= 3]
    smoothed[i] = tuple(int(round(float(np.mean([c[k] for c in win]))))
                        for k in range(3))
clean = smoothed

idx = sorted(clean)
first, last = idx[0], idx[-1]
print("track: %d clean of %d found; frames %d..%d  r %d..%d"
      % (len(clean), len(found), first, last,
         min(clean[i][2] for i in idx), max(clean[i][2] for i in idx)))


def at(i):
    """Centre and radius for frame i, interpolated, or None before it starts."""
    if i in clean:
        return clean[i]
    before = [j for j in idx if j < i]
    after = [j for j in idx if j > i]
    if before and after:
        a, b = before[-1], after[0]
        t = (i - a) / float(b - a)
        return tuple(int(round(clean[a][k] + t * (clean[b][k] - clean[a][k])))
                     for k in range(3))
    if after:          # before the badge is trackable: it is small and faint
        return None
    return clean[before[-1]]


# ---- the icon, with a soft edge -----------------------------------------
icon = cv2.imread(icon_path, cv2.IMREAD_UNCHANGED)
if icon.shape[2] == 3:
    icon = cv2.cvtColor(icon, cv2.COLOR_BGR2BGRA)

for i, name in enumerate(order):
    n = i + 1
    if only and n not in only:
        continue
    frame = cv2.imread(os.path.join(frames_dir, name))
    c = at(i)
    if c is None:
        cv2.imwrite(os.path.join(out_dir, name), frame)
        continue
    cx, cy, r = c
    side = max(8, int(round(2 * r * 1.04)))
    tile = cv2.resize(icon, (side, side), interpolation=cv2.INTER_AREA)

    # Brightness of what is being replaced, against the tile's own, so the
    # fade-in and the lightning keep working on it.
    x0, y0 = cx - side // 2, cy - side // 2
    x1, y1 = x0 + side, y0 + side
    fx0, fy0 = max(0, x0), max(0, y0)
    fx1, fy1 = min(frame.shape[1], x1), min(frame.shape[0], y1)
    if fx1 <= fx0 or fy1 <= fy0:
        cv2.imwrite(os.path.join(out_dir, name), frame)
        continue
    under = frame[fy0:fy1, fx0:fx1]
    tile_crop = tile[fy0 - y0:fy1 - y0, fx0 - x0:fx1 - x0]

    gain = float(np.mean(under)) / max(1.0, float(np.mean(tile_crop[:, :, :3])))
    gain = min(1.25, max(0.45, gain))
    rgb = np.clip(tile_crop[:, :, :3].astype(np.float32) * gain, 0, 255)

    alpha = tile_crop[:, :, 3].astype(np.float32) / 255.0
    # Feather the outline so the tile sits in the glow instead of on it.
    alpha = cv2.GaussianBlur(alpha, (0, 0), max(1.0, side / 160.0))
    alpha = alpha[:, :, None]
    frame[fy0:fy1, fx0:fx1] = (rgb * alpha + under * (1 - alpha)).astype(np.uint8)
    cv2.imwrite(os.path.join(out_dir, name), frame)

print("wrote frames to", out_dir)
