"""Builds fill_SSS.py from the checked blocks of a surah, in ayah order.
Every block is re-checked (blockcheck.load) and the ranges must tile the
surah exactly, otherwise nothing is written.
    py -3 scripts/own_irab/join_blocks.py 4 <dir with block_4_A_B.txt> "name"
"""
import datetime, glob, io, os, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from blockcheck import load
from write_surah import tokens

s, d, name = int(sys.argv[1]), sys.argv[2], sys.argv[3]
files = []
for f in glob.glob(os.path.join(d, f'block_{s}_*_*.txt')):
    m = re.fullmatch(rf'block_{s}_(\d+)_(\d+)\.txt', os.path.basename(f))
    if m:
        files.append((int(m.group(1)), int(m.group(2)), f))
files.sort()
last = max(a for a, _ in tokens(s))
nxt, body = 1, []
for a0, a1, f in files:
    assert a0 == nxt, f'gap or overlap at ayah {nxt}: next block starts at {a0}'
    out, errs = load(s, a0, a1, f)
    assert not errs, (f, errs[:3])
    body.append(open(f, encoding='utf-8').read().rstrip('\n'))
    nxt = a1 + 1
assert nxt == last + 1, f'blocks end at ayah {nxt - 1}, the surah has {last}'
today = datetime.date.today().isoformat()
head = f'''"""{name} ({s}), written {today} word by word against al-Da'as
(sheet.py {s} --work); every word al-Jadwal reads differently was read in
Darwish too (sheet.py --only-d).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt) by chunk writers
(CHUNK_PROMPT.md), each block passed blockcheck.py; joined by join_blocks.py.
Run once: fills {s:03d}.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {{'text': text, 'check': 'alt', 'alts': [{{'book': b, 'text': t}} for b, t in alts]}}


IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
'''
foot = f'''
]

if __name__ == '__main__':
    toks = tokens({s})
    if len(I) == len(toks):
        write({s}, I, "written {today}, every word checked against al-Da'as (sheet.py {s} --work); differences read in al-Jadwal and Darwish, the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
'''
open(os.path.join(H, f'fill_{s:03d}.py'), 'w', encoding='utf-8', newline='\n').write(head + '\n'.join(body) + foot)
print(f'fill_{s:03d}.py written from', len(files), 'blocks')
