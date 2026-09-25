"""Let the printed page decide where the two digital copies of al-Da'as differ.

Witnesses, per book section (parse_irab_daas.py):
  A  Shamela 23584 - the book's own sections, «» around quoted words
  B  e-quran.com `eerab` (the KSU electronic mushaf's copy) - one page per
     ayah, () around quoted words, sometimes the ayah wording added
  P  the printed edition, OCR'd by ocr_irab_daas_print.py

Nothing here rewrites a word. For each place where A and B's commentary
differ, both readings (with three words of context either side) are looked
for in the OCR of the printed pages the section sits on; the closer one wins
if it wins clearly, otherwise the place is left UNDECIDED for a human to read
off the page image. Where A and B agree, P is still measured, so the report
says how often the agreement itself is contradicted by the print.

    py -3 scripts/arbitrate_irab_daas.py   -> scripts/temp_phase1/irab_daas_arbitration.json
"""
import collections
import difflib
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
RAW = os.path.join(ROOT, 'scripts', 'shamela_raw', 'irab_daas.jsonl')

MARKS = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')
FOLD = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ة': 'ه', 'ى': 'ي',
                      'ئ': 'ي', 'ؤ': 'و'})
MARGIN = 0.06   # how much closer to the print one reading must be to win
VOLUME_PAGES = {1: 478, 2: 459, 3: 481}   # counted with pymupdf, 2026-09-25


def words(t, fold=False):
    t = MARKS.sub('', t)
    t = re.sub(r'[^ء-ي\s]', ' ', t)
    if fold:
        t = t.translate(FOLD)
    return t.split()


def commentary_a(t):
    return re.sub(r'«[^»\n]*»|﴿[^﴾]*﴾', ' ', t)


def commentary_b(t):
    return re.sub(r'\([^)\n]*\)|﴿[^﴾]*﴾|«[^»\n]*»', ' ', t)


def best_ratio(needle, hay):
    """Best similarity of `needle` to any same-length window of `hay` (both
    folded word lists), sliding one word at a time."""
    n = len(needle)
    if n == 0 or not hay:
        return 0.0
    s = ' '.join(needle)
    best = 0.0
    for i in range(0, max(1, len(hay) - n + 1)):
        w = ' '.join(hay[i:i + n])
        sm = difflib.SequenceMatcher(None, s, w, autojunk=False)
        if sm.real_quick_ratio() <= best or sm.quick_ratio() <= best:
            continue
        best = max(best, sm.ratio())
    return best


def load_ocr():
    pages = {}
    for l in io.open(os.path.join(T, 'irab_daas_print_ocr.jsonl'), encoding='utf-8'):
        d = json.loads(l)
        pages[(d['vol'], d['idx'])] = words(' '.join(d['lines']), fold=True)
    return pages


def shamela_pages():
    L = {}
    for l in io.open(RAW, encoding='utf-8'):
        d = json.loads(l)
        L[d['pageId']] = d
    return L


def locate(pid, sh, ocr, cache):
    """The PDF page a Shamela page is: its volume from the page-number resets,
    then the OCR page nearest its printed number whose text shares the most
    word trigrams with it (the offset is not constant between volumes)."""
    if pid in cache:
        return cache[pid]
    vol = 1 if pid < 472 else 2 if pid < 925 else 3
    pn = int(sh[pid]['pageNum'])
    ref = words(re.sub(r'<[^>]+>', ' ', sh[pid]['nass']), fold=True)
    grams = set(zip(ref, ref[1:], ref[2:]))
    best, where = -1, None
    for idx in range(pn - 5, pn + 4):
        w = ocr.get((vol, idx))
        if w is None:
            # Not OCR'd yet: judging against the neighbours would pick the
            # wrong page (seen: 2:92-95 matched to p. 39 before p. 40 existed).
            # (Past the last page of a volume is simply not a candidate:
            # the printed volumes have 478, 459 and 481 pages.)
            if 0 <= idx < VOLUME_PAGES[vol]:
                cache[pid] = (None, 0, 0)
                return cache[pid]
            continue
        score = len(grams & set(zip(w, w[1:], w[2:])))
        if score > best:
            best, where = score, (vol, idx)
    cache[pid] = (where, best, len(grams))
    return cache[pid]


def main():
    A = json.load(io.open(os.path.join(T, 'irab_daas.json'), encoding='utf-8'))
    B = {(d['surah'], d['from']): d['b'] for d in
         json.load(io.open(os.path.join(T, 'irab_daas_diff.json'), encoding='utf-8'))}
    ocr = load_ocr()
    sh = shamela_pages()
    cache = {}
    out, stats = [], collections.Counter()
    for r in A:
        pids = range(r['page'], r['page_end'] + 1)
        locs = [locate(p, sh, ocr, cache) for p in pids]
        if any(l[0] is None for l in locs):
            stats['no_ocr_yet'] += 1
            continue
        hay = [w for l in locs for w in ocr[l[0]]]
        # Full texts, quoted words included: the print quotes the ayah words
        # too, so B's Uthmani spellings simply lose to it where they differ.
        wa = words(r['text'], fold=True)
        wb = words(B[(r['surah'], r['from'])], fold=True)
        # A's whole commentary against the print: how well the base text is
        # carried by the page at all (OCR noise sets the ceiling).
        ops = []
        sm = difflib.SequenceMatcher(None, wa, wb, autojunk=False)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag == 'equal':
                continue
            a_txt, b_txt = ' '.join(wa[i1:i2]), ' '.join(wb[j1:j2])
            # Same letters, a space moved: e-quran splits «و الله», «لو لا»,
            # «ب الله» where Shamela and the print have one word. Not a
            # difference in wording; Shamela's spacing stays.
            if a_txt and a_txt.replace(' ', '') == b_txt.replace(' ', ''):
                stats['op_space'] += 1
                continue
            ctx_l, ctx_r = wa[max(0, i1 - 3):i1], wa[i2:i2 + 3]
            ra = best_ratio(ctx_l + wa[i1:i2] + ctx_r, hay)
            rb = best_ratio(ctx_l + wb[j1:j2] + ctx_r, hay)
            verdict = 'A' if ra - rb >= MARGIN else 'B' if rb - ra >= MARGIN else '?'
            # One letter apart is below what a character ratio can separate:
            # Shamela drops the first letter of every word of some quoted
            # ayahs («لكل جهه و وليها» for «ولكل وجهة هو موليها», 2:148). Then
            # the exact word decides - on the page, or not on the page.
            if verdict == '?' and a_txt and b_txt:
                page_words = set(hay)
                a_in = all(w in page_words for w in wa[i1:i2])
                b_in = all(w in page_words for w in wb[j1:j2])
                if a_in != b_in:
                    verdict = 'A' if a_in else 'B'
                    stats['op_exact_word'] += 1
            ops.append({'tag': tag, 'a': ' '.join(wa[i1:i2]), 'b': ' '.join(wb[j1:j2]),
                        'ctx': [' '.join(ctx_l), ' '.join(ctx_r)],
                        'ra': round(ra, 3), 'rb': round(rb, 3), 'v': verdict})
            stats['op_' + verdict] += 1
        # Where A and B AGREE, is the print saying something else? A's text in
        # 8-word chunks; a chunk most of whose words are not on the page at
        # all is measured properly, and kept if it still reads badly.
        present = set(hay)
        doubtful = []
        for c in range(0, len(wa), 8):
            chunk = wa[c:c + 8]
            if sum(w in present for w in chunk) >= 0.75 * len(chunk):
                continue
            ratio = best_ratio(chunk, hay)
            if ratio < 0.8:
                doubtful.append({'at': c, 'text': ' '.join(chunk), 'r': round(ratio, 3)})
        stats['doubtful_chunks'] += len(doubtful)
        stats['chunks'] += (len(wa) + 7) // 8
        stats['sections'] += 1
        out.append({'surah': r['surah'], 'from': r['from'], 'to': r['to'],
                    'pages': [list(l[0]) for l in locs],
                    'page_match': [round(l[1] / max(1, l[2]), 3) for l in locs],
                    'ops': ops, 'doubtful': doubtful})
    json.dump(out, io.open(os.path.join(T, 'irab_daas_arbitration.json'), 'w',
                           encoding='utf-8'), ensure_ascii=False)
    sys.stdout.reconfigure(encoding='utf-8')
    print(dict(stats))
    weak = [o for o in out if min(o['page_match']) < 0.2]
    print(f'sections whose page was located weakly (<20% trigrams): {len(weak)}')


if __name__ == '__main__':
    main()
