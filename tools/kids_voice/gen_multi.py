# One Gemini TTS request carrying several narration lines (run in a story folder).
#   py -3 ../gen_multi.py b1.wav 1 2 3 4                     # gemini-3.8-flash-tts (the owner's pick)
#   py -3 ../gen_multi.py --model gemini-3.8-flash-lite-tts b1.wav 1 2 3 4
#   py -3 ../gen_multi.py --model gemini-2.5-flash-preview-tts --plain b1.wav 1 2 3 4
# Each model has its OWN free quota (10 requests/day, measured 2026-10-01), and
# the owner approved the lite and 2.5 voices («الاتنين تمام»). One story is
# voiced by ONE model, so the voice never changes inside a story.
# --plain: 2.5 rejects per-line style annotations (HTTP 400), so the direction
# goes in the text itself; ASR showed it is not read aloud.
import sys, json, base64, wave, urllib.request, urllib.error
sys.path.insert(0, 'E:/DevEnv/kids_voice')
from gemini_tts import KEY
BASE = ("a warm, calm Arabic storyteller for young children, recorded in a professional studio with a high-end "
        "microphone, perfectly clean audio with no background noise or hiss, clear Modern Standard Arabic (fusha) "
        "with correct tashkeel, unhurried; leave a clear pause of about one second after each sentence; mood: ")
args = sys.argv[1:]
model = 'gemini-3.8-flash-tts'
if '--model' in args:
    i = args.index('--model'); model = args[i + 1]; del args[i:i + 2]
plain = '--plain' in args
if plain: args.remove('--plain')
out, ids = args[0], args[1:]
lines = dict(l.split('\t') for l in open('lines.tsv', encoding='utf-8').read().splitlines())
moods = json.load(open('moods.json', encoding='utf-8'))
if plain:
    text = ("Read the following Arabic lines aloud like a warm, calm storyteller for young children, in clear "
            "Modern Standard Arabic with correct tashkeel, unhurried, with a pause of about one second between "
            "lines:\n\n" + "\n\n".join(lines[i] for i in ids))
    content = [{"type": "text", "text": text}]
else:
    content = [{"type": "text", "text": lines[i], "annotations": [{"type": "speech_metadata", "style": BASE + moods.get(i, 'warm')}]} for i in ids]
body = {"model": model, "input": [{"type": "user_input", "content": content}],
        "response_format": {"type": "audio"}, "generation_config": {"speech_config": [{"voice": "Sadaltager"}]}}
r = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/interactions", data=json.dumps(body).encode(),
                           headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
try:
    j = json.load(urllib.request.urlopen(r, timeout=240))
except urllib.error.HTTPError as e:
    print('HTTP', e.code, e.read().decode()[:400]); sys.exit(1)
data = None
for st in j.get('steps', []):
    for c in st.get('content', []) or []:
        if c.get('data'): data = c['data']
if not data:
    print('no audio', json.dumps(j)[:400]); sys.exit(1)
raw = base64.b64decode(data)
if raw[:4] == b'RIFF':
    open(out, 'wb').write(raw)
else:
    w = wave.open(out, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000); w.writeframes(raw); w.close()
print('ok', out, model, len(raw))
