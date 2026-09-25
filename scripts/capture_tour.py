"""Photograph the tour's screens in every language, from the app itself.

The tour shows PICTURES of the real screens («الأفضل تخلي الجولة اسكرين
شوتات», owner, 2026-09-25). This takes them:

  1. Build the capture APK (never published):
       cd rafeeq_app
       flutter build apk --release --dart-define=RAFEEQ_TOUR_CAPTURE=true
       cd .. && py -3 scripts/sign_release.py
     and install it on emulator-5554 over the normal build (same key, so the
     app keeps its data - the pictures show a used app, not an empty one).
  2. In the app, start the tour (More > How the app works > quick).
  3. Run this script. The capture build walks every stop of both tours, in
     every language, drawing nothing; at each stop it logs
         TOURCAP|<lang>|<key>|l,t,r,b|w,h|top,bottom|dpr
     (logical pixels). This script screenshots the screen, crops the system
     bars, writes rafeeq_app/assets/tour/<lang>/<key>.webp, records the
     feature's rectangle as fractions of the cropped picture in
     rafeeq_app/assets/tour/frames.json, and taps to move on.

A stop whose feature was not on screen is never logged (the walk skips it),
so it gets no picture and the tour leaves it out.
"""
import io
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'rafeeq_app' / 'assets' / 'tour'
WIDTH = 480


def adb(*args, **kw):
    return subprocess.run(['adb', *args], capture_output=True, **kw)


def screencap():
    return Image.open(io.BytesIO(adb('exec-out', 'screencap', '-p').stdout)).convert('RGB')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fj = OUT / 'frames.json'
    frames = json.loads(fj.read_text(encoding='utf-8')) if fj.exists() else {}

    def save():
        fj.write_text(json.dumps(frames, ensure_ascii=False, indent=1,
                                 sort_keys=True) + '\n', encoding='utf-8')
    adb('logcat', '-c')
    log = subprocess.Popen(['adb', 'logcat', '-v', 'raw', '-s', 'flutter:I'],
                           stdout=subprocess.PIPE, text=True, encoding='utf-8',
                           errors='replace')
    shots = 0
    print('waiting for the tour to start (More > How the app works > quick)...')
    for line in log.stdout:
        line = line.strip()
        if not line.startswith('TOURCAP|'):
            continue
        parts = line.split('|')
        if parts[1] == 'DONE':
            break
        lang, key, rect, size, bars, dpr = parts[1:7]
        if rect != 'NONE':
            time.sleep(1.5)  # let the tab's own animations settle
            img = screencap()
            dpr = float(dpr)
            top, bottom = (float(v) * dpr for v in bars.split(','))
            W, H = img.size
            crop = img.crop((0, round(top), W, round(H - bottom)))
            ch = crop.size[1]
            l, t, r, b = (float(v) * dpr for v in rect.split(','))
            fr = [max(0.0, l / W), max(0.0, (t - top) / ch),
                  min(1.0, r / W), min(1.0, (b - top) / ch)]
            if fr[3] <= fr[1] or fr[2] <= fr[0]:
                print(f'  {lang}/{key}: feature outside the picture, skipped')
            else:
                small = crop.resize((WIDTH, round(ch * WIDTH / W)), Image.LANCZOS)
                (OUT / lang).mkdir(exist_ok=True)
                small.save(OUT / lang / f'{key}.webp', 'WEBP', quality=72, method=6)
                frames.setdefault(lang, {})[key] = {
                    'r': [round(v, 4) for v in fr],
                    'a': round(W / ch, 4),
                }
                shots += 1
                save()  # after every picture: a stopped run keeps what it took
                print(f'  {lang}/{key}: saved ({shots})', flush=True)
        adb('shell', 'input', 'tap', '540', '1200')
    log.kill()
    save()
    total = sum(p.stat().st_size for p in OUT.rglob('*.webp'))
    print(f'done: {shots} pictures, {total / 1e6:.2f} MB, '
          f'{len(frames)} languages')


if __name__ == '__main__':
    sys.exit(main())
