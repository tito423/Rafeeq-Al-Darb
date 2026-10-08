"""Check complete morning / evening adhkar recordings before the app lists
them (owner, 2026-10-08: real reciters, morning and evening separate).

A file name is a claim, not evidence (the adhan clips once attributed to
muezzins nobody had verified). For every candidate this downloads the
file, transcribes ALL of it with faster-whisper, and reports:
  - how often «أصبحنا» and «أمسينا» are said - a morning file must say the
    first and not only the second, an evening file the reverse;
  - the opening and closing words, and where speech ends against the
    file's length (a recording cut short ends far from its last word, or
    is simply too short to hold the adhkar);
The voice's identity cannot be proved by ASR - that stays as the source
names it, and the report says which sources are first-hand.

Usage: py -3 scripts/verify_adhkar_recordings.py  (writes
scripts/out/adhkar_verify.json; resumable - finished files are skipped).
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')
OUT = os.path.join(os.path.dirname(__file__), 'out', 'adhkar_verify.json')
CACHE = r'E:\DevEnv\adhkar_verify'
UA = {'User-Agent': 'RafeeqAlDarb/1.0 (github.com/tito423/Rafeeq-Al-Darb)'}

IA1 = 'https://archive.org/download/azkar_alsabah_w_almsaa/'
IA2 = 'https://archive.org/download/AthkarAlsabahAbdulazizBi356856835685683356568/'
IH = 'https://d1.islamhouse.com/data/ar/ih_sounds/chain_01/Mishari_Raashid/Azkar_AlSba7_w_AlMsa/'
CANDIDATES = [
    ('alafasy_ih_1434', 'morning', IH + 'ar_1434_Azkar_AlSba7.mp3'),
    ('alafasy_ih_1434', 'evening', IH + 'ar_1434_Azkar_AlMsa.mp3'),
]
for name, m, e in [
    ('fares_abbad', 'fares_abad_sabah', 'fares_abad_masaa'),
    ('hassan_saleh', 'hasn_saleh_sabah', 'hasn_saleh_masaa'),
    ('alafasy_ia', 'mashary_elafasy_sabah', 'mashary_elafasy_masaa'),
    ('muhammad_jibreel', 'mohamed_jebril_sabah', 'mohamed_jebril_massa'),
    ('rami_muhammad', 'rami_mohamed_sabah', 'rami_mohamed_masaa'),
    ('samir_albashiri', 'samir_albashiri_sabah', 'samir_albashiri_masaa'),
    ('yahya_hawwa', 'yahya_hawwa_sabah', 'yahya_hawwa_masaa'),
]:
    CANDIDATES.append((name, 'morning', IA1 + m + '.mp3'))
    CANDIDATES.append((name, 'evening', IA1 + e + '.mp3'))
for name, m, e in [
    ('faisal_labban', 'Athkar Alsabah - Faisal Labban', 'Athkar Almasaa - Faisal Labban'),
    ('abdulaziz_bin_ibrahim', 'AthkarAlsabah-AbdulazizBinIbrahim', 'AthkarAlmasaa-AbdulazizBinIbrahim'),
]:
    CANDIDATES.append((name, 'morning', IA2 + urllib.parse.quote(m) + '.mp3'))
    CANDIDATES.append((name, 'evening', IA2 + urllib.parse.quote(e) + '.mp3'))


def norm(t):
    t = re.sub('[\u064B-\u0652\u0670\u0640]', '', t)
    return t.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')


FFMPEG = 'C:/Program Files/ShareX/ffmpeg.exe'  # TRAPS #14


def pcm16k(path):
    """Mono 16 kHz float32, decoded by ffmpeg: the installed PyAV is newer
    than faster-whisper's own decoder expects (open() lost an argument)."""
    import subprocess
    import numpy as np
    raw = subprocess.run(
        [FFMPEG, '-v', 'error', '-i', path, '-f', 's16le', '-ac', '1', '-ar', '16000', '-'],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0


def fetch(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return
    tmp = path + '.part'
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r, open(tmp, 'wb') as f:
        while True:
            b = r.read(1 << 20)
            if not b:
                break
            f.write(b)
    os.replace(tmp, path)


def main():
    from faster_whisper import WhisperModel
    os.makedirs(CACHE, exist_ok=True)
    report = json.load(open(OUT, encoding='utf-8')) if os.path.exists(OUT) else {}
    model = WhisperModel('small', device='cpu', compute_type='int8')
    for name, part, url in CANDIDATES:
        key = f'{name}/{part}'
        if key in report:
            continue
        path = os.path.join(CACHE, f'{name}_{part}.mp3')
        try:
            fetch(url, path)
        except Exception as e:
            report[key] = {'url': url, 'error': str(e)}
            print(key, 'DOWNLOAD FAILED', e, flush=True)
            continue
        audio = pcm16k(path)
        dur = len(audio) / 16000
        # The opening eight minutes hold «أصبحنا/أمسينا» (after Ayat al-Kursi
        # and the three Quls); the closing two show whether the file ends on
        # speech that finishes or is cut. The whole file at CPU speed was
        # ~10 min each - 19 files would have taken hours.
        head, _ = model.transcribe(audio[: 16000 * 480], language='ar', vad_filter=True, beam_size=1)
        head = list(head)
        tail_from = max(0.0, dur - 120)
        tail, _ = model.transcribe(audio[int(16000 * tail_from):], language='ar', vad_filter=True, beam_size=1)
        tail = list(tail)
        segs = head + tail
        text = norm(' '.join(s.text for s in segs))
        last_end = tail_from + tail[-1].end if tail else 0

        class info:  # noqa: N801 - same fields the report reads
            duration = dur
        r = {
            'url': url,
            'bytes': os.path.getsize(path),
            'duration_s': round(info.duration, 1),
            'speech_ends_s': round(last_end, 1),
            'asbahna': len(re.findall('اصبحنا', text)),
            'amsayna': len(re.findall('امسينا', text)),
            'ayat_kursi': 'الحي القيوم' in text,
            # The words only one of the two says: «أصبحنا وأصبح الملك لله» /
            # «أمسينا وأمسى الملك لله». Both files say «بك أصبحنا وبك
            # أمسينا», so the bare verbs prove nothing.
            'mulk_morning': len(re.findall('اصبح الملك', text)),
            'mulk_evening': len(re.findall('امسى الملك|امسي الملك', text)),
            'start': ' '.join(s.text for s in head[:3])[:160],
            'end': ' '.join(s.text for s in tail[-3:])[-160:],
        }
        report[key] = r
        json.dump(report, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(key, {k: r[k] for k in ('duration_s', 'speech_ends_s', 'mulk_morning', 'mulk_evening', 'asbahna', 'amsayna', 'ayat_kursi')}, flush=True)
    print('DONE', flush=True)


if __name__ == '__main__':
    main()
