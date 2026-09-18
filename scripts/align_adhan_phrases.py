"""Place each breath of the adhan on the recording, by what is SAID.

`measure_adhan_phrases.py` cut recordings on silence and accepted a cut when
the count came out right. The count coming out right is not the cut being
right: on `azan13` it read two bursts of noise before the first takbir as two
breaths, so from the second shahada on every line on screen was one breath
behind the muezzin — «صفر تزامن». And every recording where no threshold gave
exactly twelve fell back to sharing the time out by letters.

This does it the other way round:

1. Whisper (`whisper_adhan_batch.py`) says what is recited and roughly when.
2. Its segments are matched, in order, to the breaths the adhan must contain
   (12, or 14 with «الصلاة خير من النوم»), by how close each segment's text is
   to that breath's words. Segments that match nothing — noise, a muezzin's
   extra flourish — are skipped; a breath Whisper missed is left open.
3. Each matched breath's start is snapped to the recording's own breath gap:
   the quietest moment in the few seconds before Whisper's start, then the
   first frame after it that rises clearly out of that quiet. Whisper places
   words to within a second or two; the gap is where the muezzin really
   draws breath.
4. A breath Whisper missed is taken from the loudest onset between its two
   neighbours, and flagged, so it can be checked.

Then `--verify` cuts every breath out on its own and asks Whisper what it
hears in that clip alone — an independent reading of each boundary, since a
wrong cut puts the wrong words in the clip.

    py -3 scripts/align_adhan_phrases.py <whisper.json> <audio_dir> <out.json> [--verify]
"""
import difflib
import json
import os
import re
import subprocess
import sys

import numpy as np

FFMPEG = r'C:\Program Files\ShareX\ffmpeg.exe'
SR = 16000
HOP = 0.05  # seconds per energy frame

# What each breath says. «الله أكبر ×٤» is recited as two breaths of two.
T2 = 'الله اكبر الله اكبر'
S1 = 'اشهد ان لا اله الا الله'
S2 = 'اشهد ان محمدا رسول الله'
H1 = 'حي على الصلاه'
H2 = 'حي على الفلاح'
F = 'الصلاه خير من النوم'
L = 'لا اله الا الله'
PLAIN = [T2, T2, S1, S1, S2, S2, H1, H1, H2, H2, T2, L]
FAJR = [T2, T2, S1, S1, S2, S2, H1, H1, H2, H2, F, F, T2, L]

_DIAC = re.compile('[\u064B-\u0652\u0670\u0640]')


def norm(t):
    t = _DIAC.sub('', t)
    t = re.sub('[إأآٱ]', 'ا', t).replace('ة', 'ه').replace('ى', 'ي')
    return re.sub(r'[^\u0621-\u064A ]', ' ', t).split()


def sim(a, b):
    """0..1 — how much of breath text [b] segment text [a] resembles."""
    return difflib.SequenceMatcher(None, ' '.join(norm(a)), ' '.join(norm(b))).ratio()


def energy_db(path):
    raw = subprocess.run(
        [FFMPEG, '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR),
         '-f', 's16le', '-'], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768
    n = int(SR * HOP)
    frames = len(x) // n
    rms = np.sqrt(np.mean(x[:frames * n].reshape(frames, n) ** 2, axis=1) + 1e-10)
    db = 20 * np.log10(rms)
    # Smooth over ~150 ms so a consonant's dip is not read as a breath.
    k = np.ones(3) / 3
    return np.convolve(db, k, mode='same')


def snap(db, t, back=4.0, fwd=1.5):
    """The onset of the breath Whisper says starts near [t]."""
    lo = max(0, int((t - back) / HOP))
    hi = min(len(db) - 1, int((t + fwd) / HOP))
    if hi <= lo:
        return t
    seg = db[lo:hi]
    m = lo + int(np.argmin(seg))
    floor = db[m]
    peak = np.max(db[m:hi + 1]) if hi > m else floor
    if peak - floor < 8:  # no real gap here: trust Whisper
        return t
    rise = floor + 0.35 * (peak - floor)
    for i in range(m, hi + 1):
        if db[i] >= rise:
            return i * HOP
    return t


def align(segments, breaths):
    """Monotonic match of Whisper segments to expected breaths (DP)."""
    n, m = len(breaths), len(segments)
    score = [[0.0] * (m + 1) for _ in range(n + 1)]
    back = [[None] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        for j in range(m + 1):
            best, arg = (0.0 if i == 0 and j == 0 else -1e9), None
            if i > 0 and score[i - 1][j] > best:
                best, arg = score[i - 1][j], 'skip_breath'
            if j > 0 and score[i][j - 1] > best:
                best, arg = score[i][j - 1], 'skip_seg'
            if i > 0 and j > 0:
                s = sim(segments[j - 1]['text'], breaths[i - 1])
                if s >= 0.35 and score[i - 1][j - 1] + s > best:
                    best, arg = score[i - 1][j - 1] + s, 'match'
            if i or j:
                score[i][j], back[i][j] = best, arg
    out = [None] * n
    i, j = n, m
    while i or j:
        a = back[i][j]
        if a == 'match':
            out[i - 1] = (j - 1, sim(segments[j - 1]['text'], breaths[i - 1]))
            i, j = i - 1, j - 1
        elif a == 'skip_breath':
            i -= 1
        else:
            j -= 1
    return out


def split_double(segments):
    """Whisper sometimes hears two breaths as one segment ("حي على الصلاة"
    twice in 16 s). Split a segment whose words repeat, at the word gap."""
    out = []
    for s in segments:
        ws = s.get('words') or []
        cut = None
        if len(ws) >= 4:
            gaps = [(ws[k + 1]['start'] - ws[k]['end'], k) for k in range(len(ws) - 1)]
            g, k = max(gaps)
            if g >= 1.0:
                cut = k
        if cut is None:
            out.append(s)
            continue
        a, b = ws[:cut + 1], ws[cut + 1:]
        out.append({'start': a[0]['start'], 'end': a[-1]['end'],
                    'text': ' '.join(w['w'] for w in a), 'words': a})
        out.append({'start': b[0]['start'], 'end': b[-1]['end'],
                    'text': ' '.join(w['w'] for w in b), 'words': b})
    return out


GAPS = {}
# How much a long breath gap counts against how the words read. A muezzin
# draws a real breath between phrases; a dip inside a phrase is short.
# No breath of the adhan is recited in under four seconds.
MIN_BREATH = 4.0
GAP_W = float(os.environ.get('GAP_W', '1.0'))


def candidates(db, min_gap=0.3, depth=9.0):
    """Every moment the muezzin could be starting a breath: the end of a
    stretch at least [min_gap] s long that sits [depth] dB under the loud
    part around it."""
    n = len(db)
    w = int(3.0 / HOP)
    loud = np.array([np.percentile(db[max(0, i - w):i + w], 90) for i in range(n)])
    quiet = db < loud - depth
    out, run = [], 0
    for i in range(n):
        if quiet[i]:
            run += 1
        else:
            if run * HOP >= min_gap:
                out.append(round(i * HOP, 2))
                GAPS[round(i * HOP, 2)] = run * HOP
            run = 0
    if not quiet[0]:
        out.insert(0, 0.0)
    return out


def anchor_label(text):
    """The breath text [text] clearly reads as, or None."""
    texts = sorted(set(FAJR))
    scored = sorted(((sim(text, b), b) for b in texts), reverse=True)
    (s1, b1), (s2, _) = scored[0], scored[1]
    return b1 if s1 >= 0.6 and s1 - s2 >= 0.12 else None


def words_in(words, a, b):
    return ' '.join(x['w'] for x in words if a <= (x['start'] + x['end']) / 2 < b)


def place(path, whisper, fajr):
    """Choose, from the recording's own breath gaps, the onsets whose
    intervals best read as the adhan's breaths in order."""
    breaths = FAJR if fajr else PLAIN
    db = energy_db(path)
    total = len(db) * HOP
    words = [x for s in whisper['segments'] for x in (s.get('words') or [])]
    cand = candidates(db)
    first_word = min((x['start'] for x in words), default=0.0)
    cand = [c for c in cand if c >= first_word - 3.0]
    # The first breath starts at the first word, not at noise before it.
    cand = [max(0.0, round(snap(db, first_word), 2))] + [c for c in cand if c > first_word + 1.0]
    N, K = len(cand), len(breaths)
    ends = cand[1:] + [total]
    NEG = -1e9
    # best[k][j]: best score with breath k starting at candidate j.
    best = [[NEG] * N for _ in range(K)]
    prev = [[None] * N for _ in range(K)]
    cache = {}

    # Whisper's confident readings — a segment that reads clearly as ONE
    # breath text — pin which breath must be sounding at that moment. The
    # breath boundaries themselves come from the recording's own breath gaps:
    # Whisper's word times drift by seconds on a melismatic muezzin, and on
    # Toubar or al-Minshawi it hears nothing at all for a minute at a time, so
    # it cannot place a boundary; it can only veto a wrong one.
    anchors = []
    for sg in whisper['segments']:
        lab = anchor_label(sg['text'])
        if lab is not None:
            anchors.append(((sg['start'] + sg['end']) / 2, lab))

    def score(k, j, jn):
        b = cand[jn] if jn is not None else total
        key = (k, j, jn)
        if key not in cache:
            v = 0.0
            for t, lab in anchors:
                if cand[j] <= t < b:
                    v += 0.5 if lab == breaths[k] else -3.0
            cache[key] = v
        return cache[key]

    for j in range(N):
        best[0][j] = 0.0 if j == 0 else -0.05 * j  # prefer the first onset
    for k in range(1, K):
        for j in range(k, N):
            for i in range(k - 1, j):
                if best[k - 1][i] == NEG or cand[j] - cand[i] < MIN_BREATH:
                    continue
                v = (best[k - 1][i] + score(k - 1, i, j)
                     + GAP_W * min(GAPS.get(cand[j], 0.0), 3.0) / 3.0)
                if v > best[k][j]:
                    best[k][j], prev[k][j] = v, i
    fin, jl = NEG, None
    for j in range(K - 1, N):
        if best[K - 1][j] == NEG:
            continue
        v = best[K - 1][j] + score(K - 1, j, None)
        if v > fin:
            fin, jl = v, j
    if jl is None:
        return [None] * K, ['no path'] * K, total
    idx = [0] * K
    idx[K - 1] = jl
    for k in range(K - 1, 0, -1):
        idx[k - 1] = prev[k][idx[k]]
    starts = [cand[j] for j in idx]
    how = []
    for k in range(K):
        b = starts[k + 1] if k + 1 < K else total
        t = words_in(words, starts[k], b)
        how.append(f'{sim(t, breaths[k]) if t else 0:.2f} «{t}»')
    return starts, how, total


def main():
    wpath, adir, out = sys.argv[1:4]
    verify = '--verify' in sys.argv
    W = json.load(open(wpath, encoding='utf-8'))
    res = {}
    model = None
    for key, w in W.items():
        text = ' '.join(s['text'] for s in w['segments'])
        fajr = any(x in norm(text) for x in ('خير', 'النوم', 'نوم'))
        path = os.path.join(adir, key)
        starts, how, total = place(path, w, fajr)
        r = {'fajr': fajr, 'total_s': round(total, 2), 'breaths': starts, 'how': how}
        if verify and None not in starts:
            if model is None:
                from faster_whisper import WhisperModel
                model = WhisperModel('small', device='cpu', compute_type='int8')
            heard = []
            bounds = starts + [total]
            for i in range(len(starts)):
                clip = subprocess.run(
                    [FFMPEG, '-v', 'error', '-ss', str(bounds[i]), '-to', str(bounds[i + 1]),
                     '-i', path, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
                    capture_output=True, check=True).stdout
                x = np.frombuffer(clip, dtype=np.int16).astype(np.float32) / 32768
                segs, _ = model.transcribe(x, language='ar', beam_size=5,
                                           condition_on_previous_text=False)
                t = ' '.join(s.text.strip() for s in segs)
                exp = (FAJR if fajr else PLAIN)[i]
                heard.append({'expect': exp, 'heard': t, 'sim': round(sim(t, exp), 2)})
            r['verify'] = heard
        res[key] = r
        print('done', key, 'fajr' if fajr else '', flush=True)
        with open(out, 'w', encoding='utf-8') as f:
            json.dump(res, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
