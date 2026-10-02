# Mix one story's narration (run in its folder): n01..nNN.wav + one recitation
# scene -> voice2.wav, timing2.json; then ambience amb2.wav; then the final mp3.
#   py -3 ../mix_story.py <scenes> <rec_scene> <rec.wav> <story_id> <ambience profile per scene, comma list>
# profile letters per scene: w=wind  r=rain  s=sea  b=bubbles  (e.g. "w,w,ws,s")
# Same rules as mix2.py (Nuh, accepted by the owner): pauses tightened to 0.13 s
# with 20 ms cross-fades, 0.25 s lead, 0.3 s tail (1.5 s on the last scene), the
# recitation untouched with 0.6 s after it; the ambience is generated noise at
# about -44 dBFS, ducked under the voice; loudness -16 LUFS, peak -1.5 dBFS.
import sys, json, wave, subprocess, numpy as np
from scipy.signal import butter, sosfilt
SR = 24000
FF = r'C:/Program Files/ShareX/ffmpeg.exe'
N, REC, RECWAV, SID, PROF = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5].split(',')
assert len(PROF) == N, 'one ambience profile per scene'

def load(f):
    w = wave.open(f); x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    assert w.getframerate() == SR, f; return x

def tighten(x, gap=0.13, edge=0.04):
    hop = int(SR * 0.01); n = len(x) // hop
    db = np.array([20 * np.log10(np.sqrt(np.mean(x[j * hop:(j + 1) * hop] ** 2)) + 1e-9) for j in range(n)])
    v = db > -40; idx = np.where(v)[0]
    a = max(0, idx[0] * hop - int(edge * SR)); b = min(len(x), (idx[-1] + 1) * hop + int(edge * SR))
    out = []; start = a; k = idx[0]
    while k <= idx[-1]:
        if not v[k]:
            r = k
            while r <= idx[-1] and not v[r]: r += 1
            if (r - k) * 0.01 > gap:
                out.append(x[start:k * hop + int(gap / 2 * SR)]); start = r * hop - int(gap / 2 * SR)
            k = r
        else: k += 1
    out.append(x[start:b])
    xf = int(0.02 * SR); fi = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2; fo = 1 - fi
    y = out[0]
    for p in out[1:]:
        if len(y) < xf or len(p) < xf: y = np.concatenate([y, p]); continue
        y = np.concatenate([y[:-xf], y[-xf:] * fo + p[:xf] * fi, p[xf:]])
    f = int(0.01 * SR); y[:f] *= np.linspace(0, 1, f); y[-f:] *= np.linspace(1, 0, f)
    return y

sil = lambda s: np.zeros(int(s * SR), np.float32)
scenes, timing = [], []
for i in range(1, N + 1):
    parts = [sil(0.25)]
    if i == REC: parts += [load(RECWAV), sil(0.6)]       # the reciter - never the generated voice
    else: parts += [tighten(load(f'n{i:02d}.wav')), sil(0.3 if i < N else 1.5)]
    seg = np.concatenate(parts); scenes.append(seg); timing.append({'scene': i, 'seconds': round(len(seg) / SR, 3)})
voice = np.concatenate(scenes)
w = wave.open('voice2.wav', 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((np.clip(voice, -1, 1) * 32767).astype(np.int16).tobytes()); w.close()
json.dump(timing, open('timing2.json', 'w'), indent=1)

# ambience: filtered noise beds, per-scene gains, 1.2 s cross-fades
rng = np.random.default_rng(3); total = len(voice) / SR; L = len(voice) + SR; t = np.arange(L) / SR
filt = lambda x, kind, f: sosfilt(butter(2, f, kind, fs=SR, output='sos'), x)
white = rng.standard_normal(L)
beds = [filt(white, 'low', 280) * (0.55 + 0.45 * np.sin(2 * np.pi * t / 7.3) ** 2),
        filt(filt(white, 'high', 700), 'low', 3000),
        filt(white, 'low', 450) * (0.25 + 0.75 * (np.sin(2 * np.pi * t / 6.5) * 0.5 + 0.5) ** 2),
        filt(white, 'low', 200) * (0.5 + 0.5 * np.sin(2 * np.pi * t * 7) ** 8)]
beds = [b / np.sqrt(np.mean(b ** 2)) for b in beds]
env = np.zeros((4, L)); s0 = 0
for i, seg in enumerate(scenes):
    g = [float('w' in PROF[i]), float('r' in PROF[i]) * 0.7, float('s' in PROF[i]), float('b' in PROF[i])]
    env[:, s0:s0 + len(seg)] = np.array(g)[:, None]; s0 += len(seg)
env[:, s0:] = env[:, s0 - 1:s0]
k = int(1.2 * SR)
def smooth(e):
    c = np.cumsum(np.concatenate([np.zeros(1), e])); m = (c[k:] - c[:-k]) / k
    return np.concatenate([np.full(k // 2, m[0]), m, np.full(len(e) - len(m) - k // 2, m[-1])])
amb = sum(smooth(env[j]) * beds[j] for j in range(4)) * 10 ** (-44 / 20)
fade = 2 * SR; amb[:fade] *= np.linspace(0, 1, fade)
vend = int((total - 1.5) * SR); f0, f1 = vend - int(1.2 * SR), vend + int(0.4 * SR)
amb[f0:f1] *= np.linspace(1, 0, f1 - f0); amb[f1:] = 0
w = wave.open('amb2.wav', 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((np.clip(amb, -1, 1) * 32767).astype(np.int16).tobytes()); w.close()

subprocess.run([FF, '-v', 'error', '-y', '-i', 'voice2.wav', '-i', 'amb2.wav', '-filter_complex',
    '[0:a]highpass=f=70,acompressor=threshold=-20dB:ratio=2.5:attack=8:release=120,asplit=2[v][sc];'
    '[1:a][sc]sidechaincompress=threshold=0.02:ratio=6:attack=40:release=600[a];'
    '[v][a]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=9',
    '-ar', '44100', '-b:a', '160k', f'{SID}_audio.mp3'], check=True)
print(SID, 'total', round(total, 2), [t['seconds'] for t in timing])
