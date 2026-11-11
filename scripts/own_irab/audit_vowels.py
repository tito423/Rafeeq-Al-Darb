"""Deterministic audit of the own i'rab against the mushaf's own vowels.

For every word whose i'rab names an OVERT case sign («وعلامة رفعه الضمة
الظاهرة» ...), the vowel written on the token's last letter must be that
sign. A contradiction is a certain error (the mushaf wins, CLAUDE.md 1.2).
Words carrying an attached pronoun are skipped (the case vowel sits before
the pronoun); the coverage is printed. No model involved: zero quota.

    py -3 audit_vowels.py > out.txt   (UTF-8)
"""
import glob, json, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))

DAMMA = set('ٌࣱُ')
FATHA = set('ًࣰَ')
KASRA = set('ٍࣲِ')
SUKUN = set('ْۡ')
WANT = {'الضمة': DAMMA, 'الفتحة': FATHA, 'الكسرة': KASRA, 'السكون': SUKUN}
SIGN = re.compile(r'وعلامة (?:رفعه|نصبه|جره|جزمه|رفعها|نصبها|جرها|جزمها) (الضمة|الفتحة|الكسرة|السكون)(?= الظاهرة|،|\.|$)')
LETTER = re.compile(r'[ء-يٱ]')
VOWELS = DAMMA | FATHA | KASRA | SUKUN


def last_vowels(tok):
    """Vowel marks on the last letter that carries one (skips a final bare
    alif / alif maqsura after tanween, and pause marks)."""
    letters = [m.start() for m in LETTER.finditer(tok)]
    for k in range(len(letters) - 1, -1, -1):
        i = letters[k]
        j = letters[k + 1] if k + 1 < len(letters) else len(tok)
        marks = set(tok[i + 1:j]) & VOWELS
        if marks and not (k == len(letters) - 1 and tok[i] in 'اىيو' and marks <= SUKUN and k):
            return tok[i], marks
        if marks:  # a silent final alif/ya/waw marked with sukun: look before it
            continue
        if tok[i] not in 'اى':  # a consonant with no vowel: stop here
            return tok[i], set()
    return '', set()


checked = flagged = skipped = 0
out = []
for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
    for w in json.load(open(f, encoding='utf-8'))['words']:
        t, ir = w['w'], w['irab']
        m = SIGN.search(ir)
        if not m:
            continue
        head = ir[:m.start()]
        if 'حُرّك' in ir or 'حرك' in ir or 'المقدرة' in ir[m.start():m.end()+12]:
            skipped += 1
            continue
        if 'ضمير' in head or 'ضمير متصل' in ir[m.end():m.end() + 80]:
            skipped += 1
            continue
        if 'ئِذ' in t or 'ئذ' in t:
            skipped += 1
            continue
        letter, marks = last_vowels(t)
        if not marks:
            skipped += 1
            continue
        checked += 1
        if not (marks & WANT[m.group(1)]):
            flagged += 1
            out.append(f"{os.path.basename(f)[:3]}:{w['a']}\t{t}\t{m.group(1)}\t{ir[:140]}")

print(f'checked {checked}  skipped {skipped}  FLAGGED {flagged}')
for line in out:
    print(line)
