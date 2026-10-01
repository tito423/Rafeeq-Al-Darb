"""Build the kids-corner story catalogue for the app from the real artefacts.

    py -3 scripts/build_kids_stories.py           # posters + Dart catalogue
    py -3 scripts/build_kids_stories.py --upload  # ... and upload video + poster to R2

Nothing in the generated Dart is typed by hand:
- the captions are the EXACT lines that were voiced (the same text the TTS was
  given), timed from the story's timing.json and the mix rules in mix2.py
  (0.25 s lead, the recitation file's own length, its pause, the narration);
- a recitation caption carries only (surah, ayah) - the app shows the ayah from
  its own bundled mushaf text, never a copy kept here;
- duration, byte size and poster come from the rendered MP4 itself.
After --upload every object is read back (HEAD) and must match the local size,
and the public URL must answer a range request with 206 (CLAUDE.md §1.1).
"""
import json, os, re, subprocess, sys, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WT = os.path.join(ROOT, '.claude', 'worktrees', 'agent-a383b101b770abc86', 'kids_stories')
VOICE = 'E:/DevEnv/kids_voice'
FF = r'C:/Program Files/ShareX/ffmpeg.exe'
OUT_DART = os.path.join(ROOT, 'rafeeq_app', 'lib', 'features', 'kids', 'data', 'kids_stories_data.dart')
POSTERS = os.path.join(ROOT, 'scripts', 'out', 'kids_posters')
PUBLIC = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'

def nuh_lines():
    L = [l.strip() for l in open(f'{VOICE}/lines.txt', encoding='utf-8') if l.strip()]
    L[11] = L[11].replace('فَنَجَّى', 'فَأَنْجَى')   # as genall_g.py voiced it
    return {i + 1: t for i, t in enumerate(L)}

def tsv_lines(story):
    return {int(n): t for n, t in (l.split('\t') for l in open(f'{VOICE}/{story}/lines.tsv', encoding='utf-8').read().splitlines())}

STORIES = [
    # id, category, render folder, mp4, lines, {scene: (surah, ayah, wav, pause_after, narration_follows)}, poster second
    ('nuh', 'prophets', 'noah', 'noah/out/noah_v2.mp4', nuh_lines,
     {11: (11, 44, f'{VOICE}/gemini/r11044.wav', 0.5, True)}, 38.5),
    ('yunus', 'prophets', 'yunus', 'yunus/out/yunus_v1.mp4', lambda: tsv_lines('yunus'),
     {9: (21, 87, f'{VOICE}/yunus/r21087.wav', 0.6, False)}, 62.0),
    ('ibrahim', 'prophets', 'ibrahim', 'ibrahim/out/ibrahim_v1.mp4', lambda: tsv_lines('ibrahim'),
     {10: (21, 69, f'{VOICE}/ibrahim/r21069.wav', 0.6, False)}, 61.5),
    ('musa', 'prophets', 'musa', 'musa/out/musa_v1.mp4', lambda: tsv_lines('musa'),
     {7: (26, 63, f'{VOICE}/musa/rec.wav', 0.6, False)}, 66.0),
    ('sulayman', 'prophets', 'sulayman', 'sulayman/out/sulayman_v1.mp4', lambda: tsv_lines('sulayman'),
     {9: (27, 19, f'{VOICE}/sulayman/rec.wav', 0.6, False)}, 38.0),
    ('salih', 'prophets', 'salih', 'salih/out/salih_v1.mp4', lambda: tsv_lines('salih'),
     {6: (11, 64, f'{VOICE}/salih/rec.wav', 0.6, False)}, 66.0),
    ('hud', 'prophets', 'hud', 'hud/out/hud_v1.mp4', lambda: tsv_lines('hud'),
     {8: (46, 24, f'{VOICE}/hud/rec.wav', 0.6, False)}, 62.0),
    # 2026-10-01: voiced in the AI Studio UI (gemini-3.8-flash-tts, Sadaltager, 4 lines a run);
    # poster None = the middle of scene 3.
    ('ayyub', 'prophets', 'ayyub', 'ayyub/out/ayyub_v1.mp4', lambda: tsv_lines('ayyub'),
     {6: (21, 83, f'{VOICE}/ayyub/rec.wav', 0.6, False)}, None),
    ('zakariya', 'prophets', 'zakariya', 'zakariya/out/zakariya_v1.mp4', lambda: tsv_lines('zakariya'),
     {5: (21, 89, f'{VOICE}/zakariya/rec.wav', 0.6, False)}, None),
    ('kaaba', 'prophets', 'kaaba', 'kaaba/out/kaaba_v1.mp4', lambda: tsv_lines('kaaba'),
     {12: (2, 127, f'{VOICE}/kaaba/rec.wav', 0.6, False)}, None),
    ('ilyas', 'prophets', 'ilyas', 'ilyas/out/ilyas_v1.mp4', lambda: tsv_lines('ilyas'),
     {5: (37, 125, f'{VOICE}/ilyas/rec.wav', 0.6, False)}, None),
    ('kahf', 'righteous', 'kahf', 'kahf/out/kahf_v1.mp4', lambda: tsv_lines('kahf'),
     {6: (18, 10, f'{VOICE}/kahf/rec.wav', 0.6, False)}, None),
    ('luqman', 'righteous', 'luqman', 'luqman/out/luqman_v1.mp4', lambda: tsv_lines('luqman'),
     {4: (31, 13, f'{VOICE}/luqman/rec.wav', 0.6, False)}, None),
    # the whole of al-Fil: five per-ayah files joined with 0.4 s between them (as fil/rec.wav was built)
    ('fil', 'quran', 'fil', 'fil/out/fil_v1.mp4', lambda: tsv_lines('fil'),
     {7: (105, [(a, f'{VOICE}/fil/r{a}.wav') for a in range(1, 6)], None, 0.6, False)}, None),
    ('yusuf', 'prophets', 'yusuf', 'yusuf/out/yusuf_v1.mp4', lambda: tsv_lines('yusuf'),
     {20: (12, 92, f'{VOICE}/yusuf/rec.wav', 0.6, False)}, None),
    ('shuayb', 'prophets', 'shuayb', 'shuayb/out/shuayb_v1.mp4', lambda: tsv_lines('shuayb'),
     {5: (11, 85, f'{VOICE}/shuayb/rec.wav', 0.6, False)}, None),
    ('musa_baby', 'prophets', 'musa_baby', 'musa_baby/out/musa_baby_v1.mp4', lambda: tsv_lines('musa_baby'),
     {4: (28, 7, f'{VOICE}/musa_baby/rec.wav', 0.6, False)}, None),
]
STORIES = [e for e in STORIES if os.path.exists(os.path.join(WT, e[3]))]   # only rendered stories

def wav_seconds(p):
    w = wave.open(p); return w.getnframes() / w.getframerate()

def probe_seconds(p):
    out = subprocess.run([FF, '-hide_banner', '-i', p], capture_output=True, text=True).stderr
    h, m, s = re.search(r'Duration: (\d+):(\d+):([\d.]+)', out).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)

def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"

def build():
    os.makedirs(POSTERS, exist_ok=True)
    entries = []
    for sid, cat, folder, mp4, lines_fn, rec, poster_t in STORIES:
        mp4p = os.path.join(WT, mp4)
        T = [e['seconds'] for e in json.load(open(os.path.join(WT, folder, 'timing.json')))]
        lines = lines_fn()
        caps, start = [], 0.0
        for i, d in enumerate(T, 1):
            last = i == len(T)
            end_pad = 1.5 if last else 0.3
            if i in rec:
                su, ay, wavp, pause, follows = rec[i]
                if isinstance(ay, list):          # several ayat, 0.4 s apart
                    t0 = start + 0.25
                    for k, (a, w) in enumerate(ay):
                        ra = wav_seconds(w); caps.append((t0, t0 + ra, None, su, a)); t0 += ra + (0.4 if k < len(ay) - 1 else 0)
                    r = t0 - (start + 0.25)
                else:
                    r = wav_seconds(wavp)
                    caps.append((start + 0.25, start + 0.25 + r, None, su, ay))
                if follows:
                    caps.append((start + 0.25 + r + pause, start + d - end_pad, lines[i], None, None))
            else:
                caps.append((start + 0.25, start + d - end_pad, lines[i], None, None))
            start += d
        size = os.path.getsize(mp4p)
        dur = probe_seconds(mp4p)
        if abs(dur - start) > 0.2:
            sys.exit(f'{sid}: video {dur:.2f} s but timing.json sums to {start:.2f} s')
        if poster_t is None:
            poster_t = round(sum(T[:2]) + T[2] / 2, 1)
        poster = os.path.join(POSTERS, f'{sid}.jpg')
        subprocess.run([FF, '-v', 'error', '-y', '-ss', str(poster_t), '-i', mp4p, '-frames:v', '1',
                        '-vf', 'scale=640:-2', '-q:v', '3', poster], check=True)
        entries.append(dict(id=sid, cat=cat, size=size, dur=dur, poster=os.path.getsize(poster), caps=caps, mp4=mp4p, posterp=poster))
    lines = ['// GENERATED by scripts/build_kids_stories.py - do not edit by hand.',
             '// Captions are the exact voiced lines, timed from each story\'s timing.json;',
             '// a recitation caption holds only its (surah, ayah) - the text comes from',
             '// the app\'s own mushaf database.',
             "import 'kids_stories.dart';", '',
             'const kidsStories = <KidsStory>[']
    for e in entries:
        lines.append(f"  KidsStory(id: '{e['id']}', category: StoryCategory.{e['cat']}, seconds: {e['dur']:.2f}, bytes: {e['size']}, captions: [")
        for a, b, txt, su, ay in e['caps']:
            if txt is None:
                lines.append(f'    StoryCaption({a:.2f}, {b:.2f}, surah: {su}, ayah: {ay}),')
            else:
                lines.append(f'    StoryCaption({a:.2f}, {b:.2f}, text: {dart_str(txt)}),')
        lines.append('  ]),')
    lines.append('];')
    open(OUT_DART, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    for e in entries:
        print(e['id'], f"{e['dur']:.2f} s", e['size'], 'bytes,', len(e['caps']), 'captions, poster', e['poster'], 'bytes')
    return entries

def upload(entries):
    sys.path.insert(0, os.path.join(ROOT, 'scripts'))
    from r2_common import r2_client, BUCKET
    s3 = r2_client()
    for e in entries:
        for local, key, ctype in [(e['mp4'], f"kids/stories/{e['id']}.mp4", 'video/mp4'),
                                  (e['posterp'], f"kids/stories/{e['id']}.jpg", 'image/jpeg')]:
            s3.upload_file(local, BUCKET, key, ExtraArgs={'ContentType': ctype, 'CacheControl': 'public, max-age=86400'})
            head = s3.head_object(Bucket=BUCKET, Key=key)
            if head['ContentLength'] != os.path.getsize(local):
                sys.exit(f'{key}: R2 has {head["ContentLength"]} bytes, local {os.path.getsize(local)}')
            r = subprocess.run(['curl', '-s', '-r', '0-1023', '-o', os.devnull, '-A', 'RafeeqAlDarb/1.0',
                                '-w', '%{http_code} %{size_download}', f'{PUBLIC}/{key}'], capture_output=True, text=True)
            print(key, head['ContentLength'], 'bytes on R2; public range ->', r.stdout)
            if not r.stdout.startswith('206'):
                sys.exit(f'{key}: public endpoint did not answer 206')

if __name__ == '__main__':
    ents = build()
    if '--upload' in sys.argv:
        upload(ents)
