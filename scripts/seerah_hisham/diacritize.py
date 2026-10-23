"""Diacritize the OpenITI Sira text with CATT (encoder-decoder), keeping punctuation and structure."""
import sys, re, json, time, os
sys.path.insert(0, os.environ.get('CATT_PKG', ''))  # folder holding catt_tashkeel + onnx_models
from catt_tashkeel import CATTEncoderDecoder

SRC, CACHE = sys.argv[1], sys.argv[2]
WORD = re.compile(r'[ء-غف-ي]+')
HARAKAT = re.compile(r'[ً-ْٰ]')
MAXC = 220

HALF = 110

def halves(words):
    """Long segments are vowelled in pieces of <= HALF chars (2x faster decode)."""
    out, cur, n = [], [], 0
    for w in words:
        if n + len(w) + 1 > HALF and cur:
            out.append(cur); cur, n = [], 0
        cur.append(w); n += len(w) + 1
    if cur: out.append(cur)
    return out

text = open(SRC, encoding='utf-8').read().split('#META#Header#End#', 1)[1]
words = WORD.findall(text)
uniq_segments = []
# Segment the whole word stream on sentence punctuation and length.
segs, cur, curlen = [], [], 0
for m in re.finditer(r'[ء-غف-ي]+|[.؟!:؛\n#]', text):
    tok = m.group()
    if WORD.fullmatch(tok):
        if curlen + len(tok) + 1 > MAXC and cur:
            segs.append(cur); cur, curlen = [], 0
        cur.append(tok); curlen += len(tok) + 1
    elif tok in '.؟!:؛' and curlen > 60:
        segs.append(cur); cur, curlen = [], 0
if cur: segs.append(cur)
assert sum(map(len, segs)) == len(words)
print('words', len(words), 'segments', len(segs), flush=True)

cache = {}
if os.path.exists(CACHE):
    for line in open(CACHE, encoding='utf-8'):
        k, v = json.loads(line); cache[k] = v
want = set()
for s in segs:
    k = ' '.join(s)
    if k in cache: continue
    for h in halves(s): want.add(' '.join(h))
todo = sorted(want - cache.keys(), key=len)
print('todo', len(todo), flush=True)
model = CATTEncoderDecoder()
B = 48; t0 = time.time()
with open(CACHE, 'a', encoding='utf-8') as out:
    for i in range(0, len(todo), B):
        batch = todo[i:i+B]
        res = model.do_tashkeel_batch(batch, batch_size=B, verbose=False)
        for k, v in zip(batch, res):
            out.write(json.dumps([k, v], ensure_ascii=False) + '\n')
        out.flush()
        if (i // B) % 20 == 0:
            print(f'{i+len(batch)}/{len(todo)} {time.time()-t0:.0f}s', flush=True)
print('done', flush=True)
