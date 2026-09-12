# -*- coding: utf-8 -*-
"""Crawl, build and upload the next books for ONE author from the plan.

    py -3 scripts/shamela_add_author_books.py <catalogue-slug> [count]

`<catalogue-slug>` is the book this Library already has of his — the key in
`scripts/shamela_author_plan.json`. The shortest `count` of his other books
are taken, because Shamela serves one HTTP request per printed page and a
twelve-volume work is twelve thousand requests against someone else's server.

It stops short of `book_catalog.dart` on purpose. Adding a catalogue entry
means writing a title, an author line and a description in seven languages,
and picking a category — judgement, not transcription. What this prints is
everything that judgement needs, measured: the slug, the Shamela card verbatim,
the page count, and the byte size the bucket actually reported.

Nothing here invents an edition. `source_label` is built from Shamela's own
card, and a book whose card carries no publisher says so.
"""
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, 'scripts')
PLAN = os.path.join(SCRIPTS, 'shamela_author_plan.json')
RAW = os.path.join(SCRIPTS, 'shamela_raw')
BUILDER = os.path.join(SCRIPTS, 'build_book_text.py')

ENV = dict(os.environ, PYTHONIOENCODING='utf-8')


def run(args):
    return subprocess.run(args, cwd=ROOT, env=ENV, capture_output=True,
                          text=True, encoding='utf-8', errors='replace')


def slugify(title):
    """A Latin slug from an Arabic title, transliterated conservatively.

    Only used as a file name and a catalogue id; the title the reader sees is
    always the Arabic one from Shamela's card.
    """
    table = {
        'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'a', 'ب': 'b', 'ت': 't', 'ث': 'th',
        'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r',
        'ز': 'z', 'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't',
        'ظ': 'z', 'ع': 'a', 'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k',
        'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h', 'ة': 'h', 'و': 'w',
        'ي': 'y', 'ى': 'a', 'ء': '', 'ؤ': 'w', 'ئ': 'y', ' ': '_',
    }
    out = ''.join(table.get(c, '') for c in title)
    out = re.sub(r'_+', '_', out).strip('_').lower()
    return out[:44] or 'book'


def add_builder_entry(slug, shamela_id, label):
    src = io.open(BUILDER, encoding='utf-8').read()
    if "\"%s\": {" % slug in src:
        return
    anchor = 'BOOKS = {\n'
    entry = ('    "%s": {\n        "shamela_id": %s,\n'
             '        "source_label": %s,\n    },\n'
             % (slug, shamela_id, json.dumps(label, ensure_ascii=False)))
    io.open(BUILDER, 'w', encoding='utf-8', newline='\n').write(
        src.replace(anchor, anchor + entry, 1))


def source_label(title, author, desc):
    """Shamela's own card, reduced to one line. Whatever it does not say, this
    does not say either."""
    bits = []
    for key in ('المحقق', 'الناشر', 'الطبعة'):
        m = re.search(key + r'\s*:\s*([^\n]+)', desc)
        if m:
            bits.append(m.group(1).strip())
    tail = '، '.join(b for b in bits if b)
    if not tail:
        tail = 'دون بيانات طبعة'
    return 'المكتبة الشاملة — %s، لـ%s، %s' % (title, author, tail)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    key = sys.argv[1]
    # Explicit Shamela ids, because WHICH books is judgement and not a sort.
    # The owner asked for «١٠ من أفضل كتبهم»; taking the shortest ones gave
    # «جزء حديث المتبايعين بالخيار» over «الأذكار», which is cheapest and
    # wrong. Ids are chosen by reading the author's list of titles.
    chosen = [a for a in sys.argv[2:] if a.isdigit() and len(a) > 2]
    want = 9

    plan = json.load(io.open(PLAN, encoding='utf-8'))
    entry = next((e for e in plan if e['slug'] == key), None)
    if entry is None:
        print('no plan entry for', key)
        return 1

    author = entry['author']
    if chosen:
        by_id = {b['id']: b for b in entry.get('books', [])}
        missing = [c for c in chosen if c not in by_id]
        if missing:
            print("not among this author's books: %s" % ', '.join(missing))
            return 1
        sized = [by_id[c] for c in chosen]
    else:
        sized = sorted([b for b in entry.get('books', []) if b.get('pages')],
                       key=lambda b: b['pages'])[:want]
    if not sized:
        print('%s: Shamela has nothing else with a page count for %s'
              % (key, author))
        return 0

    os.makedirs(RAW, exist_ok=True)
    results = []
    for book in sized:
        slug = slugify(book['title'])
        pages = book['pages']
        jsonl = os.path.join(RAW, slug + '.jsonl')
        print('\n=== %s  (shamela %s, %s pages)' % (slug, book['id'], pages))
        r = run(['py', '-3', os.path.join(SCRIPTS, 'fetch_shamela_pages.py'),
                 book['id'], str(pages), jsonl])
        print('   ' + (r.stdout.strip().splitlines() or ['(no output)'])[-1])
        if not os.path.exists(jsonl):
            print('   CRAWL FAILED, skipped')
            continue
        add_builder_entry(slug, book['id'],
                          source_label(book['title'], author, book['desc']))
        r = run(['py', '-3', BUILDER, slug])
        ok = 'wrote' in r.stdout
        card = re.search(r'edition card:\n(.*?)\n  printMatches', r.stdout, re.S)
        matches = re.search(r'printMatches [^:]*: (\w+)', r.stdout)
        stats = re.search(r'(pages: \d+.*)', r.stdout)
        if not ok:
            print('   BUILD FAILED')
            print('   ' + r.stdout.strip()[-400:])
            continue
        r = run(['py', '-3', os.path.join(SCRIPTS, 'r2_upload_book_text.py'),
                 slug])
        size = re.search(r'\s(\d+) bytes', r.stdout)
        print('   ' + (r.stdout.strip().splitlines() or ['(no output)'])[0])
        results.append({
            'slug': slug,
            'shamela_id': book['id'],
            'titleAr': book['title'],
            'authorAr': author,
            'pages': pages,
            'printMatches': matches.group(1) if matches else '?',
            'sizeBytes': int(size.group(1)) if size else None,
            'sourceLabel': source_label(book['title'], author, book['desc']),
            'card': (card.group(1).strip() if card else ''),
            'stats': (stats.group(1).strip() if stats else ''),
        })

    out = os.path.join(SCRIPTS, 'shamela_added_%s.json' % key)
    with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(results, fh, ensure_ascii=False, indent=1)
        fh.write('\n')
    print('\n%d book(s) built and uploaded; details in %s' % (len(results), out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
