"""For each CHANGE line: is every «quote» the judge attributes to a classical
book (SAMIN/NAHHAS/MAKKI/MUJTABA/BAHR) really inside that book's line in the
packet (diacritics, hamza seats and spacing ignored)? Prints the failures."""
import glob, re, sys
sys.stdout.reconfigure(encoding='utf-8')
DI = re.compile('[\u064B-\u0652\u0653-\u0655\u06D6-\u06ED\u0640«»"\'(),.:;،؛\s]')
def n(t):
    t = t.replace('\u0670', 'ا').replace('ء', '')
    t = t.replace('ٱ', 'ا').replace('آ', 'ا').replace('أ', 'ا').replace('إ', 'ا').replace('ى', 'ي').replace('ة', 'ه').replace('ؤ', 'و').replace('ئ', 'ي')
    return DI.sub('', t)
pk = {}
for f in glob.glob('pk2B/j*.txt'):
    for blk in re.split(r'(?m)^(?=### )', open(f, encoding='utf-8').read()):
        if blk.startswith('### '): pk[blk.split()[1]] = blk
ok = bad = 0
for line in open(sys.argv[1], encoding='utf-8'):
    p = line.split('\t')
    if len(p) < 3: continue
    pid, reason = p[0], p[2]
    blk = pk[pid]
    for m in re.finditer(r'(SAMIN|NAHHAS|MAKKI|MUJTABA|BAHR|Samin|Nahhas|Makki|Mujtaba|Bahr)\s*(?:\([^)]*\))?:\s*«([^»]+)»', reason):
        book = m.group(1).upper()
        bl = (re.search(rf'(?m)^{book}: (.*)$', blk) or [None, ''])[1]
        q = n(m.group(2).replace('...', '').replace('…', ''))
        parts = [x for x in re.split(r'\.\.\.|…', m.group(2)) if x.strip()]
        if all(n(x) in n(bl) for x in parts):
            ok += 1
        else:
            bad += 1
            print(f'{pid}\t{book}\t«{m.group(2)}»')
print('verified', ok, 'not found', bad, file=sys.stderr)
