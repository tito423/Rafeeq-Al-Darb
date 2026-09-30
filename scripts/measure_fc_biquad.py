"""The app's own low-pass (RBJ biquad, 3400 Hz, Q 0.7071, 16 kHz - the
formula `tasmee_audio.dart` uses) against ffmpeg's `lowpass=f=3400`: same
benchmark, FastConformer. The app must reproduce the measured gain.

    py -3 scripts/measure_fc_biquad.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_quran_asr as m  # noqa: E402
import measure_asr_tiny_vs_base as t  # noqa: E402
import measure_asr_candidates as c  # noqa: E402


def biquad_lowpass(x, fc=3400.0, fs=16000.0, q=0.7071):
    w0 = 2 * math.pi * fc / fs
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def main():
    import sqlite3
    import sherpa_onnx
    con = sqlite3.connect(m.DB)
    basmala = m.norm('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ')

    def expected(s, a):
        w = m.norm(con.execute('select text_uthmani from ayahs where surah_id=? '
                               'and ayah_number=?', (s, a)).fetchone()[0])
        if s != 1 and a == 1 and w[:len(basmala)] == basmala:
            w = w[len(basmala):]
        return w

    rec = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
        model=f'{c.ASR}/fastconformer_ar/model.int8.onnx',
        tokens=f'{c.ASR}/fastconformer_ar/tokens.txt', num_threads=4)
    tot = ok_all = 0
    for r, f in c.RECITERS.items():
        for s, a in t.AYAHS:
            x = biquad_lowpass(c.load(t.fetch(r, f, s, a)).astype(np.float64)).astype(np.float32)
            x = np.concatenate([np.zeros(4000, np.float32), x, np.zeros(8000, np.float32)])
            st = rec.create_stream()
            st.accept_waveform(16000, x)
            rec.decode_stream(st)
            exp = expected(s, a)
            ok, _, _ = m._check(exp, m.norm(st.result.text))
            tot += len(exp)
            ok_all += ok
    print(f'app biquad lowpass: {ok_all}/{tot} = {100 * ok_all / tot:.1f}%')


if __name__ == '__main__':
    main()
