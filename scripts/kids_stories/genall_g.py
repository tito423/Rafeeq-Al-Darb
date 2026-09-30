import sys, time
sys.path.insert(0, '..')
from gemini_tts import tts
BASE = ("a warm, calm Arabic storyteller for young children, recorded in a professional studio with a high-end "
        "microphone, perfectly clean audio with no background noise or hiss, clear Modern Standard Arabic (fusha) "
        "with correct tashkeel, unhurried; mood of this line: ")
MOOD = ["gentle and wondering, opening a story", "warm and reverent", "admiring his patience",
        "calm and steady", "a little sad", "quiet suspense, something is beginning",
        "steady and important, clear", "grand and awe-filled but not scary for children",
        "awe at the huge waves", "tender and sad, softly", "relief and calm returning",
        "warm, gentle and kind, giving the lesson slowly"]
lines = [l.strip() for l in open('../lines.txt', encoding='utf-8') if l.strip()]
lines[11] = lines[11].replace('فَنَجَّى', 'فَأَنْجَى')
for i, text in enumerate(lines, 1):
    if len(sys.argv) > 1 and str(i) not in sys.argv[1:]: continue
    for attempt in range(3):
        if tts(text, 'Sadaltager', BASE + MOOD[i-1], f'raw{i:02d}.wav'): break
        time.sleep(20)
