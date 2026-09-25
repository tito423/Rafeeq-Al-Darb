"""Check every quoted Qur'an word in al-Da'as's i'rab against the mushaf.

Owner (2026-09-26): a word of the Qur'an that differs from the mushaf is
checked on the Madinah page by eye, corrected, and the correction recorded
with its reference. This finds the candidates: each «…» quote of a section
must occur, word for word (consonant skeleton), in that section's ayahs
(KFGQPC text). A quote that does not is listed with its mushaf page.

The book also quotes words that are NOT the ayah on purpose (a grammar term,
«إلخ», a word from an earlier ayah it compares), so a listed quote is a
candidate to read, not an error.

    py -3 scripts/check_irab_daas_quotes.py  -> scripts/temp_phase1/irab_daas_quote_mismatch.json
"""
import io
import json
import os
import re
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from resolve_irab_daas_refs import wskel, skel  # noqa: E402


def loose(t):
    """The rasm without spaces, with doubled lam collapsed: the book writes
    standard spelling («الليل», «أولئك», «فو ربّ»), the mushaf Uthmani
    («ٱلَّيۡلَ», «أُوْلَٰٓئِكَ», «فَوَرَبِّ»). Differences only of that kind
    are spelling, not wording."""
    return re.sub('ل+', 'ل', skel(t))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')


def main():
    db = sqlite3.connect(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    ay = {(s, a): (wskel(t), p, loose(t)) for s, a, t, p in
          db.execute('select surah_id, ayah_number, text_clean, page_number from ayahs')}
    F = json.load(io.open(os.path.join(T, 'irab_daas_final.json'), encoding='utf-8'))
    out, n = [], 0
    for r in F:
        s, a0, a1 = r['surah'], r['ayah_from'], r['ayah_to']
        body = ' '.join(ay[(s, k)][0] for k in range(a0, a1 + 1))
        for q in re.findall(r'«([^«»]+)»', r['text']):
            if re.search(r'[\d٠-٩]', q):
                continue                          # «٢٣» - an ayah number
            n += 1
            w = wskel(q)
            if not w.strip() or w in body:
                continue
            # one-word quotes: also accept the word inside a longer word
            if len(w.split()) == 1 and w.strip() in body:
                continue
            if loose(q) and loose(q) in ''.join(ay[(s, k)][2] for k in range(a0, a1 + 1)):
                continue
            out.append({'surah': s, 'ayah_from': a0, 'ayah_to': a1, 'quote': q,
                        'pages': sorted({ay[(s, k)][1] for k in range(a0, a1 + 1)})})
    json.dump(out, io.open(os.path.join(T, 'irab_daas_quote_mismatch.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    sys.stdout.reconfigure(encoding='utf-8')
    print(f'quotes checked: {n} | not found in their ayahs: {len(out)}')


if __name__ == '__main__':
    main()
