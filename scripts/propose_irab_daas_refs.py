"""For every cross-reference the resolver could not PROVE, propose a target
for the owner to approve - never shown in the app until he does.

Proposal = the nearest earlier ayah (outside the reference's own section)
sharing the longest run of consecutive words with the book's quote; ties go
to the nearest. Only runs of 2+ words count. «سبق إعراب مثلها / ما يشبهها»
points at a pattern, not an ayah, so a proposal is a reading, not a fact.

    py -3 scripts/propose_irab_daas_refs.py
      -> scripts/temp_phase1/irab_daas_refs_proposed.json
      -> scripts/irab_daas_refs_for_owner.md   (the list he reads)
"""
import io
import json
import os
import sqlite3
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from resolve_irab_daas_refs import wskel  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')


def longest_run(q, t):
    best = 0
    for i in range(len(q)):
        for j in range(len(t)):
            k = 0
            while i + k < len(q) and j + k < len(t) and q[i + k] == t[j + k]:
                k += 1
            best = max(best, k)
    return best


def kind(o):
    if 'why' in o:
        if o['why'].startswith('points into its own'):
            return 'own'
        return 'held'
    n = len(o['quote'].split())
    return 'noquote' if n == 0 else ('oneword' if n == 1 else 'pattern')


def main():
    db = sqlite3.connect(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    ayahs = [(s, a, wskel(t).split(), t) for s, a, t in
             db.execute('select surah_id, ayah_number, text_uthmani from ayahs order by surah_id, ayah_number')]
    order = {(s, a): i for i, (s, a, _, _) in enumerate(ayahs)}
    names = dict(db.execute('select id, name_ar from surahs'))
    O = json.load(io.open(os.path.join(T, 'irab_daas_refs_open.json'), encoding='utf-8'))
    out = []
    for o in O:
        o['kind'] = kind(o)
        if o['kind'] == 'own':
            continue                       # the i'rab is on screen already
        q = wskel(o['quote']).split()
        if len(q) >= 2:
            best, arg = 1, None
            for i in range(order[(o['surah'], o['ayah_from'])] - 1, -1, -1):
                k = longest_run(q, ayahs[i][2])
                if k > best:
                    best, arg = k, i
                    if k == len(q):
                        break
            if arg is not None:
                s, a, _, text = ayahs[arg]
                o.update(proposed_surah=s, proposed_ayah=a, proposed_run=best, proposed_of=len(q),
                         proposed_text=text)
        out.append(o)
    json.dump(out, io.open(os.path.join(T, 'irab_daas_refs_proposed.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)

    c = Counter(o['kind'] for o in out)
    L = ['# إحالات الإعراب التي تحتاج رأيك', '',
         'لم يُعرض أي منها في التطبيق. كل سطر: موضع الإحالة، كلام الكتاب، ثم الاقتراح إن وُجد.', '',
         f"- «مثلها / ما يشبهها» مع اقتراح: {sum(1 for o in out if 'proposed_ayah' in o)}",
         f"- بلا اقتباس ولا رقم يحسمها: {c['noquote']}",
         f"- اقتباس كلمة واحدة: {c['oneword']}",
         f"- رقم الكتاب لا يطابق النص (مُحتجزة): {c['held']}", '']
    for o in out:
        where = f"{names[o['surah']]} {o['ayah_from']}" + (f"–{o['ayah_to']}" if o['ayah_to'] != o['ayah_from'] else '')
        line = f"- **{where}**: «{o['quote']}» {o['ref'].strip()}"
        if 'proposed_ayah' in o:
            line += (f"  \n  ← الاقتراح: {names[o['proposed_surah']]} {o['proposed_ayah']}"
                     f" ({o['proposed_run']} من {o['proposed_of']} كلمات متطابقة): {o['proposed_text']}")
        elif o.get('why'):
            line += f"  \n  ← محتجزة: {o['why']}"
        L.append(line)
    io.open(os.path.join(ROOT, 'scripts', 'irab_daas_refs_for_owner.md'), 'w', encoding='utf-8').write('\n'.join(L) + '\n')
    sys.stdout.reconfigure(encoding='utf-8')
    print(dict(c), '| with a proposal:', sum(1 for o in out if 'proposed_ayah' in o))


if __name__ == '__main__':
    main()
