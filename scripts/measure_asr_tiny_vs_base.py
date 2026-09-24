"""Tiny vs base: which Quran-tuned Whisper should the tasmee' use? (PLAN 4a)

The app ships whisper-tiny-ar-quran (ggml, 77,691,713 bytes) through
whisper.cpp. whisper-base-ar-quran is on the bucket and unused. «قيسه ولو
كسب ادمجه» (2026-09-24): measure, and integrate only if it wins by numbers.

SAME ENGINE, SAME SETTINGS, SAME AUDIO. Both models run in whisper.cpp
(pywhispercpp - the engine whisper_flutter_new wraps on the phone), language
«ar», on identical 16 kHz WAVs. What is compared:

  * words matched (same skeleton, the measure `measure_quran_asr.py` settled
    on: a missing long vowel is the same word) and words exact;
  * the two mistakes a tasmee' screen must catch: a recitation stopped
    half-way (the matched share must DROP) and the wrong ayah (must be
    rejected);
  * processing time per second of audio, on this desktop CPU. Absolute
    phone latency is NOT measured here; the ratio between the two models on
    one CPU is.

    py -3 scripts/measure_asr_tiny_vs_base.py
"""
import io
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_quran_asr as m  # noqa: E402  norm / skeleton / _check / paths

WORK = m.WORK
MODELS = {
    'tiny': os.path.join(WORK, 'ggml_tiny', 'ggml-model.bin'),
    'base': os.path.join(WORK, 'ggml16', 'ggml-model.bin'),
}
RECITERS = {
    'husary': 'Husary_128kbps',
    'alafasy': 'Alafasy_128kbps',
    'minshawi': 'Minshawy_Murattal_128kbps',
    'banna': 'mahmoud_ali_al_banna_32kbps',
}
AYAHS = ([(1, a) for a in range(1, 8)] + [(2, 255), (18, 1), (67, 1),
         (67, 2)] + [(112, a) for a in range(1, 5)])
# (label, source wav, ayah it is checked against, how it is made)
HARD = [
    ('phone-like band (husary 18:1)', 'husary_018001.wav', (18, 1), 'band'),
    ('phone-like band (banna 2:255)', 'banna_002255.wav', (2, 255), 'band'),
    ('stopped after 12 s (husary 2:255)', 'husary_002255.wav', (2, 255),
     'cut'),
    ('WRONG ayah: 112:1 against 18:1', 'husary_112001.wav', (18, 1), None),
    ('WRONG ayah: 67:1 against 2:255', 'alafasy_067001.wav', (2, 255), None),
]


def fetch(reciter, folder, s, a):
    name = f'{reciter}_{s:03d}{a:03d}'
    mp3 = os.path.join(WORK, 'cmp', name + '.mp3')
    wav = os.path.join(WORK, 'cmp', name + '.wav')
    if not os.path.exists(wav):
        os.makedirs(os.path.dirname(wav), exist_ok=True)
        subprocess.run(['curl', '-sS', '-f', '-A', m.UA, '-o', mp3,
                        f'https://everyayah.com/data/{folder}/{s:03d}{a:03d}.mp3'],
                       check=True)
        subprocess.run([m.FFMPEG, '-v', 'quiet', '-y', '-i', mp3,
                        '-ar', '16000', '-ac', '1', wav], check=True)
    return wav


def derived(src, how):
    out = src.replace('.wav', f'_{how}.wav')
    if not os.path.exists(out):
        af = (['-af', 'highpass=f=200,lowpass=f=3400,volume=0.6,'
               'aresample=8000,aresample=16000'] if how == 'band'
              else ['-t', '12'])
        subprocess.run([m.FFMPEG, '-v', 'quiet', '-y', '-i', src, *af,
                        '-ar', '16000', '-ac', '1', out], check=True)
    return out


def duration(wav):
    return (os.path.getsize(wav) - 44) / 32000.0


def main():
    import sqlite3
    from pywhispercpp.model import Model

    con = sqlite3.connect(m.DB)
    basmala = m.norm('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ')

    def expected(s, a):
        row = con.execute('select text_uthmani from ayahs where surah_id=? '
                          'and ayah_number=?', (s, a)).fetchone()
        w = m.norm(row[0])
        if s != 1 and a == 1 and w[:len(basmala)] == basmala:
            w = w[len(basmala):]
        return w

    files = {}
    for r, folder in RECITERS.items():
        for s, a in AYAHS:
            files[(r, s, a)] = fetch(r, folder, s, a)

    out = io.open(os.path.join(WORK, 'tiny_vs_base.txt'), 'w',
                  encoding='utf-8')

    def say(t):
        out.write(t + '\n')
        sys.stdout.buffer.write((t + '\n').encode('utf-8'))

    summary = {}
    for label, path in MODELS.items():
        model = Model(path, n_threads=4, print_progress=False,
                      print_realtime=False, redirect_whispercpp_logs_to=None)

        def heard(wav):
            segs = model.transcribe(wav, language='ar')
            return m.norm(' '.join(x.text for x in segs))

        heard(files[('husary', 1, 1)])  # warm-up, not timed
        say(f'\n=== {label}  ({os.path.getsize(path):,} bytes) ===')
        tot = ok_all = exact_all = 0
        audio = proc = 0.0
        per_reciter = {}
        for (r, s, a), wav in files.items():
            exp = expected(s, a)
            t0 = time.time()
            got = heard(wav)
            dt = time.time() - t0
            ok, missed, _ = m._check(exp, got)
            exact = sum(1 for x, y in zip(exp, got) if x == y)
            tot += len(exp)
            ok_all += ok
            exact_all += exact
            audio += duration(wav)
            proc += dt
            pr = per_reciter.setdefault(r, [0, 0])
            pr[0] += ok
            pr[1] += len(exp)
        say(f'words {tot}: matched {ok_all} ({100 * ok_all / tot:.1f}%), '
            f'exact {exact_all} ({100 * exact_all / tot:.1f}%)')
        for r, (ok, n) in per_reciter.items():
            say(f'  {r:9} {ok}/{n} = {100 * ok / n:.1f}%')
        say(f'{audio:.1f} s of audio in {proc:.1f} s -> '
            f'{proc / audio:.3f} s per audio second')
        hard = []
        for hl, src, (s, a), how in HARD:
            wav = os.path.join(WORK, 'cmp', src)
            if how:
                wav = derived(wav, how)
            exp = expected(s, a)
            ok, _, _ = m._check(exp, heard(wav))
            hard.append((hl, ok, len(exp)))
            say(f'  hard: {hl:38} {ok}/{len(exp)} = {100 * ok / len(exp):.0f}%')
        summary[label] = (ok_all, tot, proc / audio, hard)
    out.close()


if __name__ == '__main__':
    main()
