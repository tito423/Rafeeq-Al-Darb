# Decode single cleaned lines with FastConformer AND Whisper turbo.
#   py -3 recheck.py musa:3 musa:6 ...   -> recheck.txt
import sys, wave, subprocess, numpy as np, sherpa_onnx as so
FF = r'C:/Program Files/ShareX/ffmpeg.exe'
d = 'E:/DevEnv/asr/fastconformer_ar/'; wd = 'E:/DevEnv/asr/sherpa-onnx-whisper-turbo/'
fc = so.OfflineRecognizer.from_nemo_ctc(model=d + 'model.int8.onnx', tokens=d + 'tokens.txt', num_threads=4)
wh = so.OfflineRecognizer.from_whisper(encoder=wd + 'turbo-encoder.int8.onnx', decoder=wd + 'turbo-decoder.int8.onnx',
                                       tokens=wd + 'turbo-tokens.txt', language='ar', task='transcribe', num_threads=4)
o = open('recheck.txt', 'w', encoding='utf-8')
for a in sys.argv[1:]:
    s, n = a.split(':')
    src = f'{s}/n{int(n):02d}.wav'; tmp = f'{s}/chk.wav'
    subprocess.run([FF, '-v', 'error', '-y', '-i', src, '-ar', '16000', '-ac', '1', tmp], check=True)
    w = wave.open(tmp); x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    line = dict(l.split('\t') for l in open(f'{s}/lines.tsv', encoding='utf-8').read().splitlines())[n]
    res = []
    for r in (fc, wh):
        st = r.create_stream(); st.accept_waveform(16000, x); r.decode_stream(st); res.append(st.result.text)
    o.write(f'{a}\n  SCRIPT {line}\n  FC     {res[0]}\n  WHISP  {res[1]}\n')
