# Pair AI Studio downloads (oldest first) with plan.tsv rows, move them in, split + ASR-check each line.
import glob, os, shutil, subprocess, sys, re, difflib
sys.stdout.reconfigure(encoding='utf-8')
K = 'E:/DevEnv/kids_voice'
plan = [l.split() for l in open(f'{K}/new/plan.tsv')]
files = sorted(glob.glob('C:/Users/Asus/Downloads/Generated Audio*.wav'), key=os.path.getmtime)
n = int(sys.argv[1]) if len(sys.argv) > 1 else len(files)
done = [p for p in plan if os.path.exists(f'{K}/{p[0]}/{p[1]}.wav')]
todo = [p for p in plan if p not in done]
def nz(s):
    s = re.sub(r'[\u064B-\u065F\u0670\u0640]', '', s); s = re.sub('[إأآٱ]', 'ا', s).replace('ى', 'ي').replace('ة', 'ه')
    return re.sub(r'[^\u0621-\u064A]', '', s.replace('ﷺ', 'صلى الله عليه وسلم'))
for (sid, b, ids), f in zip(todo, files[:n]):
    shutil.move(f, f'{K}/{sid}/{b}.wav')
    out = subprocess.run(['py', '-3', '../split_ui.py', f'{b}={ids}'], cwd=f'{K}/{sid}', capture_output=True, text=True, encoding='utf-8', env={**os.environ, 'PYTHONIOENCODING': 'utf-8'}).stdout
    L = dict(l.split('\t') for l in open(f'{K}/{sid}/lines.tsv', encoding='utf-8').read().splitlines())
    for line in out.splitlines():
        if ' | ' in line and not line.startswith(b + ' MISMATCH') and 'BOUNDARY' not in line:
            _, i = line.split()[:2]; asr = line.split(' | ', 1)[1]
            r = difflib.SequenceMatcher(None, nz(asr), nz(L[i])).ratio()
            print(f'{sid} {i} {r:.2f}' + ('  <-- CHECK | ' + asr if r < 0.9 else ''))
        elif 'MISMATCH' in line or 'BOUNDARY' in line:
            print(sid, line)
