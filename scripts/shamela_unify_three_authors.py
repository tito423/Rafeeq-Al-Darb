# -*- coding: utf-8 -*-
"""Fix what adding the three batches exposed: one duplicated book and three
authors split across two spellings each.

The library groups books by the exact `authorAr` string, so two spellings of
one man make two people. That has bitten this project before — al-Nawawi and
Ibn al-Qayyim were each split the same way — and it showed up immediately on
the device here: «محمد ناصر الدين الألباني — كتاب واحد» sat several screens
below «الشيخ محمد ناصر الدين الألباني — ١٠ كتب».

  Ibn Hajar   الحافظ أحمد بن علي بن حجر العسقلاني  (1, بلوغ المرام)
              الحافظ ابن حجر العسقلاني              (10, new)
  Abu Nu'aym  أبو نعيم أحمد بن عبد الله الأصبهاني   (1, حلية الأولياء)
              الحافظ أبو نعيم الأصبهاني             (9, new)
  al-Albani   محمد ناصر الدين الألباني              (1, صحيح السيرة)
              الشيخ محمد ناصر الدين الألباني        (10, new)

The short, prefixed form wins in each case: it is the house style the rest of
the catalogue uses («الإمام محيي الدين النووي»), and it is the string the
author header actually has to fit.

And one duplicate. The new batch's «صحيح السيرة النبوية» is **Shamela book
592**, which the catalogue already carried as `sahih_as_seerah_albani` — same
book, 124,141 bytes against 124,126. The crawl re-fetched a book that was
already shipped. The new entry goes, and its object comes off the bucket with
it, because an orphan under a readable name is the thing most likely to be
mistaken for a real book later.

`sahih_al_adab_al_mufrad` is deliberately NOT merged into al-Albani: its text
is al-Bukhari's and al-Albani supplied the gradings, which is a different
attribution, not a different spelling.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, 'rafeeq_app', 'lib', 'features', 'library',
                       'data', 'book_catalog.dart')

DUPLICATE = 'sahih_al_sirah_al_nabawiyyah'

RENAMES = [
    ("authorAr: 'الحافظ أحمد بن علي بن حجر العسقلاني',",
     "authorAr: 'الحافظ ابن حجر العسقلاني',"),
    ("authorEn: 'Al-Hafiz Ibn Hajar al-Asqalani',",
     "authorEn: 'Ibn Hajar al-Asqalani',"),
    ("authorAr: 'أبو نعيم أحمد بن عبد الله الأصبهاني',",
     "authorAr: 'الحافظ أبو نعيم الأصبهاني',"),
    ("authorEn: 'Abu Nuaym al-Isbahani',",
     "authorEn: 'Abu Nuaym al-Asbahani',"),
    ("authorAr: 'محمد ناصر الدين الألباني',",
     "authorAr: 'الشيخ محمد ناصر الدين الألباني',"),
    ("authorEn: 'Abridged by Muhammad Nasir ad-Din al-Albani',",
     "authorEn: 'Muhammad Nasir al-Din al-Albani',"),
]


def drop_entry(src, book_id):
    """Remove one whole `LibraryBook( ... ),` block by id."""
    start = src.find("    id: '%s'," % book_id)
    if start < 0:
        return src, False
    open_at = src.rfind('  LibraryBook(', 0, start)
    end = src.find('\n  ),\n', start)
    assert open_at >= 0 and end > open_at
    return src[:open_at] + src[end + len('\n  ),\n'):], True


def main():
    apply = '--apply' in sys.argv
    src = io.open(CATALOG, encoding='utf-8').read()
    before = len(re.findall(r'  LibraryBook\(', src))

    src, dropped = drop_entry(src, DUPLICATE)
    print('duplicate %s: %s' % (DUPLICATE, 'removed' if dropped else 'ABSENT'))

    for old, new in RENAMES:
        n = src.count(old)
        print('%-3d x %s' % (n, old.strip()))
        src = src.replace(old, new)

    after = len(re.findall(r'  LibraryBook\(', src))
    print('books: %d -> %d' % (before, after))

    # No spelling of these three may survive twice.
    authors = set(re.findall(r"authorAr: '([^']+)'", src))
    for key in ('العسقلاني', 'الأصبهاني', 'الألباني'):
        hits = sorted(a for a in authors if key in a)
        print('%s -> %s' % (key, hits))

    if not apply:
        print('\ndry run; re-run with --apply')
        return 0

    io.open(CATALOG, 'w', encoding='utf-8', newline='\n').write(src)
    if dropped:
        key = 'books/text/%s.json' % DUPLICATE
        r2_client().delete_object(Bucket=BUCKET, Key=key)
        print('deleted %s from the bucket' % key)
    print('written')
    return 0


if __name__ == '__main__':
    sys.exit(main())
