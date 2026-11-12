"""Compact sheet for reading judge CHANGE proposals: per word the current
i'rab, al-Da'as's verbatim phrase, the packet's ALT line, the judge's reason
and proposal, and whether every «quote» in the reason is really in the packet
(diacritics ignored). Usage: py -3 pending_digest.py PENDING.tsv > digest.txt"""
import glob, json, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from daas_quote import quote
from write_surah import bare
DI = re.compile('[\u064B-\u0652\u0670\u0653-\u0655\u06D6-\u06ED\u0640]')
GRAM = re.compile('متعلق|خبر|مبتدا|مفعول|حال|نعت|صفه|فاعل|عطف|معطوف|بدل|مستانف|استئناف|زائد|تمييز|ظرف|توكيد|منصوب|مرفوع|مجرور|جواب|رابطه|عاطفه|اسم|منقطع|متصل')
def n(t): return re.sub(r'\s+', ' ', DI.sub('', t.replace('ٰ', 'ا').replace('ء', '').replace('ٔ', '')).replace('ٱ', 'ا').replace('آ', 'ا').replace('أ', 'ا').replace('إ', 'ا').replace('ى', 'ي').replace('ة', 'ه'))
pk = {}
for f in glob.glob(os.path.join(H, 'pk2B', 'j*.txt')):
    for blk in re.split(r'(?m)^(?=### )', open(f, encoding='utf-8').read()):
        if blk.startswith('### '): pk[blk.split()[1]] = blk
words = {}
for line in open(sys.argv[1], encoding='utf-8'):
    p = line.rstrip('\n').split('\t')
    if len(p) < 4: continue
    pid, _, reason, prop = p[:4]
    s, a, _ = pid.split(':'); s, a = int(s), int(a)
    blk = pk.get(pid, '')
    ay = (re.search(r'(?m)^AYAH: (.*)$', blk) or [None, ''])[1]
    m = re.search(r'\[([^\]]+)\]', ay)
    w = m.group(1) if m else '?'
    ours = (re.search(r'(?m)^OURS: (.*)$', blk) or [None, ''])[1]
    alt = (re.search(r'(?m)^ALT (.*)$', blk) or [None, '-'])[1]
    nb = n(blk)
    qs = re.findall('«([^»]{3,})»', reason)
    bad = [q for q in qs if n(q).strip() not in nb]
    dq = quote(s, a, bare(w)) or '(no al-Da\'as phrase found)'
    print(f'### {pid} [{w}]  tag={"AUDIT" if "[AUDIT]" in blk.split(chr(10))[0] else "CHECK"}')
    print(f'  OURS : {ours[:220]}')
    print(f'  DAAS : {dq[:220]}')
    print(f'  ALT  : {alt[:200]}')
    print(f'  WHY  : {reason[:300]}')
    print(f'  NEW  : {prop[:220]}')
    bw = n(bare(w)).replace('ال', '', 1) if bare(w).startswith('ٱل') else n(bare(w))
    bw = bw[1:] if bw[:1] in 'وف' and len(bw) > 3 else bw
    for book in ('SAMIN', 'NAHHAS', 'MAKKI', 'MUJTABA', 'BAHR'):
        t = (re.search(rf'(?m)^{book}: (.*)$', blk) or [None, ''])[1]
        if not t or t.strip() == 'silent': continue
        nt = n(t)
        for mm in re.finditer(re.escape(bw), nt):
            win = nt[max(0, mm.start() - 40): mm.start() + 110]
            if GRAM.search(win):
                print(f'  {book:7}: …{win}…')
                break
