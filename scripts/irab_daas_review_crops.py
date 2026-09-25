"""Cut, out of the printed page, the lines a human must read to settle what
arbitrate_irab_daas.py could not: every «?» difference and every doubtful
chunk (A and B agree, the print seems not to).

For each item: the section's pages are OCR'd again WITH line boxes
(winocr.ps1, WINOCR_BOXES=1), the line that best matches the item's words is
found, and that line with one line either side is cropped from a 200 dpi
render. Crops are stacked ten to a sheet with their number; the readings to
compare are written to review.txt under the same numbers.

    py -3 scripts/irab_daas_review_crops.py <pdf_dir> <out_dir>
"""
import difflib
import io
import json
import os
import subprocess
import sys

import pymupdf
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arbitrate_irab_daas import words  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
PS = os.path.join(ROOT, 'scripts', 'winocr.ps1')


def ocr_boxes(img_path, tmp):
    out = os.path.join(tmp, 'boxes.txt')
    env = dict(os.environ, WINOCR_BOXES='1')
    subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', PS, out, img_path],
                   check=True, capture_output=True, env=env)
    lines = []
    for l in io.open(out, encoding='utf-8').read().split('\n')[1:]:
        if '\t' not in l:
            continue
        box, text = l.split('\t', 1)
        x0, y0, x1, y1 = (float(v) for v in box.split(','))
        lines.append(((x0, y0, x1, y1), words(' '.join(reversed(text.split())), fold=True)))
    return lines


def best_line(lines, needle):
    s = ' '.join(needle)
    best, at = -1.0, None
    for i, (_, w) in enumerate(lines):
        # A reading can straddle two lines: score each line with its next.
        joined = ' '.join(w + (lines[i + 1][1] if i + 1 < len(lines) else []))
        r = difflib.SequenceMatcher(None, s, joined, autojunk=False).ratio()
        if r > best:
            best, at = r, i
    return at, best


def main():
    pdf_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    R = json.load(io.open(os.path.join(T, 'irab_daas_arbitration.json'), encoding='utf-8'))
    A = {(r['surah'], r['from']): r for r in
         json.load(io.open(os.path.join(T, 'irab_daas.json'), encoding='utf-8'))}
    docs = {v: pymupdf.open(os.path.join(pdf_dir, f'i3rab-krn-0{v}.pdf')) for v in (1, 2, 3)}
    items = []
    for o in R:
        wa = words(A[(o['surah'], o['from'])]['text'], fold=True)
        for x in o['ops']:
            if x['v'] == '?':
                items.append((o, 'op', x['a'], x['b'], x))
        for d in o['doubtful']:
            items.append((o, 'chunk', d['text'], '', d))
    crops, notes, cache = [], [], {}
    for n, (o, kind, a, b, raw) in enumerate(items, 1):
        best = (None, -1, None, None)
        for vol, idx in o['pages']:
            key = (vol, idx)
            if key not in cache:
                img = os.path.join(out_dir, f'p{vol}_{idx}.png')
                docs[vol][idx].get_pixmap(dpi=200).save(img)
                cache[key] = (img, ocr_boxes(img, out_dir))
            img, lines = cache[key]
            # The reading with its context words: a bare «لكل» matches
            # anywhere on the page.
            ctx = raw.get('ctx', ['', ''])
            needle = (ctx[0] + ' ' + (a or b) + ' ' + ctx[1]).split()
            at, score = best_line(lines, needle)
            if at is not None and score > best[1]:
                best = (key, score, at, img)
        key, score, at, img = best
        page = Image.open(img)
        lines = cache[key][1]
        y0 = lines[max(0, at - 1)][0][1] - 8
        y1 = lines[min(len(lines) - 1, at + 2)][0][3] + 8
        crop = page.crop((0, int(y0), page.width, int(y1)))
        crop = crop.resize((1100, int(crop.height * 1100 / crop.width)))
        canvas = Image.new('RGB', (1100, crop.height + 30), 'white')
        canvas.paste(crop, (0, 30))
        ImageDraw.Draw(canvas).text((6, 4), f'#{n}  {o["surah"]}:{o["from"]}-{o["to"]}  vol {key[0]} pdf p{key[1]}', fill='red')
        crops.append(canvas)
        notes.append(f'#{n} {o["surah"]}:{o["from"]}-{o["to"]} [{kind}] match={score:.2f}\n'
                     f'   A: {a}\n   B: {b}\n')
    for s in range(0, len(crops), 10):
        group = crops[s:s + 10]
        sheet = Image.new('RGB', (1100, sum(c.height for c in group)), 'white')
        y = 0
        for c in group:
            sheet.paste(c, (0, y))
            y += c.height
        sheet.save(os.path.join(out_dir, f'sheet_{s // 10 + 1:03d}.png'))
    io.open(os.path.join(out_dir, 'review.txt'), 'w', encoding='utf-8').write('\n'.join(notes))
    print(f'{len(items)} items, {len(crops)} crops, {(len(crops) + 9) // 10} sheets')


if __name__ == '__main__':
    main()
