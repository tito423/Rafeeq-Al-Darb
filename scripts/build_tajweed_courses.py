"""Build the tajweed course levels from two complete Shamela books.

    python scripts/build_tajweed_courses.py        (py -3 on the laptop)

The owner, 2026-10-02: «المنهج في التلت مستويات كبير جدا وصعب جدا على
الاطفال … استخدم اسهل وايسر الكتب الكاملة من الشاملة» and then «مش شرط حقوق
ملكية … اهم حاجة بتدرج وسهولة … منهج كامل ميسيبش اي حاجة مهما كانت صغيرة».

Twelve tajweed books were crawled from Shamela (via the laptop; Shamela is
blocked from the cloud) and compared. Two were chosen:

* LEVEL 1 - Shamela 688, «تيسير أحكام التجويد (المستوى الأول)», يحيى
  الغوثاني, دار الغوثاني ط٤ ١٤٢٧هـ. Its preface: «مختصر موجه لصغار الطلبة،
  وقد جعلته على طريقة السؤال والجواب، مراعاة لحال المبتدئين». 29 pages.
* LEVEL 2 - Shamela 7311, «غاية المريد في علم التجويد», عطية قابل نصر
  (ت ١٤٢٤هـ), ط٧. The complete course: from الاستعاذة to همزة الوصل and
  «ما يراعى لحفص», each chapter followed by its questions. 374 sections.

Raw pages: scripts/shamela_raw/{taysir_ahkam_al_tajwid_1,ghayat_al_murid}.jsonl
(the API's responses, verbatim). Output: rafeeq_app/assets/data/tajweed/
<id>.json.gz, and scripts/tajweed_courses_report.txt - the evidence.

WHY THIS SCRIPT HAS ITS OWN PARSER. build_book_text.parse_nass turns any
paragraph that is mostly Qur'an into an «aya» paragraph holding ONLY the
Qur'an spans. In these two books that silently deletes the left column of
every example table («القاف\\ {يَقْتُلُونَ}، {يَقْدِرُونَ} \\صغرى» came out as
two bare words). Here a paragraph is a list of spans and nothing is dropped
except Shamela's copy buttons and the «...» placeholder paragraphs.

QUR'AN (CLAUDE.md §1.2, «آيات وحروف القرآن الكريم مفيش فيها هزار»). Every
Qur'an span the book marks is located in the mushaf by its consonant
skeleton (the matcher of build_azkar_hisn.py) and its words are then written
from quran_local.db - the Madinah text the app shows everywhere else - with
the surah and ayah. Shamela's own spelling of these quotes is the simplified
one («مِنْ إِلهٍ» for «مِّنۡ إِلَٰهٍ»), so this is what makes the examples
the mushaf's. A span that cannot be located stops the build unless it is in
OVERRIDES below, pointed at its words in the mushaf by hand, with the reason.
"""
import difflib
import gzip
import html
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_azkar_hisn as Q  # noqa: E402  (relax/words/MARK/load_quran)

ROOT = os.path.join(HERE, '..')
RAW = os.path.join(HERE, 'shamela_raw')
OUT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'tajweed')
REPORT = os.path.join(HERE, 'tajweed_courses_report.txt')

# Spans the skeleton matcher cannot place, pointed at the mushaf by hand.
# key: the book's span text without braces -> (surah, ayah, first word,
# last word), word indexes 0-based inside the ayah; the words themselves are
# then copied from quran_local.db, never typed.
OVERRIDES = {
    # The book discusses the word itself; the mushaf writes it once, with
    # the preposition: al-Ghashiyah 88:22 «لَّسۡتَ عَلَيۡهِم بِمُصَيۡطِرٍ».
    'مُصَيْطِر': (88, 22, 2, 2),
    # The mushaf writes «يا ابن أم» as one word: Taha 20:94.
    'قَالَ يَا ابْنَ أُمَّ لا تَأْخُذْ بِلِحْيَتِي وَلا بِرَأْسِي': (20, 94, 0, 6),
}

COURSES = {
    'taysir_ahkam_al_tajwid_1': {
        'shamelaId': 688,
        'title': 'تيسير أحكام التجويد (المستوى الأول)',
        'author': 'د. يحيى بن عبد الرزاق الغوثاني',
        'edition': 'دار الغوثاني، دمشق، الطبعة الرابعة ١٤٢٧هـ - ٢٠٠٦م',
        # Lessons start at these paragraphs (text the paragraph begins with).
        # The author's preface (p.3) is not a lesson.
        'lessons': [
            ('مقدمات وتعريفات', 'مقدّمات وتعريفات'),
            ('أحكام النون الساكنة والتنوين', 'أحكام النّون السّاكنة والتّنوين'),
            ('أحكام الميم الساكنة', 'أحكام الميم السّاكنة'),
            ('المد: تعريفه وحروفه وأنواعه', 'أحكام المدّ'),
            ('المد الأصلي: الطبيعي والبدل والعوض والصلة', '١ - المدّ الطّبيعيّ'),
            ('المد الفرعي: المتصل والمنفصل واللازم والعارض واللين',
             'ب - المدّ الفرعيّ'),
            ('القلقلة', 'القلقلة'),
            ('أقسام المد اللازم', 'أقسام المدّ اللاّزم'),
            ('أحكام الراءات', 'أحكام الرّاءات'),
            ('الوقف والابتداء', 'الوقف والابتداء'),
            ('السكت عند حفص', 'السّكت في مواضع خاصّة لحفص عن عاصم'),
        ],
        'end': None,
    },
    'ghayat_al_murid': {
        'shamelaId': 7311,
        'title': 'غاية المريد في علم التجويد',
        'author': 'عطية قابل نصر (ت ١٤٢٤هـ)',
        'edition': 'القاهرة، الطبعة السابعة مزيدة ومنقحة',
        # Lessons start at the section whose Shamela title is this; the
        # prefaces before the first one, and the references and index after
        # 'END', are not lessons.
        'lessons': [
            ('مدخل إلى علم التجويد وآداب التلاوة', 'مدخل إلى علم التجويد'),
            ('لمحة عن تاريخ التجويد والقراءات',
             'ثانيا: لمحة موجزة عن تاريخ التجويد والقراءات'),
            ('الإمام عاصم وراويه حفص', 'ترجمة الإمام عاصم'),
            ('أقسام التجويد ومعناه واللحن', 'اهتمام الأمة الإسلامية بعلم التجويد'),
            ('الاستعاذة', 'الاستعاذة'),
            ('البسملة', 'البسملة'),
            ('النون الساكنة والتنوين', 'أحكام النون الساكنة والتنوين'),
            ('الإظهار الحلقي', 'الحكم الأول الإظهار الحلقي'),
            ('الإدغام', 'الحكم الثاني الإدغام'),
            ('الإقلاب', 'الحكم الثالث الإقلاب'),
            ('الإخفاء الحقيقي', 'الحكم الرابع الإخفاء'),
            ('النون والميم المشددتان والغنة', 'حكم النون والميم المشددتين'),
            ('أحكام الميم الساكنة', 'أحكام الميم الساكنة'),
            ('أحكام اللامات السواكن', 'حكم اللامات السواكن'),
            ('المد والقصر والمد الأصلي', 'المد والقصر'),
            ('المد الفرعي: المتصل والمنفصل', 'المد الفرعي'),
            ('مد البدل والعارض للسكون', 'المد البدل'),
            ('المد اللازم وأقسامه', 'المد اللازم'),
            ('مراتب المدود وتنبيهات وألقابها', 'مراتب المدود'),
            ('مخارج الحروف', 'مخارج الحروف'),
            ('صفات الحروف', 'صفات الحروف'),
            ('التفخيم والترقيق', 'التفخيم والترقيق'),
            ('المتماثلان والمتقاربان والمتجانسان والمتباعدان',
             'المتماثلان والمتقاربان والمتجانسان والمتباعدان'),
            ('الوقف على أواخر الكلم', 'الوقف على أواخر الكلم وأنواعه'),
            ('التقاء الساكنين', 'حكم التقاء الساكنين'),
            ('الحذف والإثبات', 'الحذف والإثبات'),
            ('هاء الكناية', 'هاء الكناية'),
            ('الوقف والابتداء والسكت والقطع', 'الوقف والابتداء'),
            ('المقطوع والموصول', 'المقطوع والموصول وحكم الوقف عليهما'),
            ('هاء التأنيث المرسومة تاء', 'هاء التأنيث التي يوقف عليها بالتاء'),
            ('همزتا الوصل والقطع', 'همزتا الوصل والقطع وحكم البدء بهما'),
            ('ما يراعى لحفص، وخاتمة الكتاب', 'ما يراعى لحفص'),
        ],
        'end': 'المراجع',
    },
}

# --- one raw page -> paragraphs of spans --------------------------------------
HAMESH = re.compile(
    r'<(?P<tag>div|p)\b[^>]*class="[^"]*\bhamesh\b[^"]*"[^>]*>(?P<body>.*?)</(?P=tag)>',
    re.S)
P = re.compile(r'<p\b[^>]*>(.*?)</p>', re.S)
BTN = re.compile(r'<a[^>]*class="[^"]*btn_tag[^"]*"[^>]*>.*?</a>', re.S)
ANCHOR = re.compile(r'<span[^>]*class="[^"]*\banchor\b[^"]*"[^>]*>\s*</span>', re.S)
SPAN = re.compile(r'<span[^>]*class="[^"]*\b(c[2-5])\b[^"]*"[^>]*>(.*?)</span>', re.S)
TAG = re.compile(r'<[^>]+>')


def clean(s):
    s = html.unescape(TAG.sub('', s)).replace('\r', ' ').replace('\n', ' ')
    return re.sub(r'[ \t ]+', ' ', s)


def spans_of(p_html):
    """[[kind, text]] with kind t (plain), b (bold lead-in), q (Qur'an)."""
    p_html = ANCHOR.sub('', BTN.sub('', p_html))
    out, pos = [], 0
    for m in SPAN.finditer(p_html):
        if m.start() > pos:
            out.append(['t', clean(p_html[pos:m.start()])])
        cls, body = m.group(1), clean(m.group(2))
        out.append(['q' if cls == 'c3' else 'h' if cls == 'c4' else 'b', body])
        pos = m.end()
    if pos < len(p_html):
        out.append(['t', clean(p_html[pos:])])
    # merge neighbours of one kind, drop empties
    merged = []
    for k, t in out:
        if not t:
            continue
        if merged and merged[-1][0] == k and k != 'q':
            merged[-1][1] += t
        else:
            merged.append([k, t])
    if merged:
        merged[0][1] = merged[0][1].lstrip()
        merged[-1][1] = merged[-1][1].rstrip()
    return [s for s in merged if s[1]]


def notes_of(raw):
    notes = []
    for m in HAMESH.finditer(raw):
        body = html.unescape(TAG.sub('', m.group('body').replace('<br>', '\n')))
        for line in re.split(r'[\r\n]+', body):
            line = line.strip()
            if line:
                notes.append(line)
    return notes


# A footnote pointer: Arabic-Indic digits glued to the end of a word, or after
# a closing brace/quote, followed by punctuation, a space or the end.
NOTE_REF = re.compile(
    r'(?:(?<=[ء-ْٰ»"])|(?<=\}) ?)([١-٩][٠-٩]?)(?=[\s،.:؛)\]]|$)')


AFTER_QUOTE = re.compile(r' ?([١-٩][٠-٩]?)(?=[\s،.:؛)\]]|$)')


def page(raw_line):
    d = json.loads(raw_line)
    raw = d.get('nass') or ''
    notes = notes_of(raw)
    body = HAMESH.sub('', raw)
    paras = []
    for ph in P.findall(body):
        s = spans_of(ph)
        text = ''.join(t for _, t in s).strip()
        if not text or re.fullmatch(r'[.…\s]+', text):
            continue
        paras.append(s)
    return {
        'pid': d['pageId'], 'p': int(d.get('pageNum') or 0),
        'title': (d.get('title') or '').strip(), 'paras': paras, 'notes': notes,
    }


def load_raw(name):
    with io.open(os.path.join(RAW, name + '.jsonl'), encoding='utf-8') as f:
        return [page(l) for l in f if l.strip()]


# --- Qur'an -------------------------------------------------------------------
QURAN = Q.load_quran()
_IDX = {}
for _sid, _ws in QURAN.items():
    rel = [(i, Q.relax(Q.MARK.sub('', w))) for i, (_, w) in enumerate(_ws)]
    _IDX[_sid] = [r for r in rel if r[1]]

_UTH = str.maketrans({'ۡ': 'ْ', 'ٰ': 'ا', 'ٱ': 'ا', 'ٓ': '', 'ۖ': '', 'ۗ': '',
                      'ۚ': '', 'ۛ': '', 'ۘ': '', 'ۙ': '', 'ٖ': 'ٍ', 'ٌ': 'ٌ',
                      'ٗ': 'ٌ', 'ࣰ': 'ً', 'ࣱ': 'ٌ', 'ࣲ': 'ٍ', 'ۢ': '', 'ۭ': ''})


def locate(seg):
    """Every place whose skeleton matches, widened to the book's leading and
    trailing words that HAVE no skeleton («أو», «أيا», «وإياي»): matching skips
    them, and a quotation about «أَوِ ٱخۡرُجُواْ» must not lose its «أَوِ»."""
    bw = Q.words(seg)
    key = [k for k in (Q.relax(w) for w in bw) if k]
    if not key:
        return []
    lead = []
    for w in bw:
        if Q.relax(w):
            break
        lead.append(w)
    trail = []
    for w in reversed(bw):
        if Q.relax(w):
            break
        trail.insert(0, w)
    hits = []
    for sid, rel in _IDX.items():
        keys = [r[1] for r in rel]
        ws = QURAN[sid]
        for i in range(len(keys) - len(key) + 1):
            if keys[i] == key[0] and keys[i:i + len(key)] == key:
                a, z = rel[i][0], rel[i + len(key) - 1][0]
                for w in reversed(lead):
                    if a > 0 and letters(ws[a - 1][1]) == letters(w):
                        a -= 1
                for w in trail:
                    if z + 1 < len(ws) and letters(ws[z + 1][1]) == letters(w):
                        z += 1
                hits.append((sid, ws[a:z + 1]))
    return hits


def letters(s):
    """Letters with the long vowels kept but alif/hamza spelling relaxed:
    «ينأون» and «وينٔون» differ here (a whole و), «الصلاة»/«الصلوة» do not
    differ in anything but the alif."""
    s = Q.MARK.sub('', s)
    s = re.sub('[أإآٱ]', 'ا', s).replace('ى', 'ي').replace('ة', 'ه')
    s = s.replace('ئ', 'ي').replace('ؤ', 'و')
    return re.sub('[اء\u0640\s]', '', s)


def _name(s):
    s = Q.MARK.sub('', s)
    s = re.sub('[أإآٱ]', 'ا', s).replace('ى', 'ي').replace('ة', 'ه')
    s = re.sub(r'^سوره\s+', '', s.strip())
    return re.sub(r'\s+', ' ', s)


def _surah_names():
    import sqlite3
    db = sqlite3.connect(os.path.join(ROOT, 'rafeeq_app', 'assets', 'data',
                                      'quran_local.db'))
    names = {_name(n): sid for sid, n in db.execute('SELECT id, name_ar FROM surahs')}
    db.close()
    # The other names the books use for a surah.
    for alt, sid in (('الدهر', 76), ('بني اسرائيل', 17), ('المومن', 40),
                     ('غافر', 40), ('فصلت', 41), ('حم السجده', 41),
                     ('السجده', 32), ('الحجر', 15), ('محمد', 47),
                     ('القتال', 47), ('الطلاق', 65), ('التحريم', 66),
                     ('براءه', 9), ('التوبه', 9), ('المسد', 111),
                     ('تبت', 111), ('الاخلاص', 112), ('الملك', 67),
                     ('تبارك', 67), ('النبا', 78), ('عم', 78)):
        names.setdefault(alt, sid)
    return names


SURAH = _surah_names()
def _ayahs():
    import sqlite3
    db = sqlite3.connect(Q.QDB)
    out = {}
    for sid, text in db.execute(
            'SELECT surah_id, text_uthmani FROM ayahs ORDER BY id'):
        out.setdefault(sid, []).append(text)
    db.close()
    return out


# Each ayah's text exactly as the app's database holds it.
AYAH = _ayahs()
_AR = str.maketrans('٠١٢٣٤٥٦٧٨٩', '0123456789')
# «سورة الأنعام: ٢٦» / «الأنعام: الآية: ٢٦» / «سورة ق: ٣٣».
_REF = re.compile(r'(?:سورة\s+)?([^\d٠-٩:،()]+?)\s*[:،]\s*(?:الآية\s*:?\s*|الآيتان\s*:?\s*)?([٠-٩]+)')
_MENTION = re.compile(r'سورة\s+((?:آل\s+|بني\s+)?[^\s،.:؛)]+)')


def surah_of(name):
    return SURAH.get(_name(name)) or SURAH.get(_name('ال' + name))


def note_ref(note):
    """(surah, ayah) a footnote points to, or None."""
    m = _REF.match(re.sub(r'^[٠-٩]+\s*', '', note.strip()))
    if not m:
        return None
    sid = surah_of(m.group(1))
    return (sid, int(m.group(2).translate(_AR))) if sid else None


def best(seg, hits, hint=None):
    """Among places with the same skeleton: first those whose letters are the
    book's own (a quotation of «ينأون» must not land on «وينأون» when the
    plain word exists), then the one whose vowels are closest to the book's
    - e.g. the same tanween before the same letter."""
    book = re.sub(r'[{}]', '', seg)
    lb = letters(book)

    def score(h):
        mush = ' '.join(w for _, w in h[1])
        ayahs = {n for n, _ in h[1]}
        return (
            # The book's own pointer: its footnote, or «سورة …» just before.
            0 if not hint else 2 if h[0] == hint[0] and (
                hint[1] is None or hint[1] in ayahs) else 1 if h[0] == hint[0] else 0,
            difflib.SequenceMatcher(None, lb, letters(mush), autojunk=False).ratio(),
            difflib.SequenceMatcher(None, book, mush.translate(_UTH),
                                    autojunk=False).ratio(),
        )
    return max(hits, key=score)


class QuranLog:
    def __init__(self):
        self.lines = []
        self.diffs = []
        self.count = 0


def quran_spans(seg, log, where, hint=None):
    """The book's {…} span -> spans in mushaf text, ayah numbers between."""
    inner = seg.strip()
    if inner.startswith('{') and inner.endswith('}'):
        inner = inner[1:-1]
    key = inner.strip(' .،')
    if key in OVERRIDES:
        sid, ayah, first, last = OVERRIDES[key]
        text = ' '.join(AYAH[sid][ayah - 1].split()[first:last + 1])
        log.lines.append('%s  OVERRIDE %d:%d  «%s» -> «%s»' % (where, sid, ayah, key, text))
        log.count += 1
        return [['q', text, '%d:%d' % (sid, ayah)]]
    hits = locate(inner)
    if not hits:
        raise SystemExit('NOT LOCATED in the mushaf (%s): %s' % (where, seg))
    sid, ws = best(inner, hits, hint)
    if hint and hint[1] and (sid != hint[0] or hint[1] not in {n for n, _ in ws}):
        log.diffs.append('%s  %d:%d  the book points to %d:%d  «%s»' % (
            where, sid, ws[0][0], hint[0], hint[1], inner))
    mushaf = ' '.join(w for _, w in ws)
    if letters(mushaf) != letters(inner):
        # The book quoted a part of a word, or dropped a «و»; the mushaf's
        # whole words are what is shown. Listed for review.
        log.diffs.append('%s  %d:%d  book «%s»  mushaf «%s»' % (
            where, sid, ws[0][0], inner, mushaf))
    out, cur, prev = [], [], None
    for n, w in ws:
        if prev is not None and n != prev:
            out.append(['q', ' '.join(cur), '%d:%d' % (sid, prev)])
            out.append(['t', ' ﴿%s﴾ ' % ''.join('٠١٢٣٤٥٦٧٨٩'[int(c)] for c in str(prev))])
            cur = []
        cur.append(w)
        prev = n
    out.append(['q', ' '.join(cur), '%d:%d' % (sid, prev)])
    log.lines.append('%s  %d:%d%s  «%s» -> «%s»  (%d place%s)' % (
        where, sid, ws[0][0], '-%d' % ws[-1][0] if ws[-1][0] != ws[0][0] else '',
        inner, ' '.join(w for _, w in ws), len(hits), '' if len(hits) == 1 else 's'))
    log.count += 1
    return out


# --- paragraphs -> blocks -----------------------------------------------------
def classify(spans):
    text = ''.join(t for _, t in spans).strip()
    if len(spans) == 1 and spans[0][0] == 'h':
        return 'head', [['t', text.strip('[] ')]]
    if re.match(r'^س\s*-', text):
        # «ما تعريف الإظهار. . .؟»: the dots are the print's way of leaving
        # a blank before the mark; on a phone they read as a typo.
        return 'q', [[k, re.sub(r'\s*(?:\.\s*){2,}؟', '؟', t), *r]
                     for k, t, *r in strip_prefix(spans, r'^س\s*-\s*')]
    if re.match(r'^ج\s*-', text):
        return 'a', strip_prefix(spans, r'^ج\s*-\s*')
    if '\\' in text:
        return 'row', spans
    if ' ... ' in text and not any(k == 'q' for k, _ in spans):
        return 'verse', spans
    return 'p', spans


def strip_prefix(spans, pat):
    spans = [list(s) for s in spans]
    spans[0][1] = re.sub(pat, '', spans[0][1])
    if not spans[0][1]:
        spans = spans[1:]
    return spans


def mark_notes(spans, n_notes):
    """Glued footnote digits -> ['n', '١'] spans; only numbers this page has."""
    if not n_notes:
        return spans
    out = []
    for k, t, *ref in spans:
        if k != 't' and k != 'b':
            out.append([k, t, *ref])
            continue
        pos = 0
        # A pointer right after a Qur'an quote: the closing brace is inside
        # the quote's span, so the digits open this one («} ٢،»).
        refs = list(NOTE_REF.finditer(t))
        if out and out[-1][0] == 'q':
            m = AFTER_QUOTE.match(t)
            if m:
                refs.insert(0, m)
        for m in refs:
            num = int(''.join(str('٠١٢٣٤٥٦٧٨٩'.index(c)) for c in m.group(1)))
            if not 1 <= num <= n_notes:
                continue
            if m.start() > pos:
                out.append([k, t[pos:m.start()].rstrip(' ') if t[m.start()] == ' ' else t[pos:m.start()]])
            out.append(['n', m.group(1)])
            pos = m.end()
        if pos < len(t):
            out.append([k, t[pos:]])
    return [s for s in out if s[1]]


def build(cid, spec, report):
    pages = load_raw(cid)
    log = QuranLog()
    # where each lesson starts: (page index, paragraph index)
    starts = []
    for title, anchor in spec['lessons']:
        found = None
        for pi, pg in enumerate(pages):
            if cid == 'ghayat_al_murid':
                if pg['title'] == anchor and (not starts or pi > starts[-1][1][0]):
                    found = (pi, 0)
                    break
            else:
                for j, s in enumerate(pg['paras']):
                    t = ''.join(x[1] for x in s).strip().strip('[]')
                    if t.startswith(anchor) and len(t) < len(anchor) + 12 and \
                            (not starts or (pi, j) > starts[-1][1]):
                        found = (pi, j)
                        break
                if found:
                    break
        if not found:
            raise SystemExit('%s: lesson start not found: %s' % (cid, anchor))
        starts.append((title, found))
    end = (len(pages), 0)
    if spec['end']:
        for pi, pg in enumerate(pages):
            if pg['title'] == spec['end']:
                end = (pi, 0)
                break
        else:
            raise SystemExit('%s: end not found' % cid)

    lessons = []
    for li, (title, (pi0, j0)) in enumerate(starts):
        pi1, j1 = starts[li + 1][1] if li + 1 < len(starts) else end
        blocks, exercises = [], False
        for pi in range(pi0, min(pi1 + 1, len(pages))):
            pg = pages[pi]
            a = j0 if pi == pi0 else 0
            z = j1 if pi == pi1 else len(pg['paras'])
            if pi == pi1 and z == 0:
                break
            # A Ghaya section titled أسئلة is the chapter's exercise set.
            exercises = pg['title'].startswith('أسئلة') or pg['title'] == 'نموذج من الأسئلة'
            last_head = blocks[-1]['s'][0][1] if blocks and blocks[-1]['k'] == 'head' else None
            if cid == 'ghayat_al_murid' and pg['title'] and pg['title'] != 'مدخل' \
                    and pi != pi0 and pg['title'] != last_head and a == 0:
                blocks.append({'k': 'exh' if exercises else 'head',
                               's': [['t', 'أسئلة' if exercises else pg['title']]]})
            for j in range(a, z):
                spans = pg['paras'][j]
                k, spans = classify(spans)
                text = ''.join(x[1] for x in spans).strip()
                if k == 'head' and text in ('مدخل', 'أسئلة') or \
                        (k == 'head' and text == title) or \
                        (k == 'head' and blocks and blocks[-1]['s'][0][1] == text):
                    continue
                if pi == pi0 and j == j0 and text.rstrip(':') in (title, spec['lessons'][li][1]):
                    continue
                spans = mark_notes(spans, len(pg['notes']))
                where = '%s p.%d' % (cid, pg['p'])
                new = []
                mention = None
                for si, s in enumerate(spans):
                    if s[0] in ('t', 'b'):
                        for m in _MENTION.finditer(s[1]):
                            mention = surah_of(m.group(1)) or mention
                    if s[0] == 'q':
                        hint = None
                        nxt = spans[si + 1:si + 3]
                        for x in nxt:
                            if x[0] == 'n':
                                num = int(x[1].translate(_AR))
                                if num <= len(pg['notes']):
                                    hint = note_ref(pg['notes'][num - 1])
                                break
                            if x[0] != 't' or x[1].strip(' ،.'):
                                break
                        if not hint and mention:
                            hint = (mention, None)
                        new.extend(quran_spans(s[1], log, where, hint))
                    else:
                        new.append(s)
                if exercises and k == 'p':
                    k = 'ex'
                blocks.append({'k': k, 's': new})
            if pg['notes'] and a < z:
                # The notes these paragraphs point to. A note nothing on its
                # page points to belonged to an example table Shamela's text
                # does not have (the Ghaya's tables of النون والميم واللام
                # are missing from it): when it names an ayah, that ayah is
                # shown, from the mushaf, as the lesson's example. A note
                # whose pointer the parser cannot see (inside a quotation)
                # stays a note.
                here = {int(x[1].translate(_AR)) for j in range(a, z)
                        for x in mark_notes(pg['paras'][j], len(pg['notes']))
                        if x[0] == 'n'}
                anywhere = {int(x[1].translate(_AR)) for para in pg['paras']
                            for x in mark_notes(para, len(pg['notes']))
                            if x[0] == 'n'}
                last = z == len(pg['paras'])
                kept, refs = [], []
                for i, n in enumerate(pg['notes'], 1):
                    if i in here:
                        kept.append(['t', n])
                    elif i not in anywhere and last:
                        r = note_ref(n)
                        if r and r[1] <= len(AYAH.get(r[0], ())):
                            refs.append(['r', AYAH[r[0]][r[1] - 1], '%d:%d' % r])
                        else:
                            kept.append(['t', n])
                if kept:
                    blocks.append({'k': 'notes', 's': kept})
                if refs:
                    blocks.append({'k': 'refs', 's': refs})
        lessons.append({'title': title, 'blocks': blocks})

    doc = {
        'id': cid,
        'schema': 1,
        'title': spec['title'],
        'author': spec['author'],
        'edition': spec['edition'],
        'shamelaId': spec['shamelaId'],
        'shamelaUrl': 'https://shamela.ws/book/%d' % spec['shamelaId'],
        'lessons': lessons,
    }
    os.makedirs(OUT, exist_ok=True)
    raw = json.dumps(doc, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    path = os.path.join(OUT, cid + '.json.gz')
    with open(path, 'wb') as f:
        f.write(gzip.compress(raw, mtime=0))
    report.write('== %s: %d lessons, %d Qur\'an spans written from the mushaf, '
                 '%d bytes json, %d gz\n' % (cid, len(lessons), log.count, len(raw),
                                            os.path.getsize(path)))
    for l in lessons:
        report.write('   %-55s %4d blocks\n' % (l['title'], len(l['blocks'])))
    report.write('-- %d spans whose mushaf words differ in letters from the '
                 'book\'s quotation (the mushaf is shown):\n' % len(log.diffs))
    for line in log.diffs:
        report.write('   ' + line + '\n')
    report.write('-- every span:\n')
    for line in log.lines:
        report.write(line + '\n')
    report.write('\n')
    print(cid, len(lessons), 'lessons', log.count, 'quran spans')


def main():
    with io.open(REPORT, 'w', encoding='utf-8') as report:
        report.write('Generated by scripts/build_tajweed_courses.py - do not hand-edit.\n'
                     'Every Qur\'an span: book page, surah:ayah, the book\'s text -> '
                     'the mushaf text written in its place.\n\n')
        for cid, spec in COURSES.items():
            build(cid, spec, report)


if __name__ == '__main__':
    main()
