# Word-level audit: every script word must be found (fuzzy, in order) in BOTH the FastConformer and
# the Whisper transcript of the cleaned line n<NN>.wav. A word missing from both = flagged.
import sys, wave, re, difflib, subprocess, numpy as np, sherpa_onnx as so
sys.stdout.reconfigure(encoding='utf-8')
FF = r'C:/Program Files/ShareX/ffmpeg.exe'; K = 'E:/DevEnv/kids_voice'
d = 'E:/DevEnv/asr/fastconformer_ar/'; wd = 'E:/DevEnv/asr/sherpa-onnx-whisper-turbo/'
fc = so.OfflineRecognizer.from_nemo_ctc(model=d + 'model.int8.onnx', tokens=d + 'tokens.txt', num_threads=4)
wh = so.OfflineRecognizer.from_whisper(encoder=wd + 'turbo-encoder.int8.onnx', decoder=wd + 'turbo-decoder.int8.onnx', tokens=wd + 'turbo-tokens.txt', language='ar', task='transcribe', num_threads=4)
def nz(w):
    w = re.sub(r'[\u064B-\u065F\u0670\u0640]', '', w); w = re.sub('[إأآٱ]', 'ا', w).replace('ى', 'ي').replace('ة', 'ه').replace('ؤ','و').replace('ئ','ي')
    return re.sub(r'[^\u0621-\u064A]', '', w)
def words(t): return [x for x in (nz(w) for w in t.replace('ﷺ', 'صلى الله عليه وسلم').split()) if x]
def missing(script, heard):
    out = []
    for w in script:
        best = max((difflib.SequenceMatcher(None, w, h).ratio() for h in heard), default=0)
        if best < 0.75: out.append(w)
    return out
for sid in sys.argv[1:]:
    L = dict(l.split('\t') for l in open(f'{K}/{sid}/lines.tsv', encoding='utf-8').read().splitlines())
    for n, t in L.items():
        subprocess.run([FF, '-v', 'error', '-y', '-i', f'{K}/{sid}/n{int(n):02d}.wav', '-ar', '16000', '-ac', '1', f'{K}/new/a16.wav'], check=True)
        w = wave.open(f'{K}/new/a16.wav'); x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
        res = []
        for r in (fc, wh):
            s = r.create_stream(); s.accept_waveform(16000, x); r.decode_stream(s); res.append(words(s.result.text))
        sw = words(t); m = [w for w in missing(sw, res[0]) if w in missing(sw, res[1])]
        if m: print(f'{sid} {n}: MISSING IN BOTH {m} | FC {" ".join(res[0])} | WH {" ".join(res[1])}')
    print(sid, 'checked', len(L))
