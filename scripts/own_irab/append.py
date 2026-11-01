"""Appends a block of entries (a text file of Python list lines) to the end
of fill_NNN.py's list I, then reports the WIP position and, for review, only
the entries that carry hand-typed Arabic (pure short codes are covered by
irab_dsl.py --test, so they are not reprinted).
    py -3 scripts/own_irab/append.py 25 block.txt"""
import importlib, io, os, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from irab_dsl import x
from write_surah import tokens

s, block = int(sys.argv[1]), sys.argv[2]
p = os.path.join(H, f'fill_{s:03d}.py')
src = open(p, encoding='utf-8').read()
k = '\n]\n\nif __name__'
assert src.count(k) == 1, 'list end not found'
before = len(importlib.import_module(f'fill_{s:03d}').I)
add = open(block, encoding='utf-8').read().rstrip('\n')
open(p, 'w', encoding='utf-8').write(src.replace(k, '\n' + add + k))
mod = importlib.reload(importlib.import_module(f'fill_{s:03d}'))
toks = tokens(s)
I = mod.I
print(f'{len(I)} of {len(toks)}; last {toks[len(I)-1]}; next {toks[len(I)] if len(I) < len(toks) else None}')
CODE = re.compile(r'^(W:\S+ )?[A-Za-z_0-9]+(:.*)?$')
for (a, w), e in zip(toks[before:len(I)], I[before:]):
    t = e['text'] if isinstance(e, dict) else (e[0] if isinstance(e, tuple) else e)
    if any(not CODE.match(c.strip()) for c in t.split(',')):
        print(f'{a} {w}: {x(t)}')
