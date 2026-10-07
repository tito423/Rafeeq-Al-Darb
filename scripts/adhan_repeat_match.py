"""Where does a breath's REPEAT start? For recordings Whisper cannot read.

Every line of the adhan is said twice in a row, and a muezzin sings the
second breath to (nearly) the same melody as the first. So with the first
breath known, the second one's start is where the region after it best
matches the first breath's sound: subsequence DTW over chroma + MFCC.

Checked on recordings whose timeline is confirmed word by word before it is
used on one that is not.

    py -3 scripts/adhan_repeat_match.py <file.mp3> <ref_start> <ref_end> <search_start> <search_end>
"""
import subprocess
import sys

import librosa
import numpy as np

sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from align_adhan_phrases import FFMPEG  # noqa: E402

SR = 16000
HOP = 512


def load(path):
    raw = subprocess.run(
        [FFMPEG, '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR),
         '-f', 's16le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768


def feats(y):
    c = librosa.feature.chroma_cqt(y=y, sr=SR, hop_length=HOP)
    m = librosa.feature.mfcc(y=y, sr=SR, n_mfcc=13, hop_length=HOP)
    m = (m - m.mean(axis=1, keepdims=True)) / (m.std(axis=1, keepdims=True) + 1e-6)
    return np.vstack([c * 2, m[1:] * 0.5])


def match(y, ref, search):
    a = feats(y[int(ref[0] * SR):int(ref[1] * SR)])
    b = feats(y[int(search[0] * SR):int(search[1] * SR)])
    D, wp = librosa.sequence.dtw(X=a, Y=b, subseq=True, metric='cosine')
    cost = D[-1, :]
    end = int(np.argmin(cost))
    path = wp[::-1]
    # Start of the best path that ends at `end`.
    D2, wp2 = librosa.sequence.dtw(X=a, Y=b[:, :end + 1], subseq=True,
                                   metric='cosine')
    start = wp2[-1][1]
    t = lambda f: search[0] + f * HOP / SR  # noqa: E731
    return t(start), t(end), float(cost[end] / a.shape[1]), path


if __name__ == '__main__':
    path = sys.argv[1]
    r0, r1, s0, s1 = map(float, sys.argv[2:6])
    y = load(path)
    st, en, c, _ = match(y, (r0, r1), (s0, s1))
    print(f'repeat starts {st:.2f} ends {en:.2f} cost/frame {c:.3f}')
