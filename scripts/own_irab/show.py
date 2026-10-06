"""Prints, for one surah, each ayah's mushaf words (numbered) and al-Da'as's
section that covers it (a section may span several ayahs - shown once), and,
when NNN.json exists, our entry under each word with its check value - the
sheet the word-by-word comparison is done from.
    py -3 scripts/own_irab/show.py <surah> [first_ayah last_ayah]"""
import io, json, os, sqlite3, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, '..', '..', 'rafeeq_app', 'assets', 'data')
s = int(sys.argv[1])
a0, a1 = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1, 999)
q = sqlite3.connect(os.path.join(DATA, 'quran_local.db'))
d = sqlite3.connect(os.path.join(DATA, 'quran_sciences.db'))
mine = {}
f = os.path.join(HERE, f'{s:03d}.json')
if os.path.exists(f):
    for i, w in enumerate(json.load(open(f, encoding='utf-8'))['words']):
        mine.setdefault(w['a'], []).append(w)
shown = set()
for a, txt in q.execute('select ayah_number, text_uthmani from ayahs where surah_id=? and ayah_number between ? and ? order by ayah_number', (s, a0, a1)):
    toks = [t for t in txt.split() if any('ء' <= c <= 'ي' for c in t)]
    print(f'\n== {s}:{a}  ' + ' '.join(f'[{i+1}]{t}' for i, t in enumerate(toks)))
    for rid, fa, ta, text in d.execute('select rowid, ayah_from, ayah_to, text from irab_daas where surah=? and ayah_from<=? and ayah_to>=?', (s, a, a)):
        if rid in shown:
            print(f'   DAAS: (section {fa}-{ta}, printed above)')
            continue
        shown.add(rid)
        print(f'   DAAS {fa}-{ta}: ' + ' '.join(text.split()))
    for i, w in enumerate(mine.get(a, [])):
        print(f'   OURS [{i+1}] {w["w"]} ({w["check"]}): {w["irab"]}')
