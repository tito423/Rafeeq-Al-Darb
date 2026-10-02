# voice2.wav + timing2.json -> words.json (per-scene word start times) and words.txt
import wave, json, subprocess, numpy as np, sherpa_onnx as so
subprocess.run([r'C:/Program Files/ShareX/ffmpeg.exe', '-v', 'error', '-y', '-i', 'voice2.wav', '-ar', '16000', '-ac', '1', 'v16.wav'], check=True)
d = 'E:/DevEnv/asr/fastconformer_ar/'
r = so.OfflineRecognizer.from_nemo_ctc(model=d + 'model.int8.onnx', tokens=d + 'tokens.txt', num_threads=4)
w = wave.open('v16.wav'); x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
T = json.load(open('timing2.json')); start = 0.0; out = {}; txt = []
for t in T:
    a = int(start * 16000); b = int((start + t['seconds']) * 16000); start += t['seconds']
    s = r.create_stream(); s.accept_waveform(16000, x[a:b]); r.decode_stream(s); res = s.result
    words = []
    for tok, ts in zip(res.tokens, res.timestamps):
        if tok.startswith(' ') or not words: words.append([tok.strip(), ts])
        else: words[-1][0] += tok
    out[str(t['scene'])] = [{'t': round(ts, 2), 'word': wd} for wd, ts in words if wd]
    txt.append(f"{t['scene']} ({t['seconds']}s): " + ' | '.join(f"{e['word']}@{e['t']}" for e in out[str(t['scene'])]))
json.dump({'note': "word start times in seconds from each scene start, from the FastConformer transcript of the narration (spelling is the recogniser's, not the script's)", 'scenes': out}, open('words.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
open('words.txt', 'w', encoding='utf-8').write('\n'.join(txt))
