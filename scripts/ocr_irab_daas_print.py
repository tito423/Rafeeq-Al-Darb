"""OCR every page of the printed al-Da'as i'rab (Dar al-Namir / Dar al-Farabi,
3 vols, archive.org item i3rb-krn-d3s) with Windows' Arabic OCR.

The printed page is the arbiter where the two digital copies (Shamela 23584 and
e-quran/KSU `eerab`) disagree, and a measure of both where they agree. The OCR
is noisy on the ornamented ayah lines but reads the commentary well (checked by
eye on vol 1 p. 9, vol 2 p. 131, vol 3 p. 277).

Resumable: one JSON line per page in the output, pages already there are
skipped.

    py -3 scripts/ocr_irab_daas_print.py <pdf_dir> [limit]
        -> scripts/temp_phase1/irab_daas_print_ocr.jsonl
"""
import io
import json
import os
import subprocess
import sys
import tempfile
import time

import pymupdf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'scripts', 'temp_phase1', 'irab_daas_print_ocr.jsonl')
PS = os.path.join(ROOT, 'scripts', 'winocr.ps1')
BATCH = 20


def main():
    pdf_dir = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
    have = set()
    if os.path.exists(OUT):
        for l in io.open(OUT, encoding='utf-8'):
            d = json.loads(l)
            have.add((d['vol'], d['idx']))
    todo = []
    for vol in (1, 2, 3):
        doc = pymupdf.open(os.path.join(pdf_dir, f'i3rab-krn-0{vol}.pdf'))
        todo += [(vol, i) for i in range(doc.page_count) if (vol, i) not in have]
    if limit:
        todo = todo[:limit]
    print(f'{len(have)} done, {len(todo)} to OCR', flush=True)
    tmp = tempfile.mkdtemp(prefix='daas_ocr_')
    docs = {v: pymupdf.open(os.path.join(pdf_dir, f'i3rab-krn-0{v}.pdf')) for v in (1, 2, 3)}
    out = io.open(OUT, 'a', encoding='utf-8')
    t0 = time.time()
    for b in range(0, len(todo), BATCH):
        chunk = todo[b:b + BATCH]
        imgs = []
        for vol, i in chunk:
            p = os.path.join(tmp, f'{vol}_{i}.png')
            docs[vol][i].get_pixmap(dpi=200).save(p)
            imgs.append(p)
        txt = os.path.join(tmp, 'out.txt')
        subprocess.run(['powershell', '-ExecutionPolicy', 'Bypass', '-File', PS, txt, *imgs],
                       check=True, capture_output=True)
        blocks = io.open(txt, encoding='utf-8').read().split('=== ')[1:]
        for (vol, i), blk, img in zip(chunk, blocks, imgs):
            lines = blk.split('\n')[1:]
            # The OCR returns each right-to-left line with its words in
            # left-to-right order; put them back in reading order.
            lines = [' '.join(reversed(l.split())) for l in lines if l.strip()]
            out.write(json.dumps({'vol': vol, 'idx': i, 'lines': lines},
                                 ensure_ascii=False) + '\n')
            out.flush()
            os.remove(img)
        done = b + len(chunk)
        rate = (time.time() - t0) / done
        print(f'  {done}/{len(todo)}  {rate:.2f} s/page', flush=True)


if __name__ == '__main__':
    main()
