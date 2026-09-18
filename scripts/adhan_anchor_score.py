"""How well a breath timeline agrees with what Whisper heard.

For every Whisper segment that clearly reads as one breath of the adhan
(similarity >= 0.6 to exactly one breath text), check which breath the
timeline says is sounding at the segment's middle. The score is the share of
those anchors the timeline gets right. Used to choose, per recording, between
the silence-cut timeline and the speech-aligned one - and to refuse both when
neither agrees with what is said.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from align_adhan_phrases import FAJR, PLAIN, sim  # noqa: E402

CLASSES = {'T': 'الله اكبر الله اكبر', 'S1': 'اشهد ان لا اله الا الله',
           'S2': 'اشهد ان محمدا رسول الله', 'H1': 'حي على الصلاه',
           'H2': 'حي على الفلاح', 'F': 'الصلاه خير من النوم', 'L': 'لا اله الا الله'}
REV = {v: k for k, v in CLASSES.items()}


def label(text):
    scored = sorted(((sim(text, v), k) for k, v in CLASSES.items()), reverse=True)
    (s1, k1), (s2, _) = scored[0], scored[1]
    return k1 if s1 >= 0.6 and s1 - s2 >= 0.12 else None


def score(segments, starts, fajr):
    seq = [REV[b] for b in (FAJR if fajr else PLAIN)]
    hit = n = 0
    for s in segments:
        k = label(s['text'])
        if not k:
            continue
        mid = (s['start'] + s['end']) / 2
        i = max((j for j, t in enumerate(starts) if t <= mid), default=0)
        n += 1
        hit += seq[i] == k
    return hit, n
