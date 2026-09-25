"""Replace quran_local.db's ayah text with the King Fahd Complex (KFGQPC) text.

Why (2026-09-25): the bundled text was Tanzil Uthmani 1.0.x, byte-identical to
api.alquran.cloud's `quran-uthmani`. Measured against the Complex's own text:

  * 6,643 legacy "tanween + small meem" pairs (U+06E2 / U+06ED) that the app's
    Amiri Quran font draws as a literal iqlab meem - the owner saw one under
    «عَدْنٍ» in al-Kahf 18:31, where the rule is ikhfa, not iqlab.
  * 5 real text differences: 12:39 and 12:41 «يَٰصَىٰحِبَىِ» (an extra ى that
    the Madinah mushaf does not have: «يَٰصَٰحِبَيِ»), and 2:181, 8:6, 13:37
    «بَعْدَمَا» joined where the mushaf writes «بَعۡدَ مَا».

The Complex's text (hafsData v18) is the text of the Madinah printing and is
drawn with the Complex's own font, KFGQPC HAFS Uthmanic Script v0.18, whose
embedded licence grants free Use, Copy, Distribute (no sale, no modification).

Two independent copies are fetched and must agree on every one of the 6,236
ayahs before anything is written; the script refuses otherwise:
  1. hafsData_v18.json from a pinned commit of a public mirror of the
     Complex's developer package;
  2. quran.com's `qpc_hafs` text (api.quran.com v4).
The text is written VERBATIM (§1.2), minus the trailing ayah-number glyph the
Complex appends (the app draws its own ayah marker).

Run:  py -3 scripts/build_quran_text_kfgqpc.py
"""
import json
import re
import shutil
import sqlite3
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / 'rafeeq_app' / 'assets' / 'data' / 'quran_local.db'
MIRROR_SHA = '281dbbe8eed1370daa5a023b6cd81655cbfd6473'
KF_URL = ('https://raw.githubusercontent.com/thetruetruth/quran-data-kfgqpc/'
          f'{MIRROR_SHA}/hafs/data/hafsData_v18.json')
QC_URL = 'https://api.quran.com/api/v4/quran/verses/qpc_hafs'
UA = {'User-Agent': 'RafeeqAlDarb-build/1.0 (+https://github.com/tito423/Rafeeq-Al-Darb)'}

# The Complex ends every ayah with NBSP + the ayah number in Arabic-Indic digits.
TRAILING_NUMBER = re.compile(r'[  ]*[٠-٩]+\s*$')


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return json.loads(r.read().decode('utf-8'))


def main():
    kf = {(r['sora'], r['aya_no']): TRAILING_NUMBER.sub('', r['aya_text']).strip()
          for r in fetch(KF_URL)}
    qc = {tuple(map(int, v['verse_key'].split(':'))):
          TRAILING_NUMBER.sub('', v['text_qpc_hafs']).strip()
          for v in fetch(QC_URL)['verses']}
    if len(kf) != 6236 or len(qc) != 6236:
        sys.exit(f'expected 6236 ayahs, got {len(kf)} / {len(qc)}')
    differ = [k for k in kf if kf[k] != qc.get(k)]
    if differ:
        sys.exit(f'the two copies disagree on {len(differ)} ayahs, e.g. {differ[:5]} - not writing')
    if any(TRAILING_NUMBER.search(t) or not t for t in kf.values()):
        sys.exit('an ayah still ends in a number or is empty')

    backup = DB.with_suffix('.db.bak')
    shutil.copyfile(DB, backup)
    con = sqlite3.connect(DB)
    rows = con.execute('select surah_id, ayah_number from ayahs').fetchall()
    if len(rows) != 6236 or set(rows) != set(kf):
        sys.exit('quran_local.db does not hold the same 6,236 ayah keys')
    con.executemany('update ayahs set text_uthmani = ? where surah_id = ? and ayah_number = ?',
                    [(kf[k], k[0], k[1]) for k in kf])
    con.commit()
    written = dict(((s, a), t) for s, a, t in
                   con.execute('select surah_id, ayah_number, text_uthmani from ayahs'))
    con.execute('vacuum')
    con.close()
    bad = [k for k in kf if written[k] != kf[k]]
    if bad:
        sys.exit(f'read-back mismatch on {len(bad)} ayahs')
    print(f'ok: 6236 ayahs written from KFGQPC hafs v18, both copies identical; '
          f'backup at {backup.name}')
    print('18:31 ->', written[(18, 31)][:40])


if __name__ == '__main__':
    main()
