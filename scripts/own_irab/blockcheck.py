"""Checks a block of entries for ayahs A..B of surah S before it is joined
to fill_SSS.py: under each « # N» line there must be exactly as many entries
as ayah N has mushaf tokens, every entry must expand (irab_dsl.x: unknown
codes and wrong slot counts fail), an alt must name daas / jadwal / darwish
with the book's text, and a check value must be a known one.
    py -3 scripts/own_irab/blockcheck.py 4 1 12 block.txt [--show]
--show prints every word with its expanded wording, for reading back."""
import collections, io, os, re, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from irab_dsl import x
from write_surah import tokens

IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


def load(s, a0, a1, path):
    src = '\n' + open(path, encoding='utf-8').read()
    parts = re.split(r'\n # (\d+)[^\n]*\n', src)
    assert not parts[0].strip(), 'text before the first « # N» line'
    toks = tokens(s)
    need = collections.Counter(a for a, _ in toks)
    errs, out, seen = [], [], []
    for i in range(1, len(parts), 2):
        a = int(parts[i]); seen.append(a)
        try:
            es = eval('[' + parts[i + 1] + ']', {'alt': alt, 'IDHA': IDHA})
        except Exception as e:
            errs.append(f'ayah {a}: does not parse: {e}'); continue
        if len(es) != need[a]:
            errs.append(f'ayah {a}: {len(es)} entries, the mushaf has {need[a]} words')
        ws = [w for x_, w in toks if x_ == a]
        for k, e in enumerate(es):
            w = ws[k] if k < len(ws) else '?'
            try:
                if isinstance(e, dict):
                    assert e['alts'] and all(b['book'] in ('daas', 'jadwal', 'darwish') and b['text'].strip() for b in e['alts']), 'alt needs daas/jadwal/darwish and its text'
                    t, c = e['text'], 'alt'
                elif isinstance(e, tuple):
                    t, c = e
                    assert c in ('agree', 'fuller'), f'check {c!r}'
                else:
                    t, c = e, 'agree'
                assert isinstance(t, str) and t.strip(), 'empty entry'
                assert '،' not in t and '.' not in t.rstrip('.'), 'clauses are separated by ASCII commas, no Arabic comma or stop inside'
                out.append((a, k + 1, w, x(t), c, e))
            except Exception as ex:
                errs.append(f'ayah {a} word {k + 1} {w}: {ex}')
    if seen != list(range(a0, a1 + 1)):
        errs.append(f'ayahs in the block {seen[:3]}..{seen[-3:]} are not exactly {a0}..{a1} in order')
    return out, errs


if __name__ == '__main__':
    s, a0, a1 = map(int, sys.argv[1:4])
    out, errs = load(s, a0, a1, sys.argv[4])
    if '--show' in sys.argv:
        for a, k, w, t, c, e in out:
            extra = ''.join(f'  ||{b["book"]}: {b["text"]}' for b in e['alts']) if isinstance(e, dict) else ('' if c == 'agree' else f'  [{c}]')
            print(f'{a}[{k}] {w}: {t}{extra}')
    n = collections.Counter(c for *_, c, _ in out)
    print('words', len(out), dict(n))
    for e in errs:
        print('ERROR', e)
    print('OK' if not errs else f'{len(errs)} ERRORS')
    sys.exit(1 if errs else 0)
