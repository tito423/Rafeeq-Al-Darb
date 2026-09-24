"""Count mid-scroll stalls in a screen recording.

A stall = a run of identical frames lasting >= 100 ms with fast motion
(mean abs diff > 8) on BOTH sides within 100 ms - the app stopped drawing
while the content was still moving. A fling coming to rest (motion decaying
to 0) is not counted.
"""
import re, subprocess, sys, pathlib
import numpy as np
from PIL import Image

ff = r'C:\Program Files\ShareX\ffmpeg.exe'
src, out = sys.argv[1], pathlib.Path(sys.argv[2])
crop = sys.argv[3] if len(sys.argv) > 3 else 'crop=iw:ih*0.8:0:ih*0.1'
out.mkdir(exist_ok=True)
for f in out.glob('*.png'):
    f.unlink()
r = subprocess.run([ff, '-v', 'info', '-i', src, '-vf',
                    f'{crop},scale=120:-1,showinfo', '-vsync', '0',
                    str(out / 'f%05d.png')], capture_output=True, text=True)
pts = [float(m) for m in re.findall(r'pts_time:([\d.]+)', r.stderr)]
rows, prev = [], None
for t, f in zip(pts, sorted(out.glob('f*.png'))):
    a = np.asarray(Image.open(f).convert('L'), dtype=np.int16)
    rows.append((t, 0.0 if prev is None else float(np.abs(a - prev).mean())))
    prev = a
fast = [t for t, d in rows if d > 8]
stalls = []
i = 1
while i < len(rows):
    if rows[i][1] < 0.3:
        j = i
        while j + 1 < len(rows) and rows[j + 1][1] < 0.3:
            j += 1
        t0 = rows[i - 1][0]
        t1 = rows[j + 1][0] if j + 1 < len(rows) else rows[j][0]
        if (t1 - t0 >= 0.1 and any(t0 - 0.1 <= m <= t0 for m in fast)
                and any(t1 <= m <= t1 + 0.1 for m in fast)):
            stalls.append((t0, t1))
        i = j + 1
    else:
        i += 1
# a stall can also show as a single long gap between two moving frames
for k in range(1, len(rows)):
    g = rows[k][0] - rows[k - 1][0]
    if g >= 0.1 and rows[k][1] > 8 and rows[k - 1][1] > 8:
        stalls.append((rows[k - 1][0], rows[k][0]))
stalls.sort()
print(f'frames={len(rows)} duration={rows[-1][0]:.1f}s stalls={len(stalls)}')
for t0, t1 in stalls:
    print(f'  {t0:6.2f} -> {t1:6.2f}  {1000 * (t1 - t0):5.0f} ms')
