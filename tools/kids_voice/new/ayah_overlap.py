# Flag narrator lines containing >=N consecutive words that also occur consecutively in an ayah.
import sqlite3, re, sys, json
N = int(sys.argv[1]) if len(sys.argv) > 1 else 3
def norm(s):
    s = re.sub(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]', '', s)
    s = re.sub('[إأآٱ]', 'ا', s).replace('ى', 'ي').replace('ة', 'ه').replace('ؤ', 'و').replace('ئ', 'ي')
    return re.sub(r'[^\u0621-\u064A ]', ' ', s).split()
db = sqlite3.connect('E:/My Projects/Rafiq-Al-Darb/rafeeq_app/assets/data/quran_local.db')
grams = {}
for su, ay, t in db.execute('select surah_id, ayah_number, text_uthmani from ayahs'):
    w = norm(t)
    for i in range(len(w) - N + 1):
        grams.setdefault(' '.join(w[i:i+N]), f'{su}:{ay}')
STOP = {'ان الله علي', 'الله علي كل', 'علي كل شيء', 'كل شيء قدير'}
IDS = sys.argv[2].split(",") if len(sys.argv) > 2 else list(json.load(open("E:/DevEnv/kids_voice/new/scenes.json")))
sys.stdout.reconfigure(encoding="utf-8")
for sid in IDS:
    for l in open(f'E:/DevEnv/kids_voice/{sid}/lines.tsv', encoding='utf-8'):
        n, t = l.rstrip('\n').split('\t')
        # strip the conjunction/prefix wa/fa so «فان» matches «وان»
        w = [re.sub(r'^[وف](?=..)', '', x) for x in norm(t)]
        hits = []
        for i in range(len(w) - N + 1):
            g = ' '.join(w[i:i+N])
            for k, ref in grams.items():
                pass
            break
        # compare with prefix-stripped grams too
        hits = [(' '.join(w[i:i+N]), GR[' '.join(w[i:i+N])]) for i in range(len(w)-N+1) if ' '.join(w[i:i+N]) in GR] if 'GR' in dir() else None
        if hits is None:
            GR = {}
            for k, v in grams.items():
                GR.setdefault(' '.join(re.sub(r'^[وف](?=..)', '', x) for x in k.split()), v)
            hits = [(' '.join(w[i:i+N]), GR[' '.join(w[i:i+N])]) for i in range(len(w)-N+1) if ' '.join(w[i:i+N]) in GR]
        if hits:
            print(f'{sid} {n}: ' + ' | '.join(f'{g} ({r})' for g, r in hits))
