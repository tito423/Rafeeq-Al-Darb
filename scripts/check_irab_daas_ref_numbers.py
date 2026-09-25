"""Check every ayah NUMBER in al-Da'as's cross-references against the print.

The Shamela/print arbitration compared words; digits are not words, so the
numbers in «انظر الآية ٢٣» were never checked. This looks each numbered
reference up in the OCR of the printed pages (irab_daas_print_ocr.jsonl): the
quoted words just before the reference are found in the OCR, and the number
printed right after them is compared with Shamela's.

    py -3 scripts/check_irab_daas_ref_numbers.py
      -> adds 'print_number' to scripts/temp_phase1/irab_daas_refs.json:
         'same'      the print has the same number there
         'differs:N' the print has N there (read the page before trusting either)
         'unseen'    the OCR did not give the passage (read the page)
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arbitrate_irab_daas import MARKS, FOLD  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
DIGITS = str.maketrans('٠١٢٣٤٥٦٧٨٩', '0123456789')


def fold(t):
    t = MARKS.sub('', t).translate(FOLD).translate(DIGITS)
    t = re.sub(r'[^ء-ي0-9 ]', ' ', t)
    return re.sub(r'\s+', ' ', t).strip()


def main():
    ocr = ' '.join(fold(' '.join(json.loads(l)['lines']))
                   for l in io.open(os.path.join(T, 'irab_daas_print_ocr.jsonl'), encoding='utf-8'))
    refs = json.load(io.open(os.path.join(T, 'irab_daas_refs.json'), encoding='utf-8'))
    text_of = {(r['surah'], r['ayah_from']): r['text'] for r in
               json.load(io.open(os.path.join(T, 'irab_daas_final.json'), encoding='utf-8'))}
    from collections import Counter
    c = Counter()
    for r in refs:
        if r['how'] != 'number':
            continue
        want = str(r['target_ayah'])
        # anchor: the last words before the number, taken from the quote and
        # the reference sentence; shorten until the OCR has it
        sec = text_of[(r['surah'], r['ayah_from'])]
        at = sec.find(r['ref'])
        head = sec[:at] + re.split(r'[0-9٠-٩]', r['ref'])[0] if at >= 0 else r['quote'] + ' ' + r['ref']
        ctx = fold(head).split()
        found = []
        for n in range(min(len(ctx), 9), 2, -1):
            key = ' '.join(ctx[-n:])
            hits = [m.end() for m in re.finditer(re.escape(key), ocr)]
            if hits and len(hits) <= 2:
                for h in hits:
                    m = re.search(r'\d+', ocr[h:h + 25])
                    if m:
                        found.append(m.group(0))
                break
        if not found:
            r['print_number'] = 'unseen'
        # the OCR glues the ayah-circle digit on («9214» for ٢١٤)
        elif any(f == want or (f.endswith(want) and len(f) == len(want) + 1) for f in found):
            r['print_number'] = 'same'
        else:
            r['print_number'] = 'differs:' + '/'.join(sorted(set(found)))
        c[r['print_number'].split(':')[0]] += 1
    json.dump(refs, io.open(os.path.join(T, 'irab_daas_refs.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    sys.stdout.reconfigure(encoding='utf-8')
    print(dict(c))
    for r in refs:
        if r.get('print_number', 'same') != 'same':
            print(f"  {r['surah']}:{r['ayah_from']} «{r['quote'][:30]}» {r['ref'][:40]} -> {r['target_ayah']} [{r['print_number']}]")


if __name__ == '__main__':
    main()
