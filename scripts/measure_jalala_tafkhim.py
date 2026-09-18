"""Measure the tafkhim of the divine name in a speech sample.

A heavy (mufakhkham) lam backs the long vowel after it, lowering its second
formant. This reads F2 over the open-vowel frames (F1 > 550 Hz) of a short
WAV by LPC. Reference, measured 2026-09-18: al-Minshawi «اللَّهُ» (112:2)
~972 Hz; Google Arabic TTS «اللَّهُ» ~1450-1600 Hz (light); nipponjo
FastPitch speaker 0 ~1232 heavy vs ~1421 for «بِاللَّهِ».

    py -3 scripts/measure_jalala_tafkhim.py "<glob of .wav>"
"""
import glob, wave, sys
import numpy as np

def read(p):
    w = wave.open(p); sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64)
    if w.getnchannels() > 1: x = x.reshape(-1, w.getnchannels()).mean(1)
    return x, sr

def resample(x, sr, to=10000):
    n = int(len(x) * to / sr)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x), to

def lpc(frame, order):
    r = np.correlate(frame, frame, 'full')[len(frame) - 1:len(frame) + order]
    a = np.zeros(order + 1); a[0] = 1; e = r[0]
    for i in range(1, order + 1):
        k = -(r[i] + np.dot(a[1:i], r[i - 1:0:-1])) / e
        a[1:i] = a[1:i] + k * a[i - 1:0:-1]; a[i] = k; e *= (1 - k * k)
    return a

def formants(frame, sr):
    frame = np.append(frame[0], frame[1:] - 0.63 * frame[:-1]) * np.hamming(len(frame))
    a = lpc(frame, 12)
    roots = [r for r in np.roots(a) if np.imag(r) > 0]
    f = sorted(np.angle(roots) * sr / (2 * np.pi))
    bw = [-sr / (2 * np.pi) * np.log(abs(r)) for r in roots]
    out = [fr for fr, b in sorted(zip(np.angle(roots) * sr / (2 * np.pi), bw)) if fr > 150 and b < 400]
    return out

def track(p):
    x, sr = read(p); x, sr = resample(x, sr)
    n = int(0.025 * sr); hop = int(0.01 * sr)
    rows = []
    for i in range(0, len(x) - n, hop):
        fr = x[i:i + n]
        e = np.sqrt((fr ** 2).mean())
        rows.append((i / sr, e, formants(fr, sr) if e > 300 else []))
    emax = max(r[1] for r in rows)
    voiced = [r for r in rows if r[1] > 0.3 * emax and len(r[2]) >= 2]
    return voiced

for p in sorted(glob.glob(sys.argv[1] if len(sys.argv) > 1 else 'allah__*.wav')):
    v = track(p)
    f2 = np.array([r[2][1] for r in v]); f1 = np.array([r[2][0] for r in v])
    # The vowel after the lam: the loudest stretch, where F1 is high (open vowel).
    open_ = [r[2][1] for r in v if r[2][0] > 550]
    print(f'{p:48s} voiced={len(v):3d}  F2 open-vowel median={np.median(open_) if open_ else 0:6.0f}  min={min(open_) if open_ else 0:6.0f}  (n={len(open_)})')
