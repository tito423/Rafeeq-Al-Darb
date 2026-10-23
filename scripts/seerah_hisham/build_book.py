"""Build the app's seerat_ibn_hisham.json (schema 1) from the OpenITI al-Saqqa text.

Inputs: OpenITI file, CATT cache (segment -> vowelled), app Quran DB.
Body words take the CATT vowels. Runs of >= 4 words that match the mushaf are
split out as 'aya' paragraphs (the reader skips them aloud) and take the
mushaf's own vowels where the letters line up; otherwise they stay bare.
"""
import sys, re, json, sqlite3, gzip, collections, datetime

SRC, CACHE, QDB, OUT, REPORT = sys.argv[1:6]
WORD = re.compile(r'[ء-غف-ي]+')
HARAKAT = re.compile(r'[ً-ْ]')
MAXC = 220

HALF = 110

def halves(words):
    """Long segments are vowelled in pieces of <= HALF chars (2x faster decode)."""
    out, cur, n = [], [], 0
    for w in words:
        if n + len(w) + 1 > HALF and cur:
            out.append(cur); cur, n = [], 0
        cur.append(w); n += len(w) + 1
    if cur: out.append(cur)
    return out

raw = open(SRC, encoding='utf-8').read().split('#META#Header#End#', 1)[1]

# ---- 1. CATT vowels, same segmentation as diacritize.py -------------------
segs, cur, curlen = [], [], 0
for m in re.finditer(r'[ء-غف-ي]+|[.؟!:؛\n#]', raw):
    tok = m.group()
    if WORD.fullmatch(tok):
        if curlen + len(tok) + 1 > MAXC and cur:
            segs.append(cur); cur, curlen = [], 0
        cur.append(tok); curlen += len(tok) + 1
    elif tok in '.؟!:؛' and curlen > 60:
        segs.append(cur); cur, curlen = [], 0
if cur: segs.append(cur)
cache = {}
for line in open(CACHE, encoding='utf-8'):
    k, v = json.loads(line); cache[k] = v
voc = []
model_ok = model_bad = 0
for s in segs:
    k = ' '.join(s)
    if k in cache: out = cache[k].split()
    else: out = ' '.join(cache.get(' '.join(h), ' '.join(h)) for h in halves(s)).split()
    for i, w in enumerate(s):
        o = out[i] if len(out) == len(s) else ''
        if o and HARAKAT.sub('', o) == w: voc.append(o); model_ok += 1
        else: voc.append(w); model_bad += 1
words_plain = WORD.findall(raw)
assert len(voc) == len(words_plain)

# ---- 2. Qur'an index ------------------------------------------------------
def loose(w):
    w = re.sub('[أإآٱ]', 'ا', w); w = w.replace('ى', 'ي').replace('ة', 'ه')
    return w

# KFGQPC Hafs writes tanween as these signs
IQLAB = {'\u064E': '\u064B', '\u064F': '\u064C', '\u0650': '\u064D'}
TANWEEN = {'\u0657': '\u064B', '\u065E': '\u064C', '\u0656': '\u064D'}

def uth_letters(word):
    """Uthmani word -> list of [letter, marks, is_dagger]."""
    out = []
    for ch in word:
        if ch == 'ٱ': out.append(['ٱ', '', False])
        elif '\u0621' <= ch <= '\u064A': out.append([ch, '', False])
        elif ch == '\u0670': out.append(['ا', '', True])  # dagger alif
        elif ch == '\u06E1' and out: out[-1][1] += '\u0652'
        elif ch in TANWEEN and out: out[-1][1] += TANWEEN[ch]
        elif ch == '\u0652': pass  # Hafs round zero = silent letter, no mark
        elif ch in '\u06E2\u06ED' and out and out[-1][1][-1:] in IQLAB:
            out[-1][1] = out[-1][1][:-1] + IQLAB[out[-1][1][-1]]  # iqlab meem = tanween
        elif '\u064B' <= ch <= '\u0651' and out: out[-1][1] += ch
        # other Uthmani signs (small waw/ya, pause marks, ...) are dropped
    return out

def skel(letters):
    return loose(letters).replace('ا', '')

con = sqlite3.connect(QDB)
qwords = []  # (loose skeleton, uthmani word, surah, ayah)
for sid, an, txt in con.execute('select surah_id, ayah_number, text_uthmani from ayahs order by id'):
    for w in txt.split():
        letters = ''.join(u[0] for u in uth_letters(w) if not u[2])
        if letters: qwords.append((skel(letters), w, sid, an))
qskel = [q[0] for q in qwords]
N = 5
index = collections.defaultdict(list)
for i in range(len(qskel) - N + 1):
    index[tuple(qskel[i:i+N])].append(i)

SAME = {('ا', 'ٱ'), ('ي', 'ى'), ('ى', 'ي')}
def transfer(book_word, uth_word):
    """Put the mushaf's vowels on the book's own letters; None if they differ."""
    ul = uth_letters(uth_word); i = j = 0; out = []
    while i < len(book_word):
        b = book_word[i]
        if j < len(ul) and (b == ul[j][0] or (b, ul[j][0]) in SAME):
            out.append(b + ('' if b == 'ا' else ul[j][1])); i += 1; j += 1
        elif j < len(ul) and ul[j][2]:
            j += 1                     # dagger alif the book does not spell
        elif b == 'ا':
            out.append(b); i += 1      # alif the mushaf writes as a sign
        else:
            return None
    while j < len(ul) and ul[j][2]: j += 1
    return ''.join(out) if j == len(ul) else None

sk = [skel(w) for w in words_plain]
quran_word = [None] * len(sk)  # index into qwords
i = 0
spans = []
while i <= len(sk) - N:
    hits = index.get(tuple(sk[i:i+N]))
    if not hits: i += 1; continue
    best_len, best_q = 0, None
    for q in hits:
        L = N
        while i + L < len(sk) and q + L < len(qskel) and sk[i+L] == qskel[q+L]: L += 1
        if L > best_len: best_len, best_q = L, q
    for k in range(best_len): quran_word[i+k] = best_q + k
    spans.append((i, best_len, qwords[best_q][2], qwords[best_q][3]))
    i += best_len

final = list(voc)
q_vowelled = q_bare = 0
for wi, qi in enumerate(quran_word):
    if qi is None: continue
    t = transfer(words_plain[wi], qwords[qi][1])
    if t: final[wi] = t; q_vowelled += 1
    else: final[wi] = words_plain[wi]; q_bare += 1

# ---- 3. Rebuild text with markers around Qur'an runs ----------------------
OPEN, CLOSE = '', ''
it = iter(range(len(final)))
def sub(m):
    wi = next(it); w = final[wi]
    q = quran_word[wi] is not None
    prev_q = wi > 0 and quran_word[wi-1] is not None
    next_q = wi + 1 < len(final) and quran_word[wi+1] is not None
    if q and not prev_q: w = OPEN + w
    if q and not next_q: w = w + CLOSE
    return w
text = WORD.sub(sub, raw)
text = re.sub(r'\s*~~', ' ', text)

pages, toc = [], []
cur_paras = []
vol, page = 1, 1
VOL_NAMES = {1: 'المجلد الأول', 2: 'المجلد الثاني'}

IN_AYA = [False]  # a Qur'an run may carry over into the next paragraph

def split_aya(p):
    """Split a paragraph at Qur'an runs -> list of (text, kind)."""
    out, buf = [], ''
    def emit(t, aya):
        t = t.strip(' ،,')
        if not WORD.search(t): return
        out.append(('{' + t + '}', 'aya') if aya else (t, 'body'))
    for ch in p:
        if ch == OPEN:
            emit(buf, False); buf = ''; IN_AYA[0] = True
        elif ch == CLOSE:
            emit(buf, True); buf = ''; IN_AYA[0] = False
        else:
            buf += ch
    emit(buf, IN_AYA[0])
    return out

def flush_page():
    global cur_paras
    if cur_paras:
        pages.append({'p': page, 'paras': cur_paras})
    cur_paras = []

started_vol = 0
for line in text.split('\n'):
    line = line.strip()
    if not line: continue
    parts = re.split(r'(PageV\d+P\d+)', line)
    content = ' '.join(x for x in parts if not x.startswith('PageV')).strip()
    content = re.sub(r'\s+', ' ', content)
    if vol != started_vol:
        flush_page()
        toc.append({'title': VOL_NAMES.get(vol, f'المجلد {vol}'), 'page': page,
                    'pageIndex': len(pages), 'level': 0})
        started_vol = vol
    m = re.match(r'^###\s*(\|+)\s*(.*)', content)
    if m:
        title = m.group(2).replace(OPEN, '').replace(CLOSE, '').strip().rstrip(' :').strip()
        if title:
            # A heading is only a toc anchor if its page is the current one.
            toc.append({'title': title, 'page': page, 'pageIndex': len(pages),
                        'level': 1})
            cur_paras.append({'t': title, 'k': 'head'})
    elif content.startswith('#'):
        body = content.lstrip('#').strip()
        for t, k in split_aya(body):
            cur_paras.append({'t': t, 'k': k})
    for mk in re.findall(r'PageV(\d+)P(\d+)', line):
        flush_page()
        v, pnum = int(mk[0]), int(mk[1])
        vol, page = v, pnum + 1
        if pnum + 1 > 0 and v != vol: pass
flush_page()
# Page markers close a page; a page with no paragraphs is dropped, so fix
# toc pageIndex values that point past the end.
for t in toc: t['pageIndex'] = min(t['pageIndex'], len(pages) - 1)

# ---- 4. Measure diacritisation the way the catalogue does -----------------
W = re.compile(r'[ء-يٰٱً-ْ]+')
tot = vw = 0
for pg in pages:
    for p in pg['paras']:
        for w in W.findall(p['t']):
            tot += 1; vw += bool(HARAKAT.search(w))
pct = round(vw / tot * 100, 1)

meta = {
    'titleAr': 'السيرة النبوية لابن هشام',
    'authorAr': 'ابن هشام [ت ٢١٣ هـ]',
    'sourceLabel': ('المكتبة الشاملة — السيرة النبوية لابن هشام (ت ٢١٣هـ)، تحقيق مصطفى السقا '
                    'وإبراهيم الأبياري وعبد الحفيظ الشلبي، مكتبة ومطبعة مصطفى البابي الحلبي، '
                    'الطبعة الثانية ١٣٧٥هـ/١٩٥٥م — النص الكامل عن OpenITI، والتشكيل آلي'),
    'shamelaId': 23833,
    'shamelaUrl': 'https://shamela.ws/book/23833',
    'printMatches': True,
    'printReliable': True,
    'editionCard': ('الكتاب: السيرة النبوية لابن هشام\nالمؤلف: عبد الملك بن هشام الحميري المعافري (ت ٢١٣هـ)\n'
                    'تحقيق: مصطفى السقا وإبراهيم الأبياري وعبد الحفيظ الشلبي\n'
                    'الناشر: شركة مكتبة ومطبعة مصطفى البابي الحلبي وأولاده بمصر\n'
                    'الطبعة: الثانية، ١٣٧٥هـ - ١٩٥٥م\nعدد الأجزاء: ٢\n'
                    'ترقيم الصفحات موافق للمطبوع\n'
                    'التشكيل: آلي بنموذج CATT (abjadai/catt)، وتشكيل الآيات المقتبسة من مصحف التطبيق'),
    'pageCount': len(pages),
    'sectionCount': len(toc),
    'builtAt': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'builtFrom': 'scripts/seerah_hisham/build_book.py (OpenITI 0213IbnHisham.SiraNabawiyya.Shamela0023833-ara1 + CATT)',
    'diacritisedBy': 'CATT encoder-decoder (github.com/abjadai/catt, release v2), Qur\'an quotes from quran_local.db',
}
book = {'id': 'seerat_ibn_hisham', 'schema': 1, 'meta': meta, 'toc': toc, 'pages': pages}
data = json.dumps(book, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
with gzip.open(OUT, 'wb', compresslevel=9) as f: f.write(data)
rep = {'words': len(words_plain), 'model_vowelled': model_ok, 'model_missing': model_bad,
       'quran_runs': len(spans), 'quran_words': sum(1 for q in quran_word if q is not None),
       'quran_vowelled_from_mushaf': q_vowelled, 'quran_left_bare': q_bare,
       'pages': len(pages), 'toc': len(toc), 'diacritised_pct': pct,
       'json_bytes': len(data),
       'quran_spans': [{'word': a, 'len': l, 'surah': s, 'ayah': n} for a, l, s, n in spans]}
json.dump(rep, open(REPORT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print({k: v for k, v in rep.items() if k != 'quran_spans'})
