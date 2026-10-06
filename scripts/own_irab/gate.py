"""Quality gate for gen_masaq.py: the generated i'rab against the words we
checked by hand (NNN.json in this folder). Only words the app would SHOW as
ours (check agree/fuller) count; a mismatch in role, case or sign, or a
clause the hand file does not have (a hidden subject on a particle), is
printed for reading.

    py -3 scripts/own_irab/gate.py [-v]
"""
import io, json, os, re, sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_masaq as G

H = os.path.dirname(os.path.abspath(__file__))
ROLES = ['نائب فاعل', 'فاعل', 'مفعول به', 'مفعول مطلق', 'مفعول لأجله', 'مفعول فيه', 'مفعول معه', 'مضاف إليه',
         'مبتدأ', 'خبر', 'نعت', 'صفة', 'حال', 'بدل', 'تمييز', 'ظرف', 'منادى', 'توكيد', 'مستثنى', 'معطوف',
         'اسم مجرور', 'فعل ماض', 'فعل مضارع', 'فعل أمر', 'حرف']
CASES = ['مرفوع', 'منصوب', 'مجرور', 'مجزوم', 'مبني']


def head(t):
    """The word's own clause: up to the first «، و» that opens a second
    segment or a sentence note."""
    t = re.split(r'، (?:و(?:الجملة|جملة|الفاعل|نائب|شبه|الجار|المصدر))', t)[0]
    return t


def feats(t):
    h = head(t)
    h2 = re.sub(r'في محل (?:رفع|نصب|جر) ', 'في محل ', h)
    role = min(((h2.find(k), k) for k in ROLES if k in h2), default=(0, None))[1]
    if role == 'صفة':
        role = 'نعت'
    case = min(((h.find(k), k) for k in CASES if k in h), default=(0, None))[1]
    place = re.search(r'في محل (رفع|نصب|جر)', h)
    sign = re.search(r'علامة \S+ ([^\s،.]+)', h)
    if role == 'حرف' or (role and h.startswith(('الواو', 'الفاء', 'السين', 'اللام', 'الهمزة', 'الباء'))):
        # «الواو حرف عطف (مبني على الفتح)، و«X» …»: compare X's own role/case
        rest = re.split(r'، و«[^»]+» ', h, maxsplit=1)
        if len(rest) == 2 and role == 'حرف':
            return feats(rest[1])
        case = None
    return role, case, place and place.group(1), sign and sign.group(1), \
        'مستتر' in t


def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    verbose = '-v' in sys.argv
    tot, bad = Counter(), Counter()
    for f in sorted(os.listdir(H)):
        if not re.fullmatch(r'\d{3}\.json', f):
            continue
        s = int(f[:3])
        hand = json.load(open(os.path.join(H, f), encoding='utf-8'))['words']
        gen = G.gen(s)
        if len(gen) != len(hand):
            print(f'{s}: word count {len(gen)} vs hand {len(hand)} - not compared')
            continue
        for g, h in zip(gen, hand):
            tot[g['check']] += 1
            if g['check'] == 'differ':
                continue
            fg, fh = feats(g['irab']), feats(h['irab'])
            why = [n for n, x, y in zip(('role', 'case', 'place', 'sign', 'hidden'), fg, fh) if x != y]
            if why:
                bad[g['check']] += 1
                for n in why:
                    bad[n] += 1
                if verbose:
                    print(f"{s}:{g['a']} {g['w']} [{g['check']}] {','.join(why)}\n   GEN : {g['irab']}\n   HAND: {h['irab']}")
    shown = tot['agree'] + tot['fuller']
    print('words', sum(tot.values()), dict(tot))
    print(f"shown {shown}, mismatching hand {bad['agree'] + bad['fuller']} "
          f"(agree {bad['agree']}, fuller {bad['fuller']}); by feature "
          + ', '.join(f'{k} {bad[k]}' for k in ('role', 'case', 'place', 'sign', 'hidden')))


if __name__ == '__main__':
    main()
