# Dump the verses and al-Muyassar for a story's ranges to <out>.txt
#   py -3 verses.py out.txt 26:52-67 20:77-79
import sqlite3, sys
Q = sqlite3.connect(r'E:/My Projects/Rafiq-Al-Darb/rafeeq_app/assets/data/quran_local.db')
S = sqlite3.connect(r'E:/My Projects/Rafiq-Al-Darb/rafeeq_app/assets/data/quran_sciences.db')
o = open(sys.argv[1], 'w', encoding='utf-8')
for r in sys.argv[2:]:
    s, ab = r.split(':'); a, b = (ab.split('-') + [ab])[:2]; s, a, b = int(s), int(a), int(b)
    for n, t in Q.execute('select ayah_number,text_uthmani from ayahs where surah_id=? and ayah_number between ? and ?', (s, a, b)):
        o.write(f'{s}:{n} {t}\n')
    for x, y, t in S.execute("select ayah_start,ayah_end,text from tafseer_texts where source='muyassar' and surah=? and ayah_end>=? and ayah_start<=? order by ayah_start", (s, a, b)):
        o.write(f'  [M {s}:{x}-{y}] {t}\n')
    o.write('\n')
