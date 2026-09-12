"""Find every Shamela book by the authors this Library only has ONE book from.

WHY NOT SHAMELA'S SEARCH, AND NOT THE LOCAL CATEGORY INDEX
----------------------------------------------------------
Trap #17: Shamela's own search looks INSIDE books, not at their titles, so
asking it for an author's name returns books that mention him. And
`scripts/shamela_index.json` is a category listing with no author field at all.

So the author id is taken from a book we already have. Every built text
edition in `scripts/book_text_build/` carries the `shamelaUrl` it was crawled
from; that page links to `/author/<id>`; that page lists everything Shamela
holds by him. No guessing which «المباركفوري» is meant — it is the same author
record the book we already shipped belongs to.

    py -3 scripts/shamela_author_books.py            # writes the plan
"""
import gzip
import io
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'rafeeq_app')
BUILD = os.path.join(ROOT, 'scripts', 'book_text_build')
CATALOG = os.path.join(APP, 'lib', 'features', 'library', 'data',
                       'book_catalog.dart')
OUT = os.path.join(ROOT, 'scripts', 'shamela_author_plan.json')

# Trap #38: a User-Agent with no contact in it gets throttled or refused.
UA = ('RafeeqAlDarb/3.22 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8')


def fetch(url):
    """curl, not urllib: msys Python has no CA bundle here (trap #12)."""
    r = subprocess.run(
        ['curl', '-s', '-m', '40', '-A', UA, url],
        capture_output=True)
    return r.stdout.decode('utf-8', 'replace')


def catalog_entries():
    """(slug, authorAr) for every catalogue book, in file order."""
    src = io.open(CATALOG, encoding='utf-8').read()
    out = []
    for m in re.finditer(r"id:\s*'([a-z0-9_]+)'", src):
        tail = src[m.end():m.end() + 1200]
        a = re.search(r"authorAr:\s*'([^']+)'", tail)
        if a:
            out.append((m.group(1), a.group(1)))
    return out


def shamela_id_for(slug):
    path = os.path.join(BUILD, slug + '.json')
    if not os.path.exists(path):
        return None
    raw = open(path, 'rb').read()
    if raw[:2] == b'\x1f\x8b':
        raw = gzip.decompress(raw)
    try:
        meta = json.loads(raw.decode('utf-8')).get('meta', {})
    except Exception:
        return None
    m = re.search(r'/book/(\d+)', meta.get('shamelaUrl', ''))
    return m.group(1) if m else None


def author_of_book(book_id):
    html = fetch('https://shamela.ws/book/%s' % book_id)
    m = re.search(r'/author/(\d+)', html)
    return m.group(1) if m else None


BOOK_ITEM = re.compile(
    r'<div class="book_item.*?/book/(\d+)".*?class="[^"]*book_title[^"]*">'
    r'(.*?)</span>(.*?)(?=<div class="book_item|<div id="pagination|\Z)',
    re.S)


def books_of_author(author_id):
    """id, title, printed-edition block and page count for each book.

    The page count matters before anything is crawled: Shamela serves one
    request per printed page, so a 12-volume work is twelve thousand requests
    against someone else's server and a 20 MB asset for a phone. It is read
    here so the choice is made on a measured number rather than on a guess.
    """
    html = fetch('https://shamela.ws/author/%s' % author_id)
    out = []
    for bid, title, block in BOOK_ITEM.findall(html):
        desc = re.sub(r'<br\s*/?>', chr(10), block)
        desc = re.sub(r'<[^>]+>', ' ', desc)
        desc = re.sub(r'[ \t]+', ' ', desc).strip()
        pages = None
        m = re.search(r'عدد الصفحات:\s*([٠-٩0-9]+)', desc)
        if m:
            digits = m.group(1)
            pages = int(''.join(
                str('٠١٢٣٤٥٦٧٨٩'.index(c)) if c in '٠١٢٣٤٥٦٧٨٩' else c
                for c in digits))
        out.append({
            'id': bid,
            'title': re.sub(r'<[^>]+>', '', title).strip(),
            'pages': pages,
            'desc': desc[:600],
        })
    name = re.search(r'<title>\s*([^<]+?)\s*</title>', html)
    return (name.group(1).strip() if name else ''), out


def main():
    entries = catalog_entries()
    counts = {}
    for _, a in entries:
        counts[a] = counts.get(a, 0) + 1
    singles = [(slug, a) for slug, a in entries if counts[a] == 1]
    print('catalogue books: %d, authors: %d, single-book authors: %d'
          % (len(entries), len(counts), len(singles)))

    plan = []
    for slug, author in singles:
        bid = shamela_id_for(slug)
        if bid is None:
            plan.append({'slug': slug, 'author': author, 'error': 'no built text edition'})
            print('  %-38s NO BUILT EDITION' % slug)
            continue
        aid = author_of_book(bid)
        time.sleep(0.8)
        if aid is None:
            plan.append({'slug': slug, 'author': author, 'book_id': bid,
                         'error': 'no author link on the book page'})
            print('  %-38s book %-7s NO AUTHOR LINK' % (slug, bid))
            continue
        label, books = books_of_author(aid)
        time.sleep(0.8)
        have = {bid}
        plan.append({
            'slug': slug,
            'author': author,
            'book_id': bid,
            'author_id': aid,
            'author_label': label,
            'books': [b for b in books if b['id'] not in have],
        })
        print('  %-38s author %-6s -> %d other books' % (slug, aid, len(plan[-1]['books'])))

    with io.open(OUT, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(plan, fh, ensure_ascii=False, indent=1)
        fh.write('\n')
    print('wrote', OUT)


if __name__ == '__main__':
    sys.exit(main())
