"""Choose each recording's breath timeline by LISTENING to it, and write
`adhan_phrase_timings.json`.

Two timelines compete for every recording:

* `silence` — what `measure_adhan_phrases.py` cut on ffmpeg's silencedetect
  (only when it produced exactly the right number of breaths);
* `speech` — what `align_adhan_phrases.py` placed from Whisper's reading and
  the recording's own breath gaps.

Neither is trusted on its own. `silence` put `azan13` one breath behind from
the second shahada on; `speech` misplaces boundaries where Whisper hears
nothing (al-Minshawi, Toubar). So each candidate is JUDGED: every breath is cut
out on its own and Whisper is asked what it hears in that clip alone. A wrong
cut puts the wrong words in a clip. The candidate whose clips read back as the
right breaths wins; if neither reads back well enough, the recording gets NO
timeline and the app shows the whole adhan instead of guessing.

Also decides which recordings are Fajr adhans — by whether «الصلاة خير من
النوم» is actually recited, not by file name.

    py -3 scripts/finalize_adhan_timings.py <whisper.json> <audio_dir> <timings.json> <report.json>
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from align_adhan_phrases import FAJR, FFMPEG, PLAIN, SR, norm, place, sim  # noqa: E402

# A candidate is accepted when its clips read back at least this well on
# average, with no more than this many clips that read as something else.
MIN_MEAN = 0.55
MAX_WRONG = 2
WRONG = 0.30

_model = None


def hear(path, a, b):
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        _model = WhisperModel('small', device='cpu', compute_type='int8')
    raw = subprocess.run(
        [FFMPEG, '-v', 'error', '-ss', str(a), '-to', str(b), '-i', path,
         '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
        capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768
    segs, _ = _model.transcribe(x, language='ar', beam_size=5,
                                condition_on_previous_text=False)
    return ' '.join(s.text.strip() for s in segs)


def judge(path, starts, total, expect):
    bounds = list(starts) + [total]
    clips = []
    for i, e in enumerate(expect):
        t = hear(path, bounds[i], bounds[i + 1])
        clips.append({'start': round(bounds[i], 2), 'expect': e, 'heard': t,
                      'sim': round(sim(t, e), 2) if t else 0.0})
    sims = [c['sim'] for c in clips]
    return {'mean': round(float(np.mean(sims)), 3),
            'wrong': sum(s < WRONG for s in sims), 'clips': clips}


def main():
    wpath, adir, tpath, rpath = sys.argv[1:5]
    W = json.load(open(wpath, encoding='utf-8'))
    old = json.load(open(tpath, encoding='utf-8'))
    report = {}
    if os.path.exists(rpath):
        report = json.load(open(rpath, encoding='utf-8'))
    for key, w in W.items():
        if key in report:
            continue
        path = os.path.join(adir, key)
        text = ' '.join(s['text'] for s in w['segments'])
        words = norm(text)
        fajr = 'خير' in words or 'النوم' in words or any(x.startswith('النو') for x in words)
        expect = FAJR if fajr else PLAIN
        new, _, total = place(path, w, fajr)
        cands = {}
        if None not in new:
            cands['speech'] = [round(x, 2) for x in new]
        ob = (old.get(key) or {}).get('breaths')
        if ob and len(ob) == len(expect):
            cands['silence'] = [round(x / 1000, 2) for x in ob]
        judged = {}
        for name, starts in cands.items():
            if name == 'silence' and 'speech' in judged and max(
                    abs(a - b) for a, b in zip(starts, cands['speech'])) < 1.0:
                judged[name] = judged['speech']  # the same timeline
                continue
            judged[name] = judge(path, starts, total, expect)
        ok = {n: j for n, j in judged.items()
              if j['mean'] >= MIN_MEAN and j['wrong'] <= MAX_WRONG}
        pick = max(ok, key=lambda n: ok[n]['mean']) if ok else None
        report[key] = {'fajr': fajr, 'total_s': round(total, 2), 'pick': pick,
                       'candidates': cands, 'judged': judged}
        print(key, 'fajr' if fajr else 'plain', 'pick=', pick,
              {n: (j['mean'], j['wrong']) for n, j in judged.items()}, flush=True)
        with open(rpath, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
