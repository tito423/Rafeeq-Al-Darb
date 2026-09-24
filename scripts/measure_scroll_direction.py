"""Vertical scroll direction around each freeze in a recording.

For each consecutive frame pair, finds the vertical shift (in px of the
120-px-wide thumbnails) that best aligns them. Around each freeze prints the
shifts just before and just after: same sign = the content was moving the
same way on both sides (a real stall mid-scroll); opposite sign = the page
hit its end and the finger reversed.
"""
import re, subprocess, sys, pathlib
import numpy as np
from PIL import Image

src, frames_dir = sys.argv[1], pathlib.Path(sys.argv[2])
r = subprocess.run([r'C:\Program Files\ShareX\ffmpeg.exe', '-v', 'info', '-i',
                    src, '-vf', 'showinfo', '-f', 'null', '-'],
                   capture_output=True, text=True)
pts = [float(m) for m in re.findall(r'pts_time:([\d.]+)', r.stderr)]
imgs = [np.asarray(Image.open(f).convert('L'), dtype=np.float32)
        for f in sorted(frames_dir.glob('f*.png'))]


def shift(a, b, maxs=60):
    best, arg = None, 0
    h = a.shape[0]
    for s in range(-maxs, maxs + 1):
        if s >= 0:
            x, y = a[s:], b[:h - s]
        else:
            x, y = a[:h + s], b[-s:]
        e = float(np.abs(x - y).mean())
        if best is None or e < best:
            best, arg = e, s
    return arg


sh = [0] + [shift(imgs[i - 1], imgs[i]) for i in range(1, len(imgs))]
diff = [0.0] + [float(np.abs(imgs[i] - imgs[i - 1]).mean())
                for i in range(1, len(imgs))]
for w in sys.argv[3:]:
    t0, t1 = map(float, w.split('-'))
    before = [sh[i] for i, t in enumerate(pts) if t0 - 0.12 <= t <= t0]
    after = [sh[i] for i, t in enumerate(pts) if t1 <= t <= t1 + 0.12]
    print(f'{t0:6.2f}-{t1:6.2f}  before {before}  after {after}')
