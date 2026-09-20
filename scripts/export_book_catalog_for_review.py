"""Export the library catalogue for the content-review site.

Reads `book_catalog.dart` - the list the app itself ships - and writes
`data/books.json` next to the site's other data: one row per book with its
title, author, category, edition line and the URL the app downloads it from.

The TEXT is deliberately not copied. 223 objects, 49.7 MB gzipped on the
bucket, is not something to duplicate into a GitHub Pages repository; the
site fetches each book from the same public URL the app uses, and ungzips it
in the browser, so a reviewer reads exactly the bytes a reader gets.

Usage:  py -3 scripts/export_book_catalog_for_review.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'rafeeq_app', 'lib', 'features', 'library', 'data',
                   'book_catalog.dart')
OUT = os.path.join(os.path.dirname(ROOT), 'rafeeq-review', 'data',
                   'books.json')
BASE = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'


def joined(text):
    """Dart string literals, including the adjacent-literal concatenation
    the catalogue uses to wrap long edition lines."""
    parts = re.findall(r"'((?:[^'\\]|\\.)*)'", text)
    return ''.join(p.replace("\\'", "'").replace('\\\\', '\\')
                   for p in parts).strip()


def field(block, name, default=''):
    m = re.search(r'\b%s:\s*(.*?)(?=\n\s{4}\w+:|\n\s{4}\),|\Z)' % name, block,
                  re.S)
    if not m:
        return default
    raw = m.group(1)
    if "'" in raw:
        return joined(raw)
    return raw.strip().rstrip(',').strip()


def main():
    src = open(SRC, encoding='utf-8').read()
    blocks = re.findall(r'LibraryBook\((.*?)\n  \),', src, re.S)
    books = []
    for b in blocks:
        bid = field(b, 'id')
        if not bid:
            continue
        url = field(b, 'url')
        # `'${AppConfig.contentBaseUrl}/books/text/x.json'` in the source.
        path = re.search(r'/books/text/[^\'\s]+\.json', url)
        books.append({
            'id': bid,
            'title': field(b, 'titleAr'),
            'author': field(b, 'authorAr'),
            'death': field(b, 'deathYearAh'),
            'category': field(b, 'category').replace('BookCategory.', ''),
            'edition': field(b, 'sourceLabel'),
            'url': (BASE + path.group(0)) if path else '',
            'size': field(b, 'sizeBytes'),
        })
    books = [b for b in books if b['url']]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(books, f, ensure_ascii=False, separators=(',', ':'))
    print('%d books -> %s (%d bytes)'
          % (len(books), OUT, os.path.getsize(OUT)))
    missing = [b['id'] for b in books if not b['title'] or not b['author']]
    if missing:
        raise SystemExit('refusing: no title or author for %s' % missing)


main()
