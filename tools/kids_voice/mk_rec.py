# rec.wav for a story: the Minshawi ayah from everyayah, 24 kHz mono, and an
# ASR check of it against the ayah text in the app's own quran_local.db.
import sys, subprocess, urllib.request, sqlite3, difflib, re, wave, numpy as np, sherpa_onnx as so
FF = r'C:/Program Files/ShareX/ffmpeg.exe'
d = 'E:/DevEnv/asr/fastconformer_ar/'
r = so.OfflineRecognizer.from_nemo_ctc(model=d + 'model.int8.onnx', tokens=d + 'tokens.txt', num_threads=4)
db = sqlite3.connect('E:/My Projects/Rafiq-Al-Darb/rafeeq_app/assets/data/quran_local.db')
def nz(t):
    t = re.sub(r'[\u064B-\u065F\u0670\u0640\u06D6-\u06ED]', '', t); t = re.sub('[إأآٱ]', 'ا', t).replace('ى', 'ي').replace('ة', 'ه')
    return re.sub(r'[^\u0621-\u064A ]', '', t).split()
for arg in sys.argv[1:]:
    sid, ref = arg.split('=')
    s, a = map(int, ref.split(':'))
    url = f'https://everyayah.com/data/Minshawy_Murattal_128kbps/{s:03d}{a:03d}.mp3'
    urllib.request.urlretrieve(url, f'{sid}/r.mp3')
    subprocess.run([FF, '-v', 'error', '-y', '-i', f'{sid}/r.mp3', '-ar', '24000', '-ac', '1', f'{sid}/rec.wav'], check=True)
    subprocess.run([FF, '-v', 'error', '-y', '-i', f'{sid}/r.mp3', '-ar', '16000', '-ac', '1', f'{sid}/r16.wav'], check=True)
    w = wave.open(f'{sid}/r16.wav'); x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    st = r.create_stream(); st.accept_waveform(16000, x); r.decode_stream(st)
    text = db.execute('select text_clean from ayahs where surah_id=? and ayah_number=?', (s, a)).fetchone()[0]
    sim = difflib.SequenceMatcher(None, nz(text), nz(st.result.text)).ratio()
    print(sid, ref, url, f'{w.getnframes()/16000:.1f}s', 'asr', round(sim, 3))
