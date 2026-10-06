"""Exports the hand-checked surahs (NNN.json here) to the app asset
rafeeq_app/assets/data/own_irab.json: {"surah:ayah": [[word, irab,
[[book, text], ...]], ...]}.

Only these files go to the app - never gen/ (gen_masaq.py output): the gate
(gate.py, 2026-10-06) found errors carried from MASAQ's own data in words it
marked 'agree', so generated text is a draft for hand review, not content.
A `nosrc` word (no book found) is left out.

    py -3 scripts/own_irab/export_app.py
"""
import glob, json, os, subprocess, sys

H = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data', 'own_irab.json')

if subprocess.call([sys.executable, os.path.join(H, 'check.py')], stdout=subprocess.DEVNULL):
    sys.exit('check.py failed - fix the surah files first')
out, n = {}, 0
for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
    d = json.load(open(f, encoding='utf-8'))
    for w in d['words']:
        if w['check'] == 'nosrc':
            continue
        alts = [[x['book'], x['text']] for x in w.get('alts', [])]
        # The tab sets «…» in gold as Qur'an words; a book's title is not one.
        irab = w['irab'].replace('«الجدول»', 'الجدول')
        out.setdefault(f"{d['surah']}:{w['a']}", []).append([w['w'], irab, alts])
        n += 1
json.dump(out, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(f'{n} words, {len(out)} ayahs, {len({k.split(":")[0] for k in out})} surahs -> {os.path.getsize(OUT):,} B')
