# Gemini 3.8 Flash TTS: text (+ per-line style) -> 24 kHz WAV. Key read from scripts/.env, never printed.
import json, sys, base64, wave, urllib.request, urllib.error, time
KEY = next(l.split('=',1)[1].strip() for l in open(r'E:/My Projects/Rafiq-Al-Darb/scripts/.env', encoding='utf-8') if l.startswith('GEMINI_API_KEY='))
def tts(text, voice, style, out, model='gemini-3.8-flash-tts'):
    body = {"model": model,
            "input": [{"type": "user_input", "content": [{"type": "text", "text": text,
                       "annotations": [{"type": "speech_metadata", "style": style}]}]}],
            "response_format": {"type": "audio"},
            "generation_config": {"speech_config": [{"voice": voice}]}}
    req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/interactions",
        data=json.dumps(body).encode(), headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
    t = time.time()
    try:
        r = json.load(urllib.request.urlopen(req, timeout=120))
    except urllib.error.HTTPError as e:
        print('HTTP', e.code, e.read().decode()[:600]); return None
    data = None
    for st in r.get('steps', []):
        for c in st.get('content', []) or []:
            if c.get('data'): data = c['data']; mime = c.get('mime_type') or c.get('mimeType')
    if data is None:
        print('no audio; keys:', list(r.keys()), json.dumps(r)[:500]); return None
    raw = base64.b64decode(data)
    if raw[:4] == b'RIFF':
        open(out, 'wb').write(raw)
    else:
        w = wave.open(out, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000); w.writeframes(raw); w.close()
    print('ok', out, 'mime', mime, 'bytes', len(raw), 'secs', round(time.time()-t, 1))
    return out
if __name__ == '__main__':
    tts(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
