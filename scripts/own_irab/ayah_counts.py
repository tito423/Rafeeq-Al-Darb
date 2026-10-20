"""Checks a fill_NNN.py before it is run: the entries under each «# N»
comment must be exactly as many as the mushaf tokens of ayah N, so a slip
shows up at its ayah instead of shifting every later word.
    py -3 scripts/own_irab/ayah_counts.py 42"""
import re, ast, collections, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from write_surah import tokens
s = int(sys.argv[1])
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fill_%03d.py' % s), encoding='utf-8').read()
body = src[src.index('I = ['):src.index('# @@NEXT') if '# @@NEXT' in src else src.index('\n]\n')]
parts = re.split(r'\n # (\d+)[^\n]*\n', body)
need = collections.Counter(a for a, _ in tokens(s))
bad = []
for i in range(1, len(parts), 2):
    a = int(parts[i]); n = len(ast.parse('[' + parts[i + 1] + ']', mode='eval').body.elts)
    if n != need[a]: bad.append((a, n, need[a]))
print('ayahs', len(parts) // 2, 'mismatch', bad or 'none')
