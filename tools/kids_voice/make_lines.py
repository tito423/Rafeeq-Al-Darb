# narration .md -> lines.tsv (scene\ttext, recitation rows skipped) in the current folder
#   py -3 ../make_lines.py musa
import re, sys
src = open(rf'E:/My Projects/Rafiq-Al-Darb/docs/kids_stories/{sys.argv[1]}_narration.md', encoding='utf-8').read()
out = []
for row in src.splitlines():
    if not re.match(r'^\| \d+ \|', row): continue
    cells = [c.strip() for c in row.strip('|').split('|')]
    if 'تلاوة' in cells[1]: continue
    out.append(f'{int(cells[0])}\t{cells[1]}')
open('lines.tsv', 'w', encoding='utf-8').write('\n'.join(out))
print(len(out), 'lines:', [l.split('\t')[0] for l in out])
