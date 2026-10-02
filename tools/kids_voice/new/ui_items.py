# Print the full JS for one AI Studio UI run on a FRESH generate-speech page:
# new dialog, voice Sadaltager, one speech block, a style that directs each sentence, Run, wait, Download.
import sys, json
sys.stdout.reconfigure(encoding='utf-8')
BASE = ("a warm, calm Arabic storyteller for young children, recorded in a professional studio with a high-end "
        "microphone, perfectly clean audio with no background noise or hiss, clear Modern Standard Arabic (fusha) "
        "with correct tashkeel, unhurried; leave a clear pause of about one and a half seconds between sentences. ")
sid, ids = sys.argv[1], sys.argv[2].split(',')
L = dict(l.split('\t') for l in open(f'E:/DevEnv/kids_voice/{sid}/lines.tsv', encoding='utf-8').read().splitlines())
M = json.load(open(f'E:/DevEnv/kids_voice/{sid}/moods.json', encoding='utf-8'))
style = BASE + 'Mood, sentence by sentence: ' + '; '.join(f'sentence {k}: {M[i]}' for k, i in enumerate(ids, 1)) + '.'
text = '\n\n'.join(L[i] for i in ids).replace('ﷺ', 'صلّى اللهُ عليهِ وسلَّمَ')
print('window.__run(' + json.dumps(style) + ',' + json.dumps(text, ensure_ascii=False) + ')')
