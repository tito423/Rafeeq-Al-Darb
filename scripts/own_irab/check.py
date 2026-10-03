"""Every own_irab/NNN.json word must be the mushaf token itself, in order,
covering the whole surah; every entry needs irab + a known check value.
    python3 scripts/own_irab/check.py"""
import glob, json, os, sqlite3, sys
HERE = os.path.dirname(os.path.abspath(__file__))
db = sqlite3.connect(os.path.join(HERE, '..', '..', 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
OK = {'agree', 'fuller', 'alt', 'fixed', 'nosrc'}
bad = 0
for f in sorted(glob.glob(os.path.join(HERE, '[0-9][0-9][0-9].json'))):
    d = json.load(open(f, encoding='utf-8'))
    toks = [(a, t) for a, txt in db.execute(
        'select ayah_number, text_uthmani from ayahs where surah_id=? order by ayah_number', (d['surah'],))
        for t in txt.split() if any('ء' <= c <= 'ي' for c in t)]
    mine = [(w['a'], w['w']) for w in d['words']]
    errs = [] if mine == toks else ['words differ from the mushaf']
    errs += [f"{w['a']}:{w['w']} bad entry" for w in d['words']
             if not w.get('irab') or w.get('check') not in OK or (w['check'] in ('alt', 'fixed') and not w.get('alts'))]
    bad += len(errs)
    print(os.path.basename(f), len(mine), 'words', 'OK' if not errs else errs[:5])
sys.exit(1 if bad else 0)
