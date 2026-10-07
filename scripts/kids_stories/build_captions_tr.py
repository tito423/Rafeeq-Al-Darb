"""Translations of the kids stories' narration captions, checked and merged.

The voice of every story is Arabic, and so are the Qur'an verses in it; a
child reading the app in another language used to see only the Arabic
captions under the picture (CLAUDE.md §1.7c, owner 2026-10-08). The player
now shows the narration line in the reader's language.

scripts/kids_stories/tr/<lang>.json maps story id -> list of lines, one per
caption of that story in kids_stories_data.dart, in the same order, with
null where the caption is a recited ayah (the ayah stays the mushaf's
Arabic). This script fails unless every language has every story with the
same number of captions, nulls exactly where the ayahs are, no empty line,
and no Arabic letters outside Urdu. Then it writes
rafeeq_app/assets/data/kids_captions_tr.json.

    py -3 scripts/kids_stories/build_captions_tr.py
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
DART = os.path.join(ROOT, 'rafeeq_app', 'lib', 'features', 'kids', 'data', 'kids_stories_data.dart')
OUT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'kids_captions_tr.json')
LANGS = ['en', 'fr', 'es', 'pt', 'ru', 'ur']
ARABIC = re.compile('[ء-ي]')


def arabic_captions():
    src = open(DART, encoding='utf-8').read()
    stories = {}
    for m in re.finditer(r"KidsStory\(id: '(\w+)'(.*?)\]\),", src, re.S):
        caps = []
        for c in re.finditer(r'StoryCaption\(([^\n]*)\),?\n', m.group(2)):
            caps.append(None if 'surah:' in c.group(1) else 'text')
        stories[m.group(1)] = caps
    return stories


def main():
    ar = arabic_captions()
    out, problems = {}, []
    for lang in LANGS:
        path = os.path.join(HERE, 'tr', f'{lang}.json')
        if not os.path.exists(path):
            problems.append(f'{lang}: no file')
            continue
        tr = json.load(open(path, encoding='utf-8'))
        for sid, caps in ar.items():
            lines = tr.get(sid)
            if lines is None:
                problems.append(f'{lang} {sid}: missing')
                continue
            if len(lines) != len(caps):
                problems.append(f'{lang} {sid}: {len(lines)} lines, story has {len(caps)}')
                continue
            for i, (a, t) in enumerate(zip(caps, lines)):
                if (a is None) != (t is None):
                    problems.append(f'{lang} {sid}[{i}]: ayah/null mismatch')
                elif t is not None and not t.strip():
                    problems.append(f'{lang} {sid}[{i}]: empty')
                elif t is not None and lang != 'ur' and ARABIC.search(t):
                    problems.append(f'{lang} {sid}[{i}]: Arabic letters')
            out.setdefault(sid, {})[lang] = lines
        for sid in tr:
            if sid not in ar:
                problems.append(f'{lang} {sid}: no such story')
    if problems:
        print(len(problems), 'problems')
        print('\n'.join(problems[:40]))
        sys.exit(1)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print('ok', len(out), 'stories x', len(LANGS), 'languages,',
          sum(1 for s in ar.values() for c in s if c), 'lines each')


if __name__ == '__main__':
    main()
