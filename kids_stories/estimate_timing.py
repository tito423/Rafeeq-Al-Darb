"""ESTIMATED timing.json for a story that has no narration recorded yet.

Lets the visuals be built and checked before the voice exists. Every entry is
marked "estimated": true; once the narration is voiced, timing.json and
words.json are regenerated from the real audio and this file is overwritten.

The rates were measured on 2026-10-01 from the six voiced stories (salih, hud,
musa, sulayman, yunus, ibrahim): 68 narrator lines fit seconds = 2.06 + 0.551 *
words; five Minshawi recitations averaged 1.35 s per word (11:64 2.03,
46:24 1.15, 26:63 1.24, 27:19 1.44, 21:87 1.26), plus 3 s of lead-in/out.

    python estimate_timing.py ayyub   (reads docs/kids_stories/ayyub_narration.md)

The Qur'an text for word counts: rafeeq_app/assets/data/quran_local.db, or
--hafs <hafsData_v18.json> where the DB is not present (a cloud session).
"""
import json, re, sqlite3, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
story = sys.argv[1]
doc = ROOT / 'docs' / 'kids_stories' / f'{story}_narration.md'


def quran():
    if '--hafs' in sys.argv:
        p = sys.argv[sys.argv.index('--hafs') + 1]
        return {(r['sora'], r['aya_no']): r['aya_text'] for r in json.load(open(p, encoding='utf-8'))}
    db = ROOT / 'rafeeq_app' / 'assets' / 'data' / 'quran_local.db'
    con = sqlite3.connect(db)
    return {(s, a): t for s, a, t in con.execute('select surah_id, ayah_number, text_uthmani from ayahs')}


Q = quran()
words = lambda t: len([w for w in t.split() if re.search('[ء-ي]', w)])
out = []
for line in doc.read_text(encoding='utf-8').splitlines():
    m = re.match(r'\| (\d+) \| (.*?) \|', line)
    if not m:
        continue
    n, text = int(m.group(1)), m.group(2)
    if '**تلاوة**' in text:
        refs = re.findall(r'(\d+):(\d+)(?:-(\d+))?', text)
        s, a, b = refs[0]
        ayat = range(int(a), int(b or a) + 1)
        sec = 3 + 1.35 * sum(words(Q[(int(s), x)]) for x in ayat)
    else:
        sec = 2.06 + 0.551 * len(text.split())
    out.append({'scene': n, 'seconds': round(sec, 2), 'estimated': True})
if [e['scene'] for e in out] != list(range(1, len(out) + 1)):
    sys.exit('scene numbers are not 1..n')
(HERE / story).mkdir(exist_ok=True)
(HERE / story / 'timing.json').write_text(json.dumps(out, indent=1), encoding='utf-8')
print(story, len(out), 'scenes', round(sum(e['seconds'] for e in out), 1), 's (ESTIMATED)')
