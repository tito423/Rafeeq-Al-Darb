"""Merge the quiz translations into the question bank, with checks.

scripts/quiz/tr/<lang>_<part>.json map question id -> {"q", "c": [4], "e"}, the
correct answer first, as in the Arabic. Every question must have every
language; each translation must have four distinct, non-empty choices and
no Arabic letters (Urdu excepted - it is written in that script).

    py -3 scripts/quiz_merge_tr.py            # check + write
    py -3 scripts/quiz_merge_tr.py --dump N M # print questions N..M to translate
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BANK = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quiz', 'history_quiz.json')
TR = os.path.join(ROOT, 'scripts', 'quiz', 'tr')
LANGS = ['en', 'fr', 'es', 'pt', 'ru', 'ur']
ARABIC = re.compile('[؀-ۿ]')


def main(strict=True):
    bank = json.load(open(BANK, encoding='utf-8'))
    qs = bank['questions']
    if sys.argv[1:2] == ['--dump']:
        a, b = int(sys.argv[2]), int(sys.argv[3])
        for q in qs[a:b]:
            print(json.dumps({'id': q['id'], 'q': q['q'], 'c': q['choices'],
                              'e': q['explain']}, ensure_ascii=False))
        return
    problems = []
    tr = {}
    for lang in LANGS:
        # One file per language and part: en_1.json, en_2.json, ...
        tr[lang] = {}
        for p in sorted(glob.glob(os.path.join(TR, f'{lang}_*.json'))):
            tr[lang].update(json.load(open(p, encoding='utf-8')))
    for q in qs:
        t = {}
        for lang in LANGS:
            x = tr[lang].get(q['id'])
            if x is None:
                problems.append(f'{q["id"]} {lang}: missing')
                continue
            c = x.get('c') or []
            if not x.get('q') or not x.get('e') or len(c) != 4 or len(set(c)) != 4 or not all(c):
                problems.append(f'{q["id"]} {lang}: bad shape')
            if lang != 'ur' and any(ARABIC.search(s) for s in [x['q'], x['e'], *c]):
                problems.append(f'{q["id"]} {lang}: Arabic letters left')
            t[lang] = {'q': x['q'], 'c': c, 'e': x['e']}
        if t:
            q['t'] = t
    unknown = {lang: [k for k in tr[lang] if k not in {q['id'] for q in qs}] for lang in LANGS}
    for lang, ks in unknown.items():
        problems += [f'{k} {lang}: no such question' for k in ks]
    if problems:
        print(len(problems), 'problems'); print('\n'.join(problems[:40]))
        sys.exit(1)
    with open(BANK, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(bank, f, ensure_ascii=False, indent=0)
        f.write('\n')
    print('ok', len(qs), 'questions x', len(LANGS), 'languages')


if __name__ == '__main__':
    main()
