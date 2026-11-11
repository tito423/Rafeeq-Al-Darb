"""Cuts, for every review target (samin_targets.json), what al-Samin «الدر
المصون» says about THAT word, plus the al-Jadwal and Darwish passages around
it, into one compact packet. No model involved.

A word is located in a book by its consonant skeleton (sheet.skel), also with
a leading و/ف/ب/ل/ك stripped. al-Samin's page is split at «قوله تعالى:»;
a section whose {…} heading holds the word is kept whole (capped), otherwise
windows around the first hits in the body. No hit at all -> `samin: silent`.

    py -3 samin_cut.py [group ...]   -> samin_packets.jsonl, batches/bNNN.txt
"""
import json, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from sheet import skel
from books import get

CAP = 700
WIN = 180
HARAKAT = re.compile('[ً-ٰٟۖ-ࣰۭ-ࣳ]')


def bare(t):
    return HARAKAT.sub('', t)


def keys(tok):
    k = skel(tok)
    out = {k}
    if len(k) > 2 and k[0] in 'وفبلك':
        out.add(k[1:])
    # attached pronouns: هم/هن/كم/نا/ه/ها at the end
    for suf in ('هم', 'هن', 'كم', 'نا', 'ه', 'ه', 'ك'):
        for x in list(out):
            if len(x) > len(suf) + 1 and x.endswith(suf):
                out.add(x[:-len(suf)])
    return {x for x in out if len(x) >= 2}


def hits(text, ks):
    for m in re.finditer(r'\S+', text):
        if skel(m.group()) in ks:
            yield m.start()


def windows(text, ks, n=2):
    out, last = [], -1
    for p in hits(text, ks):
        if p < last:
            continue
        a, b = max(0, p - WIN), min(len(text), p + WIN)
        out.append(text[a:b])
        last = b
        if len(out) >= n:
            break
    return ' … '.join(' '.join(x.split()) for x in out)


SIGS = ['نائب فاعل', 'فاعل', 'مبتدأ', 'خبر', 'مفعول به', 'مفعول مطلق', 'مفعول فيه', 'ظرف', 'مفعول لأجله',
        'مفعول معه', 'حال', 'تمييز', 'مضاف إليه', 'بدل', 'نعت', 'صفة', 'توكيد', 'مستثنى', 'منادى', 'ضمير فصل',
        'اسم إن', 'اسم كان', 'خبر كان', 'اسم مجرور', 'فعل ماض', 'فعل مضارع', 'فعل أمر']


def norm_role(t):
    t = bare(t).replace('«', '').replace('»', '').replace('ّ', '')
    t = re.sub('[أإآ]', 'ا', t)
    return t


def first_role(t):
    t = norm_role(re.split(r'[،.(]', t)[0])
    best = None
    for r in SIGS:
        i = t.find(norm_role(r))
        if i >= 0 and (best is None or i < best[0]):
            best = (i, r)
    return best[1] if best else None


def book_confirms(text, tok, role):
    """al-Jadwal / Darwish write «(word) role ...»: True when the role they
    name for this word right after its parenthesis is ours."""
    ks = keys(tok)
    for m in re.finditer(r'\(([^()]{1,25})\)\s*([^()]{0,70})', text or ''):
        inner = m.group(1).split()
        if len(inner) == 1 and skel(inner[0]) in ks and first_role(m.group(2)) == role:
            return m.group(0)[:90]
    return None


def samin(s, a, tok):
    t = get('aldur-almasoon', s, a) or ''
    ks = keys(tok)
    secs = re.split(r'(?=قوله تعالى)', t)
    for sec in secs:
        h = re.match(r'قوله تعالى:?\s*\{([^}]*)\}', sec)
        if h and any(skel(w) in ks for w in h.group(1).split()):
            sec = ' '.join(sec.split())
            return sec[:CAP] + ('…' if len(sec) > CAP else '')
    w = windows(t, ks, 3)
    if w:
        return w
    t = ' '.join(t.split())
    if not t:
        return ''
    # al-Samin often names the word by its class («والموصول ...»), not its letters
    return '(no direct quote; page start) ' + t[:500] + ('…' if len(t) > 500 else '')


def main():
    groups = set(sys.argv[1:]) or {'fuller', 'repeat', 'role'}
    tg = [t for t in json.load(open(os.path.join(H, 'samin_targets.json'), encoding='utf-8')) if t['group'] in groups]
    files = {}
    OUT = 'pkr' if groups == {'role'} else 'pk'
    packets, silent, auto = [], 0, []
    for t in tg:
        s, a = t['s'], t['a']
        if s not in files:
            files[s] = json.load(open(os.path.join(H, f'{s:03d}.json'), encoding='utf-8'))['words']
        w = files[s][t['i']]
        idx = [j for j, x in enumerate(files[s]) if x['a'] == a]
        lo = max(idx[0], t['i'] - 6); hi = min(idx[-1], t['i'] + 6)
        ayah = ('… ' if lo > idx[0] else '') + ' '.join(
            ('[' + files[s][j]['w'] + ']') if j == t['i'] else bare(files[s][j]['w'])
            for j in range(lo, hi + 1)) + (' …' if hi < idx[-1] else '')
        if t['group'] == 'role':
            # priority: ours parted from al-Da'as, or both other books part from ours
            from samin_targets import kind
            bs = {x['book'] for x in w['alts'] if kind(x['text']) == 'role'}
            if not ('daas' in bs or {'jadwal', 'darwish'} <= bs):
                continue
        ks = keys(w['w'])
        role = first_role(w['irab'])
        if t['group'] != 'repeat' and role:
            ev = book_confirms(get('aljadwal', s, a), w['w'], role) or book_confirms(get('iraab-aldarweesh', s, a), w['w'], role)
            if ev:
                auto.append(f"{s}:{a}:{t['i']}	OURS_OK	auto: «{' '.join(bare(ev).split())}»")
                continue
        sm = samin(s, a, w['w'])
        if not sm:
            silent += 1
            if t['group'] == 'role':
                continue  # khilaf already shown, al-Samin adds nothing
        p = {'id': f"{s}:{a}:{t['i']}", 'group': t['group'], 'word': w['w'], 'ayah': ayah,
             'ours': w['irab'], 'alts': [f"{x['book']}: {x['text']}" for x in w.get('alts', [])],
             'samin': bare(sm) if sm else 'silent',
             'jadwal': bare(windows(get('aljadwal', s, a) or '', ks, 1)),
             'darwish': bare(windows(get('iraab-aldarweesh', s, a) or '', ks, 1))}
        packets.append(p)
    os.makedirs(os.path.join(H, OUT), exist_ok=True)
    open(os.path.join(H, OUT, 'auto_ok.tsv'), 'w', encoding='utf-8').write(''.join(x + chr(10) for x in auto))
    print(len(auto), 'auto-confirmed by al-Jadwal/Darwish')
    with open(os.path.join(H, 'samin_packets.jsonl'), 'w', encoding='utf-8') as f:
        for p in packets:
            f.write(json.dumps(p, ensure_ascii=False) + '\n')
    os.makedirs(os.path.join(H, OUT), exist_ok=True)
    B = 30
    for n in range(0, len(packets), B):
        with open(os.path.join(H, OUT, f'b{n // B:03d}.txt'), 'w', encoding='utf-8') as f:
            for p in packets[n:n + B]:
                f.write(f"### {p['id']} ({p['group']})\nAYAH: {p['ayah']}\nOURS: {p['ours']}\n")
                for x in p['alts']:
                    f.write(f'ALT {x}\n')
                f.write(f"SAMIN: {p['samin']}\nJADWAL: {p['jadwal'] or '-'}\nDARWISH: {p['darwish'] or '-'}\n\n")
    size = sum(os.path.getsize(os.path.join(H, OUT, x)) for x in os.listdir(os.path.join(H, OUT)))
    print(len(packets), 'packets;', silent, 'silent in al-Samin;', (len(packets) + B - 1) // B, 'batches;', size, 'bytes')


if __name__ == '__main__':
    main()
