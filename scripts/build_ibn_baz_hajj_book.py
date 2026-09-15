"""Builds the text edition of Ibn Baz's Hajj manual for the Library and for
the «مناسك الحج والعمرة» section, through the same pipeline every other
Shamela book goes through (`build_book_text.build_book`).

    «التحقيق والإيضاح لكثير من مسائل الحج والعمرة والزيارة على ضوء الكتاب
    والسنة» — الشيخ عبد العزيز بن عبد الله بن باز. Shamela book 31235.

Why this book: the owner asked for the rites «من مصادر موثوقة». It is a short,
step-by-step manual written for pilgrims, by the former Grand Mufti of Saudi
Arabia, and it cites its evidence inline. The 106 pages were crawled once by
`fetch_shamela_pages.py`; this reads them from that crawl rather than asking
Shamela again.

    py -3 scripts/build_ibn_baz_hajj_book.py <crawl.jsonl>

Writes scripts/book_text_build/ibn_baz_tahqiq_wal_idah.json (gzip, the
standing rule) and prints the pipeline's own verification block.
"""
import io
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(__file__))

import build_book_text as bbt  # noqa: E402

SLUG = "ibn_baz_tahqiq_wal_idah"
SHAMELA_ID = 31235


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    crawl = sys.argv[1]
    os.makedirs(bbt.RAW_DIR, exist_ok=True)
    cached = os.path.join(bbt.RAW_DIR, f"{SLUG}.jsonl")
    if not os.path.exists(cached):
        shutil.copyfile(crawl, cached)
    with io.open(cached, encoding="utf-8") as f:
        n = sum(1 for line in f if line.strip())
    print(f"crawl: {n} pages at {cached}")

    card = bbt.fetch_meta_card(SHAMELA_ID)
    label = f"المكتبة الشاملة — {card['title'] or SLUG}، {card['author']}"
    for line in card["card"].splitlines():
        if line.startswith("الناشر:"):
            label += f"، {line.split(':', 1)[1].strip()}"

    doc = bbt.build_book(SLUG, SHAMELA_ID, label)
    os.makedirs(bbt.OUT_DIR, exist_ok=True)
    out = os.path.join(bbt.OUT_DIR, f"{SLUG}.json")
    raw, packed = bbt.write_book_json(doc, out)
    print(f"wrote {out}  ({packed} bytes gzip, {raw} bytes raw)")
    bbt.verify_and_print(doc)

    # The section section of the Hajj guide addresses paragraphs by
    # (printed page, index). Dump that index so the ranges can be read off
    # the real parse, not guessed from the raw crawl.
    index_path = os.path.join(bbt.OUT_DIR, f"{SLUG}.para_index.txt")
    with io.open(index_path, "w", encoding="utf-8") as f:
        f.write(f"sourceLabel: {label}\n")
        for page in doc["pages"]:
            for i, para in enumerate(page["paras"]):
                f.write(f"p{page['p']}:{i} [{para['k']}] {para['t'][:110]}\n")
    print(f"paragraph index: {index_path}")


if __name__ == "__main__":
    main()
