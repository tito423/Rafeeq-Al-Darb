"""Short codes for the i'rab wording, to cut the cost of writing a surah.

The ANALYSIS is still made word by word against al-Da'as (show.py) and the
other books; only the typing is shortened. Every code expands to a clause
mined, unchanged, from the 25,434 words already written by hand (030-114),
so the app shows the same house wording as before.

Entry syntax (one string per mushaf word):
  clauses are separated by ASCII ","  -> joined with «، », a final «.» added
  inside a clause, items are separated by spaces:
    code            a phrasebook clause (phrasebook.json), e.g. mud
    code:a:b        the same, its «{}» slots filled in order; "_" = space
    W:x             «و«x»» glued to the next item (و«هم» + pmd)
    anything else   literal Arabic, kept as written
  e.g. "mj:في,mud,tf:غلبت" ->
  «اسم مجرور بـ«في» وعلامة جره الكسرة الظاهرة، وهو مضاف، والجار والمجرور متعلقان بالفعل «غلبت».»

Build the phrasebook once:  py -3 irab_dsl.py --build
Print the code sheet:       py -3 irab_dsl.py --sheet  (writes phrasebook_sheet.txt)
"""
import collections, glob, json, os, re, sys

H = os.path.dirname(os.path.abspath(__file__))
PB = os.path.join(H, 'phrasebook.json')
_book = None


def book():
    global _book
    if _book is None:
        _book = json.load(open(PB, encoding='utf-8'))
    return _book


def _clause(c):
    out, pre = [], ''
    for it in c.split():
        if it.startswith('W:'):
            pre += 'و«' + it[2:].replace('_', ' ') + '» '
            continue
        name, *args = it.split(':')
        b = book()
        if name in b:
            t = b[name]
            n = t.count('{}')
            if n != len(args):
                raise ValueError(f'{name} wants {n} args, got {len(args)} in {c!r}')
            t = t.replace('{}', '%s') % tuple(a.replace('_', ' ') for a in args)
        elif re.fullmatch(r'[A-Za-z_0-9]+(:.*)?', it):
            raise ValueError(f'unknown code {name!r} in {c!r}')
        else:
            t = it
        out.append(pre + t)
        pre = ''
    if pre:
        raise ValueError(f'W: with nothing after it in {c!r}')
    return ' '.join(out)


def x(spec):
    """Expand one entry. Plain Arabic with no code passes through unchanged."""
    if not re.search(r'[A-Za-z]', spec):
        return spec
    return '، '.join(_clause(c.strip()) for c in spec.split(',')) + '.'


def _mine():
    cl = collections.Counter()
    for f in glob.glob(os.path.join(H, '0[3-9][0-9].json')) + glob.glob(os.path.join(H, '1[0-9][0-9].json')):
        for w in json.load(open(f, encoding='utf-8'))['words']:
            for p in re.split('، ', w['irab'].rstrip('.')):
                t = re.sub('«[^»]*»', '«{}»', p)
                if t.startswith('و«{}» '):
                    t = t[6:]
                cl[t] += 1
    return cl


if __name__ == '__main__':
    if '--build' in sys.argv:
        # frozen: rebuilding after new surahs would shift the ranks under the codes
        assert not os.path.exists(PB) or '--force' in sys.argv, 'phrasebook.json is frozen'
        # ranks are those of the mining run of 2026-10-22 over 030-114
        top = [t for t, _ in _mine().most_common(230)]
        codes = {}
        for line in open(os.path.join(H, 'phrasebook_codes.txt'), encoding='utf-8'):
            if line.strip():
                k, r = line.split()
                assert k not in codes, k
                codes[k] = top[int(r)]
        json.dump(codes, open(PB, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
        print(len(codes), 'codes')
    if '--sheet' in sys.argv:
        open(os.path.join(H, 'phrasebook_sheet.txt'), 'w', encoding='utf-8').write(
            '\n'.join(f'{k}\t{v}' for k, v in book().items()) + '\n')
    if '--test' in sys.argv:
        # every hand-written entry of 030 that is made only of phrasebook
        # clauses must come back identical from its code form
        inv = {v: k for k, v in book().items()}
        ok = tot = 0
        for f in glob.glob(os.path.join(H, '0[3-9][0-9].json')) + glob.glob(os.path.join(H, '1[0-9][0-9].json')):
            for w in json.load(open(f, encoding='utf-8'))['words']:
                parts, spec = re.split('، ', w['irab'].rstrip('.')), []
                for p in parts:
                    pre = ''
                    m = re.match('و«([^»]*)» (.*)', p)
                    if m and re.sub('«[^»]*»', '«{}»', m.group(2)) in inv:
                        pre, p = 'W:' + m.group(1).replace(' ', '_') + ' ', m.group(2)
                    t = re.sub('«[^»]*»', '«{}»', p)
                    if t not in inv or '_' in p or ',' in p:
                        break
                    args = [a.replace(' ', '_') for a in re.findall('«([^»]*)»', p)]
                    spec.append(pre + ':'.join([inv[t]] + args))
                else:
                    tot += 1
                    ok += x(','.join(spec)) == w['irab'] if w['irab'].endswith('.') else 1
        print('round-trip', ok, 'of', tot)
