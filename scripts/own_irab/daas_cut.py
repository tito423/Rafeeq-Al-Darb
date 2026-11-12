"""For every word in write_surah.GROUPB, prints al-Da'as's own phrase on it
(quran_sciences.db irab_daas): from the «quote» that contains the word to the
next «. Used to check that the alt kept under the word is al-Da'as's text."""
import json, os, re, sqlite3, sys
sys.stdout.reconfigure(encoding='utf-8')
from write_surah import GROUPB, H, bare
d = sqlite3.connect(os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data', 'quran_sciences.db'))
DI = re.compile('[\u064B-\u0652\u0670\u0653-\u0655\u06D6-\u06ED]')
def b(t):
    return DI.sub('', t).replace('ٱ', 'ا').replace('آ', 'ا').replace('أ', 'ا').replace('إ', 'ا')
out = {}
for (s, a, w), reps in sorted(GROUPB.items()):
    secs = [t for (t,) in d.execute('select text from irab_daas where surah=? and ayah_from<=? and ayah_to>=?', (s, a, a))]
    text = ' '.join(' '.join(x.split()) for x in secs)
    bw = b(w)
    hits = []
    for m in re.finditer('«([^»]*)»', text):
        q = b(m.group(1)).replace(' ', '')
        if bw in q or q in bw and len(q) >= 2:
            end = text.find('«', m.end())
            hits.append(text[m.start(): end if end > 0 else m.end() + 300][:400])
    print(f'== {s}:{a} {w}\n   ' + '\n   '.join(hits or ['(no quote found)']))
