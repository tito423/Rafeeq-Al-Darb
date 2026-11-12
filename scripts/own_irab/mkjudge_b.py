import glob, os, random, re, sys
sys.stdout.reconfigure(encoding='utf-8')
P = r'E:\My Projects\Rafiq-Al-Darb\scripts\own_irab\pk2B'
first, last = int(sys.argv[1]), int(sys.argv[2])
start_idx = int(sys.argv[3])  # first judge file index
verd = {}
for i in range(first, last + 1):
    n = 'b%03d' % i
    for l in open(f'{P}/out_{n}.tsv', encoding='utf-8').read().splitlines():
        p = l.split('\t')
        if len(p) >= 2:
            verd[p[0].strip()] = (p[1].strip(), n)
pk = {}
for i in range(first, last + 1):
    t = open(f'{P}/b%03d.txt' % i, encoding='utf-8').read()
    for blk in re.split(r'(?m)^(?=### )', t):
        if blk.startswith('### '):
            pk[blk.split('\n', 1)[0][4:].strip()] = blk
flag = [k for k, (v, _) in verd.items() if v in ('OURS_WRONG', 'UNCLEAR')]
ok = sorted(k for k, (v, _) in verd.items() if v == 'OURS_OK')
random.Random(first * 100 + last).shuffle(ok)
aud = ok[:int(sys.argv[4])]
print('flag', len(flag), 'ok', len(ok), 'audit', len(aud), 'missing', [k for k in verd if k not in pk][:5])
items = [(k, 'CHECK', verd[k][0]) for k in flag] + [(k, 'AUDIT', 'OURS_OK') for k in aud]
for j in range(0, len(items), 30):
    out = []
    for k, tag, v in items[j:j + 30]:
        b = pk[k].split('\n', 1)
        out.append(f'### {k} [{tag}] classifier said: {v}\n' + b[1])
    fn = f'{P}/j{start_idx + j // 30}.txt'
    open(fn, 'w', encoding='utf-8').write('\n'.join(out))
    print(fn, len(items[j:j + 30]))
