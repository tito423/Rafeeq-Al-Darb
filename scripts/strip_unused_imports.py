# -*- coding: utf-8 -*-
"""Drop the imports the analyzer says are unused or redundant.

Splitting a big file copies its whole import block into every piece, so most
of them are dead in most of the pieces. The analyzer is the only thing that
actually knows which; this reads its report, deletes exactly those lines, and
repeats until it has nothing left to say.
"""
import io
import re
import subprocess
import sys

TARGET = sys.argv[1] if len(sys.argv) > 1 else 'lib test'
BACKSLASH = chr(92)

for round_ in range(12):
    out = subprocess.run(['flutter', 'analyze'] + TARGET.split(),
                         capture_output=True, text=True, shell=True).stdout
    hits = {}
    for line in out.splitlines():
        if 'unused_import' not in line and 'unnecessary_import' not in line:
            continue
        m = re.search(r'- (lib[' + BACKSLASH + BACKSLASH + r'/][^ ]+' +
                      BACKSLASH + r'.dart):(' + BACKSLASH + r'd+):' +
                      BACKSLASH + r'd+ -', line)
        if m:
            path = m.group(1).replace(BACKSLASH, '/')
            hits.setdefault(path, set()).add(int(m.group(2)))
    if not hits:
        print('round', round_, '- nothing left')
        break
    for path, nums in hits.items():
        lines = io.open(path, encoding='utf-8').read().split('\n')
        kept = [l for i, l in enumerate(lines, 1) if i not in nums]
        io.open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(kept))
    print('round', round_, '- removed',
          sum(len(v) for v in hits.values()), 'in', len(hits), 'files')
