"""One compact reading sheet for a chunk: show.py + books_range.py in one run,
with every book passage cut down to the ayahs asked for.

Al-Da'as, al-Jadwal and Darwish all group ayahs, so a chunk boundary used to
reprint a whole group (Darwish 25:45-57 came back three times while 25:41-59
was written). Here each passage is split at the Qur'an words it quotes
(al-Da'as «...», Darwish (...)) and each piece is placed on its ayah by
matching the quote, in order, against the mushaf tokens; al-Jadwal is split
at its own «(42)» ayah markers. Only pieces on ayahs a0..a1 are printed.
A piece whose quote cannot be placed stays with the piece before it, so
nothing inside the range is dropped.

    py -3 scripts/own_irab/sheet.py 25 60 67
    py -3 scripts/own_irab/sheet.py 25 60 67 --full   (no cutting)"""
import io, os, re, sqlite3, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from books import get

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
H = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data')
MARKS = re.compile('[ً-ٰٟۖ-ۭـ]')


def skel(w):
    """Consonant skeleton: drops vowels, Uthmani marks, alif/waw/ya/hamza
    so «السماوات» (mushaf) and «السموات» (a book) meet."""
    w = MARKS.sub('', w)
    w = w.translate(str.maketrans('ٱأإآىةؤئ', 'اااايهوي'))
    return re.sub('[^ب-ي]|[اويء]', '', w.replace('ا', ''))


def ayah_tokens(s):
    q = sqlite3.connect(os.path.join(DATA, 'quran_local.db'))
    out = []
    for a, txt in q.execute('select ayah_number, text_uthmani from ayahs where surah_id=? order by ayah_number', (s,)):
        out += [(a, t) for t in txt.split() if any('ء' <= c <= 'ي' for c in t)]
    return out


def place(pieces, toks, start, back=0):
    """pieces: [(quote, text)] in book order -> [(ayah, text)]. A quote is
    placed at the first token at/after the cursor where up to three of its
    words match in a row (then, failing that, its first word alone); `back`
    lets the first quote sit before `start` (a Darwish group fetched for a
    later ayah). Unplaced pieces inherit the previous ayah."""
    sk = [skel(t) for _, t in toks]

    def eq(k, w, first):
        return k < len(sk) and sk[k] and (sk[k] == w or (first and len(w) > 1 and sk[k].endswith(w)))

    cur, ayah, out = max(0, start - back), toks[start][0] if toks else 0, []
    for quote, text in pieces:
        words = [w for w in (skel(x) for x in quote.split()) if w]
        if words:
            n = min(3, len(words))
            hit = next((i for i in range(cur, min(cur + 250, len(sk)))
                        if all(eq(i + k, words[k], k == 0) for k in range(n))), None)
            if hit is None and n > 1:
                hit = next((i for i in range(cur, min(cur + 60, len(sk))) if eq(i, words[0], True)), None)
            # a quote never jumps more than 3 ayahs ahead (a later «أولئك
            # يجزون» once swallowed 25:63-66); it stays with the piece before
            if hit is not None and (not out or toks[hit][0] - ayah <= 3):
                ayah, cur = toks[hit][0], hit + 1
        out.append((ayah, text))
    return out


def first_index(toks, a):
    return next((i for i, (x, _) in enumerate(toks) if x == a), 0)


def cut(text, pat, toks, a_from, back=0):
    parts, last = [], 0
    ms = list(pat.finditer(text))
    if not ms:
        return [(a_from, text)]
    if ms[0].start() > 0:
        parts.append(('', text[:ms[0].start()]))
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(text)
        parts.append((m.group(1), text[m.start():end]))
    return place(parts, toks, first_index(toks, a_from), back)


DAAS_Q = re.compile(r'«([^»]*)»')
DRW_Q = re.compile(r'\(([^()]*[ً-ْ][^()]*[ً-ْ][^()]*[ً-ْ][^()]*)\)')


def show(label, placed, a0, a1):
    keep = [t for a, t in placed if a0 <= a <= a1]
    if keep:
        print(f'   {label}: ' + ' '.join(' '.join(keep).split()))


def main():
    s, a0, a1 = map(int, sys.argv[1:4])
    full = '--full' in sys.argv
    toks = ayah_tokens(s)
    d = sqlite3.connect(os.path.join(DATA, 'quran_sciences.db'))
    for a in range(a0, a1 + 1):
        at = [t for x, t in toks if x == a]
        print(f'== {s}:{a}  ' + ' '.join(f'[{i+1}]{t}' for i, t in enumerate(at)))
    print()
    rows = d.execute('select ayah_from, ayah_to, text from irab_daas where surah=? and ayah_from<=? and ayah_to>=? order by ayah_from',
                     (s, a1, a0)).fetchall()
    covered = set()
    for fa, ta, text in rows:
        covered.update(range(fa, ta + 1))
        placed = [(a0, text)] if full else cut(text, DAAS_Q, toks, fa)
        show(f'DAAS {fa}-{ta}', placed, a0, a1)
    miss = [a for a in range(a0, a1 + 1) if a not in covered]
    if miss:
        print('   DAAS: NO SECTION for ayahs', miss)
    seen, jgot = set(), set()
    for src, name in (('aljadwal', 'J'), ('iraab-aldarweesh', 'D')):
        for a in range(a0, a1 + 1):
            t = get(src, s, a)
            if src == 'aljadwal':
                t = re.split(r'\* (الصرف|البلاغة|الفوائد|فوائد)', t)[0]
            else:
                m = re.search(r'(الإعراب|الأعراب):', t); t = t[m.start():] if m else t
                t = re.split(r'\* (البلاغة|الفوائد)', t)[0]
            t = ' '.join(t.split())
            if not t or t in seen:
                continue
            seen.add(t)
            if full:
                placed = [(a, t)]
            elif src == 'aljadwal':  # «(42)» opens the part on ayah 42
                # «(n)» outside a [[footnote]]; «في الآية (75)» inside one is not a marker
                placed, cur = [], a
                for chunk in re.split(r'(\[\[.*?\]\])', t):
                    if chunk.startswith('[['):
                        placed.append((cur, chunk)); continue
                    for i, p in enumerate(re.split(r'\((\d+)\)', chunk)):
                        if i % 2:
                            cur = int(p)
                        else:
                            placed.append((cur, p))
            else:
                placed = cut(t, DRW_Q, toks, a, back=200)
            show(f'{name} {s}:{a}', placed, a0, a1)
            if src == 'aljadwal' and not full:
                jgot.update(x for x, _ in placed)
    if not full:
        jm = [a for a in range(a0, a1 + 1) if a not in jgot]
        if jm:  # e.g. tafsir.app's al-Jadwal group 25:63 jumps from (64) to (73)
            print('   J: NO PART for ayahs', jm)


if __name__ == '__main__':
    main()
