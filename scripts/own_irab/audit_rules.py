"""Free grammar-invariant audit of the own i'rab (SAMIN_REVIEW.md step 0).

Two classes of contradiction, no model involved:
  ROLECASE  a clause names a role whose case is fixed (فاعل -> رفع, مفعول به ->
            نصب, مضاف إليه -> جر ...) and, in the same clause, a different case.
  NEIGHBOUR the previous word is a jazm / nasb / jarr particle on its own and
            this word's i'rab contradicts it (a مضارع after لم not مجزوم, a noun
            after حرف جر not مجرور).
A flag is a candidate, not an error: it is read before anything changes.

    py -3 audit_rules.py > out.tsv   (UTF-8)
"""
import glob, json, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))

CASE = re.compile(r'(?:في محل |محل )?(رفع|نصب|جر|جزم)\b|(مرفوع|منصوب|مجرور|مجزوم)')
NORM = {'مرفوع': 'رفع', 'منصوب': 'نصب', 'مجرور': 'جر', 'مجزوم': 'جزم'}
# role at the head of a clause -> its fixed case
ROLES = [
    (r'نائب فاعل', 'رفع'), (r'فاعل', 'رفع'), (r'مبتدأ', 'رفع'),
    (r'خبر المبتدأ|خبر مرفوع', 'رفع'), (r'اسم «?(?:كان|أصبح|صار|ليس|ظل|بات|أمسى|أضحى|مازال|ما زال|ما دام|يكون|تكون|كانوا|يكن|تكن)»?', 'رفع'),
    (r'خبر «?(?:إن|إنّ|أن|أنّ|لكن|لكنّ|ليت|لعل|كأن|كأنّ)»?', 'رفع'),
    (r'اسم «?(?:إن|إنّ|أن|أنّ|لكن|لكنّ|ليت|لعل|كأن|كأنّ)»?', 'نصب'),
    (r'خبر «?(?:كان|أصبح|صار|ليس|ظل|بات|أمسى|أضحى|مازال|ما زال|ما دام|يكون|تكون|كانوا|يكن|تكن)»?', 'نصب'),
    (r'مفعول (?:به|فيه|لأجله|مطلق|معه)', 'نصب'), (r'حال', 'نصب'), (r'تمييز', 'نصب'),
    (r'مضاف إليه', 'جر'), (r'اسم مجرور', 'جر'),
]
ROLES = [(re.compile(r'^(?:لفظ الجلالة |و?«[^»]+» )?(?:' + p + r')(?=[ ،.»]|$)'), c) for p, c in ROLES]
SKIP = re.compile(r'لفظا|لفظًا|محلا|محلًا|منادى|مستثنى|بدل|نعت|صفة|معطوف|توكيد|المصدر المؤول|جملة|الجملة|شبه|محذوف|تقديره|أو ')


def segments(ir):
    return [s.strip() for s in re.split(r'[،؛.]', ir) if s.strip()]


def own_case(seg):
    m = CASE.search(seg)
    if not m:
        return None
    return m.group(1) or NORM[m.group(2)]


out = []
words = []
for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
    s = os.path.basename(f)[:3]
    for w in json.load(open(f, encoding='utf-8'))['words']:
        words.append((s, w))

for i, (s, w) in enumerate(words):
    ir = w['irab']
    for seg in segments(ir):
        if SKIP.search(seg):
            continue
        for rx, want in ROLES:
            if rx.search(seg):
                got = own_case(seg)
                if got and got != want and not (want == 'نصب' and 'مبني' in seg and got is None):
                    out.append(('ROLECASE', s, w['a'], w['w'], f'{want}≠{got}', seg[:120]))
                break
    if i == 0 or words[i - 1][0] != s:
        continue
    prev = words[i - 1][1]
    pir = prev['irab']
    head = segments(ir)[0] if segments(ir) else ''
    if 'زائد' in pir:
        continue
    if re.match(r'حرف (?:نفي وجزم|جزم|نهي وجزم)|لام الأمر', pir) and head.startswith('فعل مضارع'):
        if 'مجزوم' not in ir and 'جزم' not in ir:
            out.append(('NEIGHBOUR', s, w['a'], w['w'], 'جزم', head[:120]))
    elif re.match(r'حرف (?:نصب|مصدري ونصب|نصب ونفي|نفي ونصب)', pir) and head.startswith('فعل مضارع'):
        if 'منصوب' not in ir and 'مبني' not in head:
            out.append(('NEIGHBOUR', s, w['a'], w['w'], 'نصب', head[:120]))
    elif re.match(r'حرف جر(?: مبني)?[^،]*$', segments(pir)[0] if segments(pir) else '') and len(segments(pir)) <= 2:
        if not re.search(r'مجرور|محل جر|في محل جر|جر ب', ir):
            out.append(('NEIGHBOUR', s, w['a'], w['w'], 'جر', head[:120]))

for o in out:
    print('\t'.join(str(x) for x in o))
from collections import Counter
print(Counter(o[0] for o in out), file=sys.stderr)
