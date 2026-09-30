"""FastConformer heard the phone band BETTER than the clean file (97.1% vs
91.3%, asr_candidates_2026-09-30.txt). Which part of the band does it - the
3.4 kHz low-pass, the 200 Hz high-pass, the 8 kHz round trip, or the volume?
The answer decides what the app does to a recording before decoding it.

    py -3 scripts/measure_fc_band_cause.py
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_quran_asr as m  # noqa: E402
import measure_asr_tiny_vs_base as t  # noqa: E402
import measure_asr_candidates as c  # noqa: E402

VARIANTS = {
    'clean': None,
    'lowpass3400': 'lowpass=f=3400',
    'highpass200': 'highpass=f=200',
    'band_no_resample': 'highpass=f=200,lowpass=f=3400',
    'resample8k_only': 'aresample=8000,aresample=16000',
    'volume0.6_only': 'volume=0.6',
    'full_band': 'highpass=f=200,lowpass=f=3400,volume=0.6,aresample=8000,aresample=16000',
}


def variant(src, name, af):
    if af is None:
        return src
    out = src.replace('.wav', f'_v_{name}.wav')
    if not os.path.exists(out):
        subprocess.run([m.FFMPEG, '-v', 'quiet', '-y', '-i', src, '-af', af,
                        '-ar', '16000', '-ac', '1', out], check=True)
    return out


def main():
    import sqlite3
    con = sqlite3.connect(m.DB)
    basmala = m.norm('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ')

    def expected(s, a):
        w = m.norm(con.execute('select text_uthmani from ayahs where surah_id=? '
                               'and ayah_number=?', (s, a)).fetchone()[0])
        if s != 1 and a == 1 and w[:len(basmala)] == basmala:
            w = w[len(basmala):]
        return w

    heard = c.sherpa('fastconformer')
    files = {(r, s, a): t.fetch(r, f, s, a)
             for r, f in c.RECITERS.items() for s, a in t.AYAHS}
    lines = []
    for name, af in VARIANTS.items():
        tot = ok_all = 0
        per = {}
        for (r, s, a), wav in files.items():
            exp = expected(s, a)
            ok, _, _ = m._check(exp, heard(variant(wav, name, af)))
            tot += len(exp)
            ok_all += ok
            p = per.setdefault(r, [0, 0])
            p[0] += ok
            p[1] += len(exp)
        line = (f'{name:18} {ok_all}/{tot} = {100 * ok_all / tot:.1f}%   ' +
                ' '.join(f'{r} {100 * o / n:.0f}' for r, (o, n) in per.items()))
        lines.append(line)
        sys.stdout.buffer.write((line + '\n').encode('utf-8'))
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           'fc_band_cause_2026-09-30.txt'), 'w',
              encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
