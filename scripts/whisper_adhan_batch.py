"""Transcribe adhan recordings with Whisper and save segments + words as JSON.

Evidence for `align_adhan_phrases.py`: what each recording actually says and
when, from speech recognition rather than from silence thresholds.

    py -3 scripts/whisper_adhan_batch.py <out.json> <file.mp3> [file.mp3 ...]

Files already present in <out.json> are skipped, so a killed run resumes.
"""
import json
import os
import sys

from faster_whisper import WhisperModel

out_path = sys.argv[1]
files = sys.argv[2:]
done = {}
if os.path.exists(out_path):
    with open(out_path, encoding='utf-8') as f:
        done = json.load(f)

model = WhisperModel(os.environ.get('WHISPER_MODEL', 'small'),
                     device='cpu', compute_type='int8')
for path in files:
    key = os.path.basename(path)
    if key in done:
        continue
    segs, info = model.transcribe(
        path, language='ar', word_timestamps=True, vad_filter=False,
        beam_size=5, condition_on_previous_text=False)
    done[key] = {
        'duration': info.duration,
        'segments': [
            {'start': s.start, 'end': s.end, 'text': s.text.strip(),
             'words': [{'start': w.start, 'end': w.end, 'p': w.probability,
                        'w': w.word.strip()} for w in (s.words or [])]}
            for s in segs
        ],
    }
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(done, f, ensure_ascii=False, indent=1)
    print('done', key, flush=True)
