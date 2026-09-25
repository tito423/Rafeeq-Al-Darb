"""Cut «إعراب القرآن الكريم» (al-Da'as, Humaydan, al-Qasim; Shamela 23584)
into its own sections: one row per heading the book prints, verbatim.

What the pages look like (read by hand 2026-09-25, pages 1-6 and 1399):

  * A section opens with a heading paragraph
        [سورة البقرة (٢) : الآيات ١ الى ٥]      (early volumes: a range)
        [[سورة الناس (١١٤) : آية ١]]           (later: one ayah, double brackets)
    «الى» and «إلى» both occur.
  * Then the ayah text, each ayah closed by a `(n)` in a c2 span, and a
    bare basmala line at the head of a surah.
  * Then the book's own text for the section: sometimes a paragraph of
    word meanings first («الكفر» الجحود…), then the i'rab. Both are the
    book's text and both are kept - nothing is rewritten or dropped.
  * A paragraph can run across a page (page 6 opens with «مبتدأ.»), so the
    pages are joined before cutting.
  * `[سورة …]` alone (no colon) is a surah title, not a section.

The book groups ayahs; a section's text belongs to the whole group, so a row
carries surah, ayah_from, ayah_to and is shown for every ayah in the group.

    py -3 scripts/parse_irab_daas.py      -> scripts/temp_phase1/irab_daas.json
"""
import html
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'scripts', 'shamela_raw', 'irab_daas.jsonl')
OUT = os.path.join(ROOT, 'scripts', 'temp_phase1', 'irab_daas.json')

AR_DIGITS = str.maketrans('٠١٢٣٤٥٦٧٨٩', '0123456789')
HEAD = re.compile(
    r'^\[\[?\s*سورة\s+(.+?)\s*\((\d+)\)\s*:\s*(?:الآيات|الآية|آية|الايات|اية)\s*'
    r'(\d+)(?:\s*(?:الى|إلى|إلي|الي)\s*(\d+))?\s*\]\]?$')
SURAH_TITLE = re.compile(r'^\[سورة [^:\]]+\]$')
AYAH_END = re.compile(r'\((\d+)\)\s*$')


def paragraphs():
    pages = [json.loads(l) for l in io.open(RAW, encoding='utf-8')]
    pages.sort(key=lambda p: p['pageId'])
    for p in pages:
        for m in re.finditer(r'<p>(.*?)</p>', p['nass'], re.S):
            inner = re.sub(r'<a [^>]*btn_tag.*?</a>', '', m.group(1), flags=re.S)
            text = html.unescape(re.sub(r'<[^>]+>', '', inner)).strip()
            if text:
                yield p['pageId'], text


def main():
    rows, cur = [], None
    unparsed_heads = []
    for page, para in paragraphs():
        norm = para.translate(AR_DIGITS)
        m = HEAD.match(norm)
        if m:
            if cur:
                rows.append(cur)
            s, a, b = int(m.group(2)), int(m.group(3)), int(m.group(4) or m.group(3))
            cur = {'surah': s, 'from': a, 'to': b, 'page': page,
                   'ayah_text': [], 'text': []}
            continue
        if norm.startswith('[') and ':' in norm and 'سورة' in norm[:8]:
            unparsed_heads.append((page, para))
        if cur is None or SURAH_TITLE.match(norm):
            continue
        cur['page_end'] = page
        # Ayah lines come right after the heading, before any book text.
        if not cur['text'] and (AYAH_END.search(norm) or
                                norm.startswith('بِسْمِ اللَّهِ')):
            cur['ayah_text'].append(para)
            continue
        # Shamela sometimes glues the section's last ayah line and the start
        # of the i'rab into one paragraph (19:14-17: «… بَشَراً سَوِيًّا (١٧)
        # «وَبَرًّا» معطوف …»). Split after the section's last ayah number when
        # nothing before it is book text (no «).
        if not cur['text']:
            m = None
            for m_ in re.finditer(r'\((\d+)\)', norm):
                if int(m_.group(1)) == cur['to']:
                    m = m_
            if m and '«' not in para[:m.end()]:
                cur['ayah_text'].append(para[:m.end()].strip())
                para = para[m.end():].strip()
                if not para:
                    continue
        cur['text'].append(para)
    if cur:
        rows.append(cur)

    out = [{'surah': r['surah'], 'from': r['from'], 'to': r['to'],
            'page': r['page'], 'page_end': r.get('page_end', r['page']),
            'text': '\n'.join(r['text'])} for r in rows]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(out, io.open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    sys.stdout.reconfigure(encoding='utf-8')
    print(f'{len(out)} sections, {len(unparsed_heads)} heading-like lines not parsed')
    for p, t in unparsed_heads[:20]:
        print('  UNPARSED', p, t[:90])


if __name__ == '__main__':
    main()
