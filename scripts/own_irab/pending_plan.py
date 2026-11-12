"""Turns judge CHANGE lines into (old, new) replacements on our text. Waw/fa
kind changes edit only the particle's name and, for a fasiha, the clause tail;
everything else uses the judge's full proposal. Prints OURS -> NEW for review
and writes pk2B/plan_<name>.json."""
import glob, json, re, sys
sys.stdout.reconfigure(encoding='utf-8')
pk = {}
for f in glob.glob('pk2B/j*.txt'):
    for blk in re.split(r'(?m)^(?=### )', open(f, encoding='utf-8').read()):
        if blk.startswith('### '): pk[blk.split()[1]] = blk
KIND = {'استئناف': 'حرف استئناف', 'عاطف': 'حرف عطف', 'معطوف': 'حرف عطف', 'حالية': 'حالية', 'حاليّة': 'حالية',
        'اعتراض': 'اعتراضية', 'معترض': 'اعتراضية', 'رابطة': 'رابطة لجواب الشرط'}
LEAD = re.compile(r'^(الواو|الفاء) (حالية|حرف عطف|حرف استئناف|الفصيحة|زائدة|عاطفة|استئنافية|اعتراضية|رابطة لجواب الشرط)')
out = []
for line in open(sys.argv[1], encoding='utf-8'):
    p = line.rstrip('\n').split('\t')
    if len(p) < 4: continue
    pid, _, reason, prop = p[:4]
    blk = pk[pid]
    ay = re.search(r'(?m)^AYAH: (.*)$', blk).group(1)
    w = re.search(r'\[([^\]]+)\]', ay).group(1)
    ours = re.search(r'(?m)^OURS: (.*)$', blk).group(1)
    m = LEAD.match(ours)
    new = None
    pm = LEAD.match(prop)
    if m and pm and m.group(1) == pm.group(1):
        kind = pm.group(2)
        kind = {'عاطفة': 'حرف عطف', 'استئنافية': 'حرف استئناف'}.get(kind, kind)
        new = m.group(1) + ' ' + kind + ours[m.end():]
        if 'جواب شرط مقدر لا محل لها' in new and kind != 'رابطة لجواب الشرط':
            new = new.replace('جواب شرط مقدر لا محل لها', 'مستأنفة لا محل لها' if 'استئناف' in kind else 'معطوفة على ما قبلها')
        if 'جواب شرط غير جازم لا محل لها' in new and kind != 'رابطة لجواب الشرط':
            new = new.replace('جواب شرط غير جازم لا محل لها', 'مستأنفة لا محل لها' if 'استئناف' in kind else 'معطوفة على ما قبلها')
        how = 'particle'
    else:
        new, how = prop, 'judge'
    s, a, _ = pid.split(':')
    out.append({'id': pid, 's': int(s), 'a': int(a), 'w': w, 'old': ours, 'new': new, 'how': how, 'why': reason})
    print(f'## {pid} {w} [{how}]\n  - {ours}\n  + {new}')
json.dump(out, open('pk2B/plan_' + sys.argv[2] + '.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(out), 'items', file=sys.stderr)
