"""Every dhikr of Hisn al-Muslim (azkar.db, all 302) voiced ONCE as its own
mp3, for the dhikr page's single «استمع» button (owner, 2026-10-06: «شيل زر
الصوت الآلي من الأذكار … شوف جيميني زي ما عملنا صوت الفيديوهات … فكنا من
تسجيلات حصن المسلم لو مش كاملة»; hisnmuslim.com covers 213 of 302 and does
not name its reader).

Same rules as tools/azkar_voice.py (morning/evening, 2026-10-03), which the
owner accepted:
  * Qur'an - every {...} passage, every (...) with ayah stars, and a line that
    is exactly the basmala - is the reciter's own ayah file (Alafasy,
    everyayah 128 kbps). Each piece between the stars must equal ONE whole
    ayah of the mushaf (letters compared, marks ignored), or the item stops
    and is reported: a partial ayah is never played from a whole-ayah file,
    and Qur'an is never handed to a synthetic voice.
  * Everything else is Gemini TTS (scripts/kids_stories/gemini_tts.py, key
    from scripts/.env, voice Sadaltager, the same style line), one clip per
    line, transcribed back with faster-whisper and compared letter by letter;
    every ratio goes into the report.
Writes scripts/out/azkar_voice/items/<id>.mp3, items.json (id -> seconds,
bytes, sha1), asr_report_all.json, quran_map.json. Resumable: finished clips
and items are kept. Uploads nothing.

    py -3 scripts/azkar_voice_all.py            (from the repo root)
"""
import difflib, hashlib, json, os, re, sqlite3, subprocess, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
sys.path.insert(0, 'scripts/kids_stories')
from gemini_tts import tts  # noqa: E402

FF = r'C:/Program Files/ShareX/ffmpeg.exe'
OUT = 'scripts/out/azkar_voice'
ITEMS = f'{OUT}/items'
os.makedirs(ITEMS, exist_ok=True)
VOICE, STYLE = 'Sadaltager', ('اقرأ هذا الذكر بصوت هادئ خاشع وبطء معتدل، بالعربية الفصحى، '
                              'وانطق كل حرف بتشكيله كما هو مكتوب تماما، دون أي زيادة أو نقص.')
EA = 'https://everyayah.com/data/Alafasy_128kbps'
BASMALA = 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'


def letters(t):
    t = re.sub('[\u064b-\u065f\u0670\u06d6-\u06ed\u0640]', '', t)
    t = re.sub('[أإآٱ]', 'ا', t).replace('ى', 'ي').replace('ة', 'ه')
    return re.sub('[^ء-ي]', '', t)


def ayah_index():
    q = sqlite3.connect('rafeeq_app/assets/data/quran_local.db')
    idx = {}
    for s, a, txt in q.execute('select surah_id, ayah_number, text_uthmani from ayahs order by id'):
        idx.setdefault(letters(txt), (s, a))
    return idx


def ayah_mp3(s, a):
    fn = f'{OUT}/q{s:03d}{a:03d}.mp3'
    if not os.path.exists(fn):
        req = urllib.request.Request(f'{EA}/{s:03d}{a:03d}.mp3', headers={'User-Agent': 'RafeeqAlDarb'})
        data = urllib.request.urlopen(req, timeout=120).read()
        open(fn, 'wb').write(data)
    return fn


QC = 'https://api.quran.com/api/v4'
# A dhikr that only TELLS you to read whole surahs («يقرأ الم تنزيل … وتبارك
# …») is not voiced: its «...» are surah titles, not words to recite.
SKIP = {138}


def _json(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'RafeeqAlDarb (tito423 on GitHub)'})
    return json.load(urllib.request.urlopen(req, timeout=60))


def partial_ayah(piece, idx):
    """A Qur'an piece that is PART of one ayah: the reciter's own audio of
    that ayah (quran.com's Alafasy, recitation 7), cut at his word timings
    (quran.com `segments`: [i, word position, start ms, end ms]). Returns
    (wav, (surah, ayah, first word, last word)) or None. The run of words
    must spell the piece exactly, letters compared."""
    want = letters(piece)
    hits = [v for k, v in idx.items() if want and want in k]
    if len(hits) != 1:
        return None
    s, a = hits[0]
    words = [w for w in _json(f'{QC}/verses/by_key/{s}:{a}?words=true&word_fields=text_uthmani')['verse']['words']
             if w['char_type_name'] == 'word']
    ls = [letters(w['text_uthmani']) for w in words]
    run = None
    for i in range(len(ls)):
        acc = ''
        for j in range(i, len(ls)):
            acc += ls[j]
            if acc == want:
                run = (words[i]['position'], words[j]['position'])
            if len(acc) >= len(want):
                break
        if run:
            break
    if not run:
        return None
    af = _json(f'{QC}/recitations/7/by_ayah/{s}:{a}?fields=segments')['audio_files'][0]
    seg = {p: (st, en) for _, p, st, en in af['segments']}
    if run[0] not in seg or run[1] not in seg:
        return None
    src = f'{OUT}/qc{s:03d}{a:03d}.mp3'
    if not os.path.exists(src):
        req = urllib.request.Request('https://verses.quran.com/' + af['url'], headers={'User-Agent': 'RafeeqAlDarb'})
        open(src, 'wb').write(urllib.request.urlopen(req, timeout=120).read())
    start, end = seg[run[0]][0] / 1000, seg[run[1]][1] / 1000
    dst = f'{OUT}/qc{s:03d}{a:03d}_{run[0]}-{run[1]}.wav'
    if not os.path.exists(dst):
        subprocess.run([FF, '-y', '-loglevel', 'error', '-i', src, '-ss', f'{start:.3f}', '-to', f'{end:.3f}',
                        '-ar', '24000', '-ac', '1', dst], check=True)
    return dst, (s, a, run[0], run[1])


def to_wav(src, dst):
    if not os.path.exists(dst):
        subprocess.run([FF, '-y', '-loglevel', 'error', '-i', src, '-ar', '24000', '-ac', '1', dst], check=True)
    return dst


def secs(p):
    r = subprocess.run([FF, '-i', p], capture_output=True, text=True, encoding='utf-8', errors='replace')
    h, m, s = re.search(r'Duration: (\d+):(\d+):([\d.]+)', r.stderr).groups()
    return int(h) * 3600 + int(m) * 60 + float(s)


def pcm16k(p):
    import numpy as np
    raw = subprocess.run([FF, '-loglevel', 'error', '-i', p, '-f', 's16le', '-ac', '1', '-ar', '16000', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0


def main():
    from faster_whisper import WhisperModel
    asr = WhisperModel(os.environ.get('AZKAR_ASR', 'small'), device='cpu', compute_type='int8')
    idx = ayah_index()
    db = sqlite3.connect('rafeeq_app/assets/data/azkar.db')
    gap = f'{OUT}/gap.wav'
    subprocess.run([FF, '-y', '-loglevel', 'error', '-f', 'lavfi', '-i', 'anullsrc=r=24000:cl=mono',
                    '-t', '0.5', gap], check=True)
    rep_path = f'{OUT}/asr_report_all.json'
    report = json.load(open(rep_path, encoding='utf-8')) if os.path.exists(rep_path) else {}
    items_path = f'{OUT}/items.json'
    items = json.load(open(items_path, encoding='utf-8')) if os.path.exists(items_path) else {}
    qmap, stopped = {}, []
    rows = list(db.execute('select id, body from azkar_items order by id'))
    for n, (iid, body) in enumerate(rows, 1):
        mp3 = f'{ITEMS}/{iid}.mp3'
        parts, qs, ok = [], [], True
        for c in re.split(r'(\{[^}]*\}|\([^)]*\*[^)]*\))', body):
            c = c.strip()
            if not c:
                continue
            if c.startswith('{') or (c.startswith('(') and '*' in c):
                for piece in c.strip('{}()').split('*'):
                    hit = idx.get(letters(piece))
                    if hit:
                        qs.append(hit)
                        parts.append(to_wav(ayah_mp3(*hit), f'{OUT}/q{hit[0]:03d}{hit[1]:03d}.wav'))
                        continue
                    cut = None if iid in SKIP else partial_ayah(piece, idx)
                    if not cut:
                        ok = False
                        stopped.append({'item': iid, 'piece': piece.strip()[:120]})
                        break
                    wav, where = cut
                    qs.append(where)
                    if wav not in report:
                        segs, _ = asr.transcribe(pcm16k(wav), language='ar', beam_size=5)
                        heard = ' '.join(x.text for x in segs).strip()
                        report[wav] = {'item': iid, 'text': piece.strip(), 'heard': heard, 'quran_cut': where,
                                       'ratio': round(difflib.SequenceMatcher(None, letters(piece), letters(heard)).ratio(), 3)}
                    parts.append(wav)
                if not ok:
                    break
                continue
            for line in [x.strip() for x in c.split('\n') if x.strip()]:
                if letters(line) == letters(BASMALA):
                    parts.append(to_wav(ayah_mp3(1, 1), f'{OUT}/q001001.wav'))
                    qs.append((1, 1))
                    continue
                if not letters(line):
                    continue
                fn = f'{OUT}/g{iid}_{hashlib.sha1(line.encode()).hexdigest()[:8]}.wav'
                if not os.path.exists(fn):
                    for _ in range(3):
                        if tts(line, VOICE, STYLE, fn):
                            break
                if not os.path.exists(fn):
                    # Gemini refused (content_blocked) or failed 3 times: the item
                    # gets no clip and is listed, the run goes on.
                    print('TTS FAILED', iid, flush=True)
                    ok = False
                    stopped.append({'item': iid, 'tts_failed': line[:120]})
                    break
                if fn not in report:
                    segs, _ = asr.transcribe(pcm16k(fn), language='ar', beam_size=5)
                    heard = ' '.join(s.text for s in segs).strip()
                    report[fn] = {'item': iid, 'text': line, 'heard': heard,
                                  'ratio': round(difflib.SequenceMatcher(None, letters(line), letters(heard)).ratio(), 3)}
                    json.dump(report, open(rep_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
                parts.append(fn)
                parts.append(gap)
            if not ok:
                break
        if not ok:
            print(f'[{n}/{len(rows)}] {iid} STOPPED: Qur\'an piece is not one whole ayah', flush=True)
            continue
        if qs:
            qmap[iid] = qs
        if not os.path.exists(mp3):
            lst = f'{ITEMS}/{iid}.txt'
            open(lst, 'w', encoding='utf-8').write(''.join(f"file '{os.path.abspath(p)}'\n" for p in parts))
            subprocess.run([FF, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lst,
                            '-ac', '1', '-ar', '44100', '-b:a', '96k', mp3], check=True)
            os.remove(lst)
        data = open(mp3, 'rb').read()
        items[str(iid)] = {'seconds': round(secs(mp3), 2), 'bytes': len(data),
                           'sha1': hashlib.sha1(data).hexdigest()}
        json.dump(items, open(items_path, 'w', encoding='utf-8'), indent=1)
        print(f'[{n}/{len(rows)}] {iid} ok {items[str(iid)]["seconds"]} s', flush=True)
    json.dump(qmap, open(f'{OUT}/quran_map.json', 'w', encoding='utf-8'), indent=1)
    json.dump(stopped, open(f'{OUT}/stopped.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    low = sorted((r for r in report.values() if r['ratio'] < 0.9), key=lambda r: r['ratio'])
    print('items', len(items), 'of', len(rows), '| stopped', len(stopped), '| gemini clips', len(report),
          '| ratio<0.9:', len(low), flush=True)


if __name__ == '__main__':
    main()
