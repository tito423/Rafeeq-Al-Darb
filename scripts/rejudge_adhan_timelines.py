"""Second attempt at the adhans `finalize_adhan_timings.py` left with NO
timeline (azan3, azan13, azan19 as of 2026-10-07), so the app showed them
with no text at all.

Owner (2026-10-07): «كل الموجودين … المفروض ان النص يتعرض فيهم بمزامنة
اتأكد من كل ده».

Why they failed: Whisper `small` cannot read a drawn-out adhan («اشتركوا في
القناة», «مرحباً»), so neither the silence cut nor the speech cut could be
CONFIRMED, and an unconfirmed timeline is never shipped. Two changes, the
judging bar unchanged:

1. A third candidate cut from the sound itself: every dip in loudness is
   scored by how deep and how long it is, and the K-1 strongest dips inside
   the spoken span (K = 12 breaths, 14 with «الصلاة خير من النوم») become
   the breath boundaries. A muezzin breathes between breaths; that is the
   longest, deepest quiet in each.
2. Each candidate is judged with Whisper `large-v3` instead of `small`:
   every breath cut out alone and read back against what that breath says.
   Same acceptance as before (mean >= 0.55, at most 2 clips under 0.30).

    py -3 scripts/rejudge_adhan_timelines.py <model> <key> [<key> ...]

Writes docs/reports/_adhan_rejudged.json; changes nothing in the app.
"""
import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from align_adhan_phrases import (FAJR, FFMPEG, HOP, PLAIN, SR,  # noqa: E402
                                 energy_db, sim)
from finalize_adhan_timings import MAX_WRONG, MIN_MEAN, WRONG  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADIR = os.path.join(ROOT, 'rafeeq_app', 'assets', 'audio', 'adhan')
OLD = os.path.join(ROOT, 'docs', 'reports', '_adhan_judged.json')
OLD_F = os.path.join(ROOT, 'docs', 'reports', '_adhan_judged_fajr.json')
OUT = os.path.join(ROOT, 'docs', 'reports', '_adhan_rejudged.json')
TIMINGS = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'catalogs',
                       'adhan_phrase_timings.json')

_model = None


def model(size):
    global _model
    if _model is None:
        from faster_whisper import WhisperModel
        _model = WhisperModel(size, device='cpu', compute_type='int8')
    return _model


def hear(size, path, a, b):
    raw = subprocess.run(
        [FFMPEG, '-v', 'error', '-ss', str(a), '-to', str(b), '-i', path,
         '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
        capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768
    segs, _ = model(size).transcribe(x, language='ar', beam_size=5,
                                     condition_on_previous_text=False)
    return ' '.join(s.text.strip() for s in segs)


def judge(size, path, starts, total, expect):
    bounds = list(starts) + [total]
    clips = []
    for i, e in enumerate(expect):
        t = hear(size, path, bounds[i], bounds[i + 1])
        clips.append({'start': round(bounds[i], 2), 'expect': e, 'heard': t,
                      'sim': round(sim(t, e), 2) if t else 0.0})
        print(f'   {bounds[i]:7.2f}  {clips[-1]["sim"]:.2f}', flush=True)
    sims = [c['sim'] for c in clips]
    return {'mean': round(float(np.mean(sims)), 3),
            'wrong': sum(s < WRONG for s in sims), 'clips': clips}


def dips(path, k):
    """K breath starts cut at the K-1 strongest quiet stretches."""
    db = energy_db(path)
    n = len(db)
    loud = np.percentile(db, 90)
    speaking = np.where(db > loud - 20)[0]
    first, last = int(speaking[0]), int(speaking[-1])
    win = int(2.0 / HOP)
    cands = []
    i = first + 1
    while i < last:
        # A run of frames well under the surrounding speech.
        lo, hi = max(first, i - win), min(last, i + win)
        ref = min(np.max(db[lo:i + 1]), np.max(db[i:hi + 1]))
        if ref - db[i] >= 10:
            j = i
            while j < last and ref - db[j] >= 10:
                j += 1
            seg = db[i:j]
            depth = ref - float(np.min(seg))
            dur = (j - i) * HOP
            # The next breath starts where the sound rises back.
            cands.append((depth * (0.3 + dur), j * HOP))
            i = j + 1
        else:
            i += 1
    cands.sort(reverse=True)
    chosen = []
    for score, t in cands:
        if all(abs(t - c) >= 3.0 for c in chosen) and t - first * HOP >= 3.0:
            chosen.append(t)
        if len(chosen) == k - 1:
            break
    if len(chosen) < k - 1:
        return None, n * HOP
    return [round(first * HOP, 2)] + sorted(round(c, 2) for c in chosen), n * HOP


def main():
    size = sys.argv[1]
    keys = sys.argv[2:]
    old = {}
    for f in (OLD, OLD_F):
        if os.path.exists(f):
            old.update(json.load(open(f, encoding='utf-8')))
    meta = json.load(open(TIMINGS, encoding='utf-8'))
    report = json.load(open(OUT, encoding='utf-8')) if os.path.exists(OUT) else {}
    for key in keys:
        path = os.path.join(ADIR, key)
        fajr = bool((meta.get(key) or {}).get('fajr'))
        expect = FAJR if fajr else PLAIN
        cands = dict((old.get(key) or {}).get('candidates') or {})
        cut, total = dips(path, len(expect))
        if cut:
            cands['dips'] = cut
        res = {}
        for name, starts in cands.items():
            if len(starts) != len(expect):
                continue
            print(key, name, starts, flush=True)
            res[name] = judge(size, path, starts, total, expect)
            print(key, name, res[name]['mean'], res[name]['wrong'], flush=True)
        ok = {n: j for n, j in res.items()
              if j['mean'] >= MIN_MEAN and j['wrong'] <= MAX_WRONG}
        pick = max(ok, key=lambda n: ok[n]['mean']) if ok else None
        report[f'{key}@{size}'] = {'fajr': fajr, 'total_s': round(total, 2),
                                   'pick': pick, 'candidates': cands,
                                   'judged': res}
        print(key, 'PICK', pick, flush=True)
        with open(OUT, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
