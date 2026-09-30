"""Which recogniser should the tasmee' use? (owner, 2026-09-30: «غير ام
النموذج اللي بيسمع الكلمات لو وحش»)

Same audio, same scoring as `measure_asr_tiny_vs_base.py` (words matched on
the skeleton, `measure_quran_asr._check`), for:

  * tiny         - tarteel whisper-tiny-ar-quran, ggml, whisper.cpp: what the
                   app's tasmee' runs today;
  * fastconformer - NVIDIA FastConformer Arabic CTC (the «دقة أعلى في
                   العربية» pack Rafeeq already downloads, sha 714fc796…);
  * omnilingual  - omnilingual-asr 300M CTC (Rafeeq's base pack).

Six reciters instead of four, and EVERY file also through a phone/headset
band (200-3400 Hz, 8 kHz, quieter) - a learner on a Bluetooth headset is the
case the owner hit. Plus the two mistakes a tasmee' must catch.

    py -3 scripts/measure_asr_candidates.py
"""
import io
import os
import sys
import time
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure_quran_asr as m  # noqa: E402
import measure_asr_tiny_vs_base as t  # noqa: E402

ASR = 'E:/DevEnv/asr'
RECITERS = dict(t.RECITERS)
RECITERS.update({
    'abdulbasit': 'Abdul_Basit_Murattal_192kbps',
    'sudais': 'Abdurrahmaan_As-Sudais_192kbps',
})


def load(wav):
    with wave.open(wav) as w:
        a = np.frombuffer(w.readframes(w.getnframes()), np.int16)
    return a.astype(np.float32) / 32768


def sherpa(kind):
    import sherpa_onnx
    if kind == 'fastconformer':
        rec = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
            model=f'{ASR}/fastconformer_ar/model.int8.onnx',
            tokens=f'{ASR}/fastconformer_ar/tokens.txt', num_threads=4)
    else:
        d = f'{ASR}/sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-v2-int8-2026-02-05'
        rec = sherpa_onnx.OfflineRecognizer.from_omnilingual_asr_ctc(
            model=f'{d}/model.int8.onnx', tokens=f'{d}/tokens.txt',
            num_threads=4)

    def heard(wav):
        a = np.concatenate([np.zeros(4000, np.float32), load(wav),
                            np.zeros(8000, np.float32)])
        s = rec.create_stream()
        s.accept_waveform(16000, a)
        rec.decode_stream(s)
        return m.norm(s.result.text)
    return heard


def whisper_tiny():
    from pywhispercpp.model import Model
    model = Model(t.MODELS['tiny'], n_threads=4, print_progress=False,
                  print_realtime=False, redirect_whispercpp_logs_to=None)

    def heard(wav):
        return m.norm(' '.join(x.text for x in model.transcribe(wav, language='ar')))
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

    files = {}
    for r, folder in RECITERS.items():
        for s, a in t.AYAHS:
            files[(r, s, a)] = t.fetch(r, folder, s, a)
    out = io.open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               'asr_candidates_2026-09-30.txt'), 'w',
                  encoding='utf-8')

    def say(x):
        out.write(x + '\n')
        out.flush()
        sys.stdout.buffer.write((x + '\n').encode('utf-8'))

    for label, make in [('tiny', whisper_tiny),
                        ('fastconformer', lambda: sherpa('fastconformer')),
                        ('omnilingual', lambda: sherpa('omnilingual'))]:
        heard = make()
        heard(files[('husary', 1, 1)])  # warm-up
        say(f'\n=== {label} ===')
        for band in (False, True):
            tot = ok_all = 0
            audio = proc = 0.0
            per = {}
            for (r, s, a), wav in files.items():
                src = t.derived(wav, 'band') if band else wav
                exp = expected(s, a)
                t0 = time.time()
                got = heard(src)
                proc += time.time() - t0
                audio += t.duration(src)
                ok, _, _ = m._check(exp, got)
                tot += len(exp)
                ok_all += ok
                p = per.setdefault(r, [0, 0])
                p[0] += ok
                p[1] += len(exp)
            say(f'{"PHONE BAND" if band else "clean":10} words {tot}: matched '
                f'{ok_all} ({100 * ok_all / tot:.1f}%)  '
                f'{proc / audio:.3f} s per audio second')
            say('   ' + '  '.join(f'{r} {100 * o / n:.0f}%' for r, (o, n) in per.items()))
        for hl, src, (s, a), how in t.HARD:
            wav = os.path.join(t.WORK, 'cmp', src)
            if how:
                wav = t.derived(wav, how)
            exp = expected(s, a)
            ok, _, _ = m._check(exp, heard(wav))
            say(f'  hard: {hl:38} {ok}/{len(exp)} = {100 * ok / len(exp):.0f}%')
    out.close()


if __name__ == '__main__':
    main()
