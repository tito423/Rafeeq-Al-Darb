"""WIP check for a fill_NNN.py in short codes: per-ayah counts (ayah_counts.py)
and that every entry expands (irab_dsl.x).   py -3 wip_check.py 28"""
import importlib, subprocess, sys, os
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from irab_dsl import x
from write_surah import tokens
s = int(sys.argv[1])
subprocess.run([sys.executable, os.path.join(H, 'ayah_counts.py'), str(s)])
I = importlib.import_module('fill_%03d' % s).I
for i, e in enumerate(I):
    t = e['text'] if isinstance(e, dict) else (e[0] if isinstance(e, tuple) else e)
    try:
        x(t)
    except Exception as err:
        print('ENTRY', i, tokens(s)[i], err)
toks = tokens(s)
print(len(I), 'of', len(toks), 'last', toks[len(I) - 1])
