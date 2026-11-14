"""Current tasmee model (NVIDIA FastConformer int8) vs Abdou/quran-asr-small
(int8, 36 MB), same audio, same scoring as measure_asr_candidates.py.

Model: https://huggingface.co/Abdou/quran-asr-small (MIT, int8 36,081,762 B,
downloaded 2026-11-14 to E:/DevEnv/asr/quran_asr_small). Results:
asr_quran_small_2026-11-14.txt. Run: py -3 scripts/measure_asr_quran_small.py

Two sets:
  * ours   - the 6 reciters the app was measured on (likely IN the new
             model's training data: it trained on 36 EveryAyah reciters);
  * heldout - the 4 EveryAyah reciters its card names as held out of its
             training (results/heldout_reciters.txt) - fair to both.
Each clean, clean with the app's 3.4 kHz low-pass, and through the phone band.
"""
import os
import sys
import time

import numpy as np
from scipy.signal import butter, sosfilt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_quran_asr as m  # noqa: E402
import measure_asr_tiny_vs_base as t  # noqa: E402
import measure_asr_candidates as c  # noqa: E402
import sherpa_onnx  # noqa: E402

OURS = dict(c.RECITERS)
HELDOUT = {
    'alalaqimy': 'Akram_AlAlaqimy_128kbps',
    'rifai': 'Hani_Rifai_64kbps',
    'menshawi32': 'Menshawi_32kbps',
    'sahlyassin': 'Sahl_Yassin_128kbps',
}
SOS = butter(8, 3400, 'low', fs=16000, output='sos')


def make(kind):
    if kind == 'fastconformer':
        rec = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
            model=f'{c.ASR}/fastconformer_ar/model.int8.onnx',
            tokens=f'{c.ASR}/fastconformer_ar/tokens.txt', num_threads=4)
    else:
        rec = sherpa_onnx.OfflineRecognizer.from_zipformer_ctc(
            model=f'{c.ASR}/quran_asr_small/model.int8.onnx',
            tokens=f'{c.ASR}/quran_asr_small/tokens.txt', num_threads=4)

    def heard(wav, lp=False):
        x = c.load(wav)
        if lp:
            x = sosfilt(SOS, x).astype(np.float32)
        a = np.concatenate([np.zeros(4000, np.float32), x,
                            np.zeros(8000, np.float32)])
        s = rec.create_stream()
        s.accept_waveform(16000, a)
        rec.decode_stream(s)
        return m.norm(s.result.text)
    return heard


def main():
    import sqlite3
    con = sqlite3.connect(m.DB)
    basmala = m.norm('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ')

    def expected(s, a):
        row = con.execute('select text_uthmani from ayahs where surah_id=? '
                          'and ayah_number=?', (s, a)).fetchone()
        w = m.norm(row[0])
        if s != 1 and a == 1 and w[:len(basmala)] == basmala:
            w = w[len(basmala):]
        return w

    sets = {}
    for name, recs in (('ours', OURS), ('heldout', HELDOUT)):
        files = {}
        for r, folder in recs.items():
            for s, a in t.AYAHS:
                try:
                    files[(r, s, a)] = t.fetch(r, folder, s, a)
                except Exception:
                    print(f'  missing on everyayah: {folder} {s}:{a}')
        sets[name] = files

    for kind in ('fastconformer', 'quran_small'):
        heard = make(kind)
        print(f'\n=== {kind} ===', flush=True)
        for name, files in sets.items():
            for mode in ('clean', 'lowpass', 'band'):
                tot = ok_all = 0
                proc = audio = 0.0
                per = {}
                for (r, s, a), wav in files.items():
                    src = t.derived(wav, 'band') if mode == 'band' else wav
                    exp = expected(s, a)
                    t0 = time.time()
                    got = heard(src, lp=(mode == 'lowpass'))
                    proc += time.time() - t0
                    audio += t.duration(src)
                    ok, _, _ = m._check(exp, got)
                    tot += len(exp)
                    ok_all += ok
                    p = per.setdefault(r, [0, 0])
                    p[0] += ok
                    p[1] += len(exp)
                print(f'{name:8} {mode:8} words {tot}: {ok_all} '
                      f'({100 * ok_all / tot:.1f}%)  {proc / audio:.3f} s/s   '
                      + '  '.join(f'{r} {100 * o / n:.0f}%'
                                  for r, (o, n) in per.items()), flush=True)
        for hl, src, (s, a), how in t.HARD:
            wav = os.path.join(t.WORK, 'cmp', src)
            if how:
                wav = t.derived(wav, how)
            exp = expected(s, a)
            ok, _, _ = m._check(exp, heard(wav))
            print(f'  hard: {hl:38} {ok}/{len(exp)}', flush=True)


if __name__ == '__main__':
    main()
