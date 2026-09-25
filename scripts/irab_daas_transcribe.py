"""The 27 sections Shamela damaged are taken from the PRINTED page.

Neither digital copy is clean there (Shamela drops first letters and glues
words; the KSU copy repaired it by hand and some repairs are wrong - 16:33
«تنظرون» for the printed «ينظرون», 12:86 garbled). So these sections are
transcribed by eye from the scan, and each transcription is then checked word
by word against both copies: a word that neither copy has is listed for a
second look, so a typing slip cannot pass unseen.

    py -3 scripts/irab_daas_transcribe.py show <surah> <ayah_from> <pdf_dir> <out.png>
        render the section's printed page(s)
    py -3 scripts/irab_daas_transcribe.py check
        check every transcription in scripts/irab_daas_print_transcriptions.json

The transcriptions are the book's text as printed: «» around the quoted words
(bold in the print), no word added or dropped.
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arbitrate_irab_daas import words  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
OUT = os.path.join(ROOT, 'scripts', 'irab_daas_print_transcriptions.json')


def show(surah, ayah, pdf_dir, out):
    import pymupdf
    from PIL import Image
    arb = {(o['surah'], o['from']): o for o in
           json.load(io.open(os.path.join(T, 'irab_daas_arbitration.json'), encoding='utf-8'))}
    ims = []
    for vol, idx in arb[(surah, ayah)]['pages']:
        doc = pymupdf.open(os.path.join(pdf_dir, f'i3rab-krn-0{vol}.pdf'))
        p = os.path.join(os.path.dirname(out), f'_p{vol}_{idx}.png')
        doc[idx].get_pixmap(dpi=110).save(p)
        ims.append(Image.open(p))
    W = Image.new('RGB', (sum(i.width for i in ims), max(i.height for i in ims)), 'white')
    x = 0
    for i in reversed(ims):          # right-to-left book: first page on the right
        W.paste(i, (x, 0))
        x += i.width
    W.save(out)
    print(out, [tuple(p) for p in arb[(surah, ayah)]['pages']])


def check():
    A = {(r['surah'], r['from']): r['text'] for r in
         json.load(io.open(os.path.join(T, 'irab_daas.json'), encoding='utf-8'))}
    B = {(d['surah'], d['from']): d['b'] for d in
         json.load(io.open(os.path.join(T, 'irab_daas_diff.json'), encoding='utf-8'))}
    tr = json.load(io.open(OUT, encoding='utf-8')) if os.path.exists(OUT) else {}
    sys.stdout.reconfigure(encoding='utf-8')
    for k, text in tr.items():
        s, a = (int(v) for v in k.split(':'))
        known = set(words(A[(s, a)], fold=True)) | set(words(B[(s, a)], fold=True))
        new = [w for w in words(text, fold=True) if w not in known]
        print(f'{k}: {len(words(text))} words, {len(new)} in neither copy: {new}')


if __name__ == '__main__':
    if sys.argv[1] == 'show':
        show(int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5])
    else:
        check()
