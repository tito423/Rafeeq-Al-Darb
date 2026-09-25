"""Resolve al-Da'as's cross-references («سبق إعرابها», «انظر الآية ٢٣») to the
section they point at, so the app can show that i'rab under the book's line.

Owner's requirement (2026-09-25 23:45): where the book says the i'rab was
given before, SHOW it. The book's own sentence stays; the target section is
rendered under it. A target is taken ONLY from:
  1. an ayah number the book writes («الآية ٢٣», «رقم 10 من هذه السورة»,
     «في أول سورة البقرة»), in the same surah unless another is named;
  2. «الآية السابقة» / «قبلها» -> the previous ayah;
  3. the quoted words just before the reference -> the NEAREST EARLIER ayah
     whose text contains the same words (compared as a consonant skeleton,
     because the book quotes in standard spelling and the mushaf is Uthmani).
     Only for quotes of 2+ words; one word occurs everywhere.
Everything else is written to the report for the owner - never guessed.

    py -3 scripts/resolve_irab_daas_refs.py
      -> scripts/temp_phase1/irab_daas_refs.json      resolved references
      -> scripts/temp_phase1/irab_daas_refs_open.json  unresolved, for the owner
"""
import bisect
import io
import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, 'scripts', 'temp_phase1')
MARKS = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')
DIGITS = str.maketrans('٠١٢٣٤٥٦٧٨٩', '0123456789')

VERB = r'(?:سبق|تقدم|تقدّم|مرّ|انظر|ينظر|يراجع|راجع)'
KEY = r'(?:إعراب\S*|اعراب\S*|الآية|الآيتين|الآيتان|الآيات|آية|مثل\S*|مثيل\S*|نظير\S*|كسابقت\S*)'
# the verb, then at most three short words, then what is referred to; the
# match runs on to the end of the clause so a number after it is caught.
# The book writes a number bare («الآية ٢٣»), in guillemets («الآية «٤٧»»)
# or between dashes/slashes («الآية- ٤٧-», «/ ١١٠/»), so a « that opens a
# number does not end the clause.
NUM_Q = r'«\s*[\d٠-٩][\d٠-٩\s\-–،,و/]*»?'
REF = re.compile(VERB + r'\s+(?:\S+\s+){0,3}?' + KEY + r'(?:[^«.\n]|' + NUM_Q + r')*')


def skel(t):
    t = MARKS.sub('', t)
    t = re.sub('[اأإآٱءئؤىيوۥۦ]', '', t).replace('ة', 'ه')
    return re.sub(r'[^ء-ي]', '', t)


def wskel(t):
    """Word-by-word skeleton, space-delimited, so a match cannot straddle a
    word boundary («أمن يبدؤا» must not match «مَنۢ بِيَدِهِۦ»). A word-initial
    alef/hamza is KEPT (as ا): dropping it made «أَمَّنْ» (أم + من) equal to
    the relative «مَن» (27:64 matched 10:34). Inside a word alefs still go,
    since the mushaf writes many as a dagger alef («ٱلصَّٰلِحَٰتِ»). Words
    that are all long vowels (يا، و) vanish on both sides alike."""
    out = []
    # the mushaf writes the vocative joined («يَٰٓأَيُّهَا», «يَٰبَنِىٓ»), the
    # book writes it apart («يا أَيُّهَا»): join it the mushaf's way first
    t = re.sub(r'(?<!\S)([وف]?يا)\s+', r'\1', MARKS.sub('', t))
    for x in t.split():
        head = 'ا' if x[:1] in 'اأإآٱء' else ''
        w = head + skel(x)
        if w:
            out.append(w)
    return ' ' + ' '.join(out) + ' '


# «في الآية السابقة», «ما يشبهها في الآية السابقة», «كسابقتها»
PREV = re.compile(r'^\S+\s+(?:\S+\s+){0,5}?(?:السابقة|كسابقت)')


def shares_wording(src_words, tgt_words, n=2):
    """True when source and target ayahs have n consecutive words in common
    (word skeletons, as wskel gives them)."""
    grams = {tuple(tgt_words[i:i + n]) for i in range(len(tgt_words) - n + 1)}
    return any(tuple(src_words[i:i + n]) in grams for i in range(len(src_words) - n + 1))


def accept(rec, shares):
    """Decide whether a resolved reference is SHOWN in the app, or goes to the
    owner's list instead.

    rec['how']   'number' | 'quote' | 'previous' | 'surah-start'
    rec['quote'] the book's quoted words before the reference ('' if none)
    shares       the source ayah(s) and the target ayah share 2+ words

    Measured on the book: 34:39 says «انظر الآية ١٦» and the print confirms
    ١٦, but 34:16 shares no wording with 34:39 (the phrase is in 34:36);
    7:197 says «(١٠)» and 7:10 is about something else. Showing those would
    put the wrong i'rab under the ayah.
    """
    # TODO(human)


def ref_only(text):
    """True for a section that gives no i'rab of its own: once the references
    and the quoted words are removed, (almost) nothing is left."""
    rest = re.sub(r'«[^«»]*»', ' ', REF.sub(' ', text))
    return len(re.findall(r'[ء-ي]{2,}', rest)) < 3


def main():
    db = sqlite3.connect(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    ayahs = [(s, a, wskel(t)) for s, a, t in
             db.execute('select surah_id, ayah_number, text_clean from ayahs order by surah_id, ayah_number')]
    order = {(s, a): i for i, (s, a, _) in enumerate(ayahs)}
    count = dict(db.execute('select id, ayahs_count from surahs'))
    names = {skel(re.sub(r'^سُورَةُ\s*', '', n)): i for i, n in db.execute('select id, name_ar from surahs')}

    F = json.load(io.open(os.path.join(T, 'irab_daas_final.json'), encoding='utf-8'))
    starts = [(r['surah'], r['ayah_from']) for r in F]
    start_idx = [order[k] for k in starts]

    def section_of(s, a):
        i = bisect.bisect_right(start_idx, order[(s, a)]) - 1
        return starts[i]

    resolved, open_ = [], []
    for r in F:
        s, a0, a1, text = r['surah'], r['ayah_from'], r['ayah_to'], r['text']
        for m in REF.finditer(text):
            ref = m.group(0).strip()
            before = text[:m.start()].rstrip()
            q = re.search(r'«([^«»]+)»\s*[،,]?$', before)
            quote = q.group(1) if q else ''
            tail = ref.translate(DIGITS)
            # the ayah of this section the quoted words belong to (a section
            # can run over several ayahs); the section's first one otherwise
            at = a0
            if quote:
                for k in range(a1, a0 - 1, -1):
                    if wskel(quote) in ayahs[order[(s, k)]][2]:
                        at = k
                        break
            target, how = None, None
            # 1. a number the book writes
            n = re.search(r'(?:الآية|الآيتين|الآيتان|الآيات|آية|رقم)\s*[-/(«]*\s*(\d+)', tail)
            sur = s
            ms = re.search(r'سورة\s+(\S+(?:\s+\S+)?)', tail)
            if ms:
                for w in (ms.group(1), ms.group(1).split()[0]):
                    if skel(w) in names:
                        sur = names[skel(w)]
                        break
                else:
                    sur = None
            if n and sur:
                k = int(n.group(1))
                if 1 <= k <= count[sur]:
                    target, how = (sur, k), 'number'
            elif ms and sur and sur != s and re.search(r'أول|صدر|بداية', tail):
                target, how = (sur, 1), 'surah-start'
            # 2. the previous ayah
            elif PREV.search(ref) and not n:
                prev = at - 1
                if prev >= 1:
                    target, how = (s, prev), 'previous'
            # 3. the quote, matched to the nearest earlier ayah
            # (length is counted on the letters as written: the skeleton of
            # «يا أيها الذين» is only four letters)
            elif (quote and len(quote.split()) >= 2
                  and len(re.sub(r'[^ء-ي]', '', MARKS.sub('', quote))) >= 6):
                sq = wskel(quote)
                here = order[(s, at)]
                for i in range(here - 1, -1, -1):
                    if sq in ayahs[i][2]:
                        target, how = ayahs[i][:2], 'quote'
                        break
            rec = {'surah': s, 'ayah_from': a0, 'ayah_to': a1, 'ref': ref, 'quote': quote}
            if target is None:
                open_.append(rec)
                continue
            tsec = section_of(*target)
            if tsec == (s, a0):
                rec['why'] = f'points into its own section ({target[0]}:{target[1]})'
                open_.append(rec)
                continue
            if order[target] > order[(s, at)]:
                rec['why'] = f'points forward ({target[0]}:{target[1]})'
                open_.append(rec)
                continue
            rec.update(target_surah=target[0], target_ayah=target[1],
                       target_section=list(tsec), how=how)
            src = sum((ayahs[order[(s, k)]][2].split() for k in range(a0, a1 + 1)), [])
            if not accept(rec, shares_wording(src, ayahs[order[target]][2].split())):
                rec['why'] = f'not accepted ({how} -> {target[0]}:{target[1]})'
                open_.append(rec)
                continue
            resolved.append(rec)

    # A target section that is itself only a pointer («سبق إعرابها.») is
    # followed back until a section that gives the i'rab (at most 3 steps).
    text_of = {(r['surah'], r['ayah_from']): r['text'] for r in F}
    first = {}
    for x in resolved:
        first.setdefault((x['surah'], x['ayah_from']), x)
    still = []
    for x in resolved:
        seen, cur = [], tuple(x['target_section'])
        while ref_only(text_of[cur]) and cur in first and len(seen) < 3:
            seen.append(cur)
            cur = tuple(first[cur]['target_section'])
        if ref_only(text_of[cur]):
            x['why'] = f'target {cur} is only a reference and leads nowhere resolved'
            open_.append(x)
            continue
        if seen:
            x['via'] = [list(c) for c in seen]
            x['target_section'] = list(cur)
        still.append(x)
    resolved = still

    json.dump(resolved, io.open(os.path.join(T, 'irab_daas_refs.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    json.dump(open_, io.open(os.path.join(T, 'irab_daas_refs_open.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    sys.stdout.reconfigure(encoding='utf-8')
    from collections import Counter
    print('references:', len(resolved) + len(open_), '| resolved:', len(resolved),
          Counter(x['how'] for x in resolved), '| open:', len(open_))
    print('sections with a reference:', len({(x['surah'], x['ayah_from']) for x in resolved + open_}))


if __name__ == '__main__':
    main()
