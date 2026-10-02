# lines.tsv per new story from docs/kids_stories/<id>_narration.md (narrator column, recitation rows skipped)
import re, os, sys, json
DOCS = 'E:/My Projects/Rafiq-Al-Darb/docs/kids_stories'
IDS = 'ayyub zakariya yusuf kahf luqman shuayb kaaba musa_baby fil isa dhulqarnayn jannatayn hudhud adam dawud dhabih ihya ilyas khidr dayf sabt'.split()
summary = {}
for sid in IDS:
    rows = []
    for l in open(f'{DOCS}/{sid}_narration.md', encoding='utf-8'):
        m = re.match(r'^\| (\d+) \| (.*?) \| (.*)\|\s*$', l)
        if not m: continue
        n, txt = int(m.group(1)), m.group(2).strip()
        if '**تلاوة**' in txt: continue
        rows.append((n, txt))
    os.makedirs(f'E:/DevEnv/kids_voice/{sid}', exist_ok=True)
    open(f'E:/DevEnv/kids_voice/{sid}/lines.tsv', 'w', encoding='utf-8', newline='\n').write(''.join(f'{n}\t{t}\n' for n, t in rows))
    summary[sid] = [n for n, _ in rows]
    bad = [t for _, t in rows if '*' in t or '«' in t or '`' in t]
    print(sid, len(rows), 'MARKUP:' + str(len(bad)) if bad else '')
json.dump(summary, open('E:/DevEnv/kids_voice/new/scenes.json', 'w'), indent=0)
