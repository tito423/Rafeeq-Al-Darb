"""Build the final text of al-Da'as's i'rab, one row per book section.

Inputs (all produced and checked earlier, see TASK_FOLLOWUP 2026-09-25):
  A  temp_phase1/irab_daas.json          Shamela 23584, the book's own sections
  B  shamela_raw/irab_daas_equran.jsonl  e-quran.com `eerab` (KSU copy), per ayah
  temp_phase1/irab_daas_arbitration.json every A/B difference judged by the print
  irab_daas_verdicts.json                what the print said where the OCR could not

Rules, each one established against the printed pages:
  * A section with no difference won by B is Shamela's text as it is, with two
    FORMATTING repairs only: a line broken right after a quoted word is joined
    (768 such breaks, all in Shamela's damaged stretches; the print runs on),
    and Shamela's own structure lines («[الجزء الثاني]», «[تتمة سورة التوبة]»)
    are dropped - they are not the book's words.
  * A section where the print sided with B somewhere is a section Shamela
    damaged (dropped first letters, glued words). There B is the base, and
    every place the print sided with A gets A's words back. B's quotation
    marks ( ) become « » and its one-item-per-line layout becomes a paragraph,
    so every section reads the same.
  * Where both copies are wrong, the printed word is used (16:33 «يَنْظُرُونَ»).
  * The book's sections are kept: B's per-ayah split puts text under the wrong
    ayah in places (55:19 under 55:20, 69:2 under 69:1).

    py -3 scripts/build_irab_daas_final.py  -> scripts/temp_phase1/irab_daas_final.json
"""
import collections
import difflib
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arbitrate_irab_daas import MARKS, FOLD  # noqa: E402
from diff_irab_daas import b_body  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
# KSU's own notes inside its copy («لا يوجد إعراب لهذه الآية في كتاب مشكل
# إعراب القرآن للدعاس», «تقدم إعرابها» repeated): folded forms.
STRUCTURE = re.compile(r'^الجزء \S+ تتمه سوره ')
FORCE_SHAMELA = {(55, 20)}
KSU_NOTE = re.compile(r'لا يوجد|يوجد اعراب|مشكل اعراب|تقدم اعرابها تقدم')


def tokens(t):
    """(start, end, folded) for every word, exactly as `words(t, fold=True)`
    splits it (checked equal on all 7,278 texts)."""
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if 'ء' <= c <= 'ي' or MARKS.match(c):
            j, has = i, False
            while j < n and ('ء' <= t[j] <= 'ي' or MARKS.match(t[j])):
                has = has or 'ء' <= t[j] <= 'ي'
                j += 1
            if has:
                out.append((i, j, MARKS.sub('', t[i:j]).translate(FOLD)))
            i = j
        else:
            i += 1
    return out


def clean_b_page(body):
    """A B page body without the tail of the ayah it opens with (a multi-line
    ayah leaves its later lines, ending in ')', after b_body drops the first)."""
    lines = body.split('\n')
    if lines and not lines[0].startswith('('):
        for k, l in enumerate(lines):
            if l.rstrip().endswith(')') and '(' not in l:
                lines = lines[k + 1:]
                break
    return '\n'.join(lines)


def b_to_paragraph(t):
    t = re.sub(r'\(([^()\n]*)\)', r'«\1»', t)
    return re.sub(r'\s*\n\s*', ' ', t).strip()


def a_format(t):
    t = '\n'.join(l for l in t.split('\n') if not re.match(r'^\s*\[.*\]\s*$', l))
    return re.sub(r'»\n(?=[^«\n])', '» ', t).strip()


def main():
    A = json.load(io.open(os.path.join(T, 'irab_daas.json'), encoding='utf-8'))
    pages = {}
    for l in io.open(os.path.join(ROOT, 'scripts', 'shamela_raw', 'irab_daas_equran.jsonl'),
                     encoding='utf-8'):
        d = json.loads(l)
        pages[(d['s'], d['a'])] = b_body(d['html'])
    arb = {(o['surah'], o['from']): o for o in
           json.load(io.open(os.path.join(T, 'irab_daas_arbitration.json'), encoding='utf-8'))}
    ver = collections.defaultdict(list)
    for d in json.load(io.open(os.path.join(ROOT, 'scripts', 'irab_daas_verdicts.json'),
                               encoding='utf-8')):
        if d['kind'] == 'op':
            ver[(d['surah'], d['from'])].append(d)

    out, stats, unresolved = [], collections.Counter(), []
    for r in A:
        key = (r['surah'], r['from'])
        a = r['text']
        b = '\n'.join(clean_b_page(pages[(r['surah'], x)] or '')
                      for x in range(r['from'], r['to'] + 1))
        judged = collections.defaultdict(list)
        for x in arb[key]['ops']:
            judged[(x['a'], x['b'])].append(x['v'])
        for d in ver[key]:
            judged[(d['a'], d['b'])] = [d['v']] + judged.get((d['a'], d['b']), [])
        ta, tb = tokens(a), tokens(b)
        wa, wb = [x[2] for x in ta], [x[2] for x in tb]
        ops = []
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, wa, wb, autojunk=False).get_opcodes():
            if tag == 'equal':
                continue
            sa, sb = ' '.join(wa[i1:i2]), ' '.join(wb[j1:j2])
            if sa and sa.replace(' ', '') == sb.replace(' ', ''):
                continue                                  # spacing only
            vs = judged.get((sa, sb)) or ['A' if not sb else None]
            v = vs[0]
            # Shamela's structure lines «[الجزء الثاني] [تتمة سورة التوبة]»
            # are missing from B, so B "won" there; they are dropped by
            # a_format anyway and must not turn the section over to B.
            if STRUCTURE.match(sa) and not sb:
                v = 'STRIP'
            # Seen on the page: B put 55:19's i'rab under 55:20, and the print
            # of 55:19 on the same page made it look right.
            if key in FORCE_SHAMELA:
                v = 'A'
            if v in ('?', None):
                # A difference the arbitration did not see: B's ayah prefix
                # now removed shifts nothing but may split an op differently.
                v = 'A' if not sb else None
            if v is None:
                unresolved.append((key, sa, sb))
                # Decided below, once the section's base is known: in a
                # Shamela-based section B's reading is simply not used; in a
                # KSU-based one (Shamela damaged there) B's reading stays,
                # unless it is KSU's own note, which is never the book's.
                v = 'UNSEEN_KSU_NOTE' if KSU_NOTE.search(sb) else 'UNSEEN'
            ops.append((v, i1, i2, j1, j2))
        b_wins = any(v == 'B' or str(v).startswith('PRINT') or v == 'SECTION_B' for v, *_ in ops)
        if not b_wins:
            text, base = a_format(a), 'shamela'
        else:
            base = 'ksu+print'
            text = b
            sb_of = lambda j1, j2: ' '.join(wb[j1:j2])  # noqa: E731
            for v, i1, i2, j1, j2 in sorted(ops, key=lambda o: -o[3]):
                if v in ('A', 'OK', 'STRIP', 'PARSER', 'UNSEEN_KSU_NOTE') or (v == 'UNSEEN' and not sb_of(j1, j2)):
                    # A's words back into B at B's position.
                    s = tb[j1][0] if j1 < len(tb) else len(text)
                    e = tb[j2 - 1][1] if j2 > j1 else s
                    rep = a[ta[i1][0]:ta[i2 - 1][1]] if i2 > i1 else ''
                    rep = rep.replace('«', '(').replace('»', ')')
                    text = text[:s] + (' ' + rep + ' ' if j2 == j1 and rep else rep) + text[e:]
                elif str(v).startswith('PRINT:'):
                    s, e = tb[j1][0], tb[j2 - 1][1]
                    text = text[:s] + v.split(':', 1)[1] + text[e:]
                    stats['print_word'] += 1
            text = b_to_paragraph(text)
        stats[base] += 1
        out.append({'surah': r['surah'], 'ayah_from': r['from'], 'ayah_to': r['to'],
                    'text': text, 'base': base})
    json.dump(out, io.open(os.path.join(T, 'irab_daas_final.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=0)
    sys.stdout.reconfigure(encoding='utf-8')
    print(dict(stats))
    print(f'unresolved differences: {len(unresolved)}')
    for u in unresolved[:30]:
        print('  ', u)


if __name__ == '__main__':
    main()
