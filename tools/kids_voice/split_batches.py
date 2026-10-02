# Split batched Gemini clips (several narration lines per request) into one
# clip per line, using the ASR word timestamps: the cut goes in the quietest
# part of the gap between the last word of a line and the first of the next.
# Refuses (prints MISMATCH, writes nothing for that batch) if the recogniser's
# word count differs from the script's. Then cleans each line (same chain as Nuh).
#   py -3 ../split_batches.py b1=1,2,3,4 b2=5,6,7,8 ...   (run in the story folder)
import sys, wave, subprocess, numpy as np, sherpa_onnx as so
FF = r'C:/Program Files/ShareX/ffmpeg.exe'
CHAIN = 'volume=0.8,afftdn=nr=18:nf=-50:tn=1,highpass=f=70,lowpass=f=10500,agate=threshold=0.0096:ratio=3:attack=5:release=150'
d = 'E:/DevEnv/asr/fastconformer_ar/'
r = so.OfflineRecognizer.from_nemo_ctc(model=d + 'model.int8.onnx', tokens=d + 'tokens.txt', num_threads=4)
L = dict(l.split('\t') for l in open('lines.tsv', encoding='utf-8').read().splitlines())
def load(f):
    w = wave.open(f); return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768, w.getframerate()
ok = True
for arg in sys.argv[1:]:
    b, ids = arg.split('='); ids = ids.split(',')
    subprocess.run([FF, '-v', 'error', '-y', '-i', b + '.wav', '-ar', '16000', '-ac', '1', b + '_16.wav'], check=True)
    x16, _ = load(b + '_16.wav'); x, sr = load(b + '.wav')
    s = r.create_stream(); s.accept_waveform(16000, x16); r.decode_stream(s); res = s.result
    words = []
    for t, ts in zip(res.tokens, res.timestamps):
        if t.startswith(' ') or not words: words.append([t.strip(), ts])
        else: words[-1][0] += t
    words = [w for w in words if w[0]]
    want = sum(len(L[i].split()) for i in ids)
    if len(words) != want:
        print(b, 'MISMATCH asr', len(words), 'script', want, '|', ' '.join(w[0] for w in words)); ok = False; continue
    hop = int(sr * 0.01); db = np.array([20 * np.log10(np.sqrt(np.mean(x[i * hop:(i + 1) * hop] ** 2)) + 1e-9) for i in range(len(x) // hop)])
    cuts, k = [0.0], 0
    for i in ids[:-1]:
        k += len(L[i].split())
        a = words[k - 1][1] + 0.15; z = words[k][1]
        seg = db[int(a * 100):int(z * 100)]; q = np.where(seg < -42)[0]
        cuts.append(a + (q[len(q) // 2] if len(q) else len(seg) // 2) * 0.01)
    cuts.append(len(x) / sr)
    for j, i in enumerate(ids):
        seg = x[int(cuts[j] * sr):int(cuts[j + 1] * sr)]
        name = f'raw{int(i):02d}.wav'
        w = wave.open(name, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((seg * 32767).astype(np.int16).tobytes()); w.close()
        subprocess.run([FF, '-loglevel', 'error', '-y', '-i', name, '-af', CHAIN, f'n{int(i):02d}.wav'], check=True)
        print(b, i, round(len(seg) / sr, 2), 's |', ' '.join(w[0] for w in words if cuts[j] <= w[1] < cuts[j + 1]))
print('ALL OK' if ok else 'SOME BATCHES FAILED')
