"""Transcribe an adhan recording with Whisper and print word timings.

A probe, not a pipeline: it answers "what does this recording actually say,
and when" so the phrase timings can be checked against speech rather than
against silence.

    py -3 scripts/whisper_adhan_probe.py <file.mp3> [model] > out.txt
"""
import sys

from faster_whisper import WhisperModel

path = sys.argv[1]
size = sys.argv[2] if len(sys.argv) > 2 else 'small'
model = WhisperModel(size, device='cpu', compute_type='int8')
segs, info = model.transcribe(
    path, language='ar', word_timestamps=True, vad_filter=False,
    beam_size=5, condition_on_previous_text=False)
sys.stdout.reconfigure(encoding='utf-8')
for s in segs:
    print(f'[{s.start:7.2f} - {s.end:7.2f}] {s.text.strip()}')
    for w in s.words or []:
        print(f'      {w.start:7.2f} {w.end:7.2f} {w.probability:.2f} {w.word.strip()}')
