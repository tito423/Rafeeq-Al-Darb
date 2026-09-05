"""P3-44 data-quality fix: 3 of the 182 books built with an empty
titleAr/authorAr (fetch_meta_card's regex parse of the shamela.ws landing
page transiently failed for these 3 specific requests — a real, isolated
network/parse hiccup, not a pattern; every other field, including the
actual page-by-page book content, built completely correctly for all 3).
Re-fetches just the metadata (not a re-walk of the whole book — the
content itself is already verified good) and patches:
  - the book's own JSON meta (titleAr, authorAr, sourceLabel)
  - scripts/batch_summary.jsonl's matching row
so the catalog generator picks up the real values on a re-run.
"""

import json
import sys

sys.path.insert(0, "scripts")
from build_book_text import fetch_meta_card  # noqa: E402

FIXES = {
    "al_uzlah_wal_infirad": (26356, "ibn_abi_al_dunya"),
    "naqd_maratib_al_ijma": (8630, "ibn_taymiyyah"),
    "al_jami_fi_amthal_al_quran": (1477, "ibn_al_qayyim"),
}

for slug, (book_id, author_key) in FIXES.items():
    meta_card = fetch_meta_card(book_id)
    title = meta_card["title"]
    author = meta_card["author"]
    print(f"{slug}: title={title!r} author={author!r}")
    if not title or not author:
        print(f"  !! still empty, skipping patch for {slug}")
        continue

    source_label = f"المكتبة الشاملة — {title}، {author}"
    for line in meta_card["card"].splitlines():
        if line.startswith("الناشر:"):
            source_label += f"، {line.split(':', 1)[1].strip()}"
        if line.startswith("المحقق:") and line.split(":", 1)[1].strip() not in ("-", ""):
            source_label += f"، تحقيق {line.split(':', 1)[1].strip()}"

    json_path = f"scripts/book_text_build/{slug}.json"
    with open(json_path, encoding="utf-8") as f:
        doc = json.load(f)
    doc["meta"]["titleAr"] = title
    doc["meta"]["authorAr"] = author
    doc["meta"]["sourceLabel"] = source_label
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))

    # patch batch_summary.jsonl: append a corrected row (generate_catalog_
    # entries.py's by_slug dict keeps the LAST occurrence of each slug, so
    # appending a corrected row is enough, no need to rewrite the file).
    with open("scripts/batch_summary.jsonl", encoding="utf-8") as f:
        rows = [json.loads(l) for l in f]
    fixed_row = None
    for r in rows:
        if r["slug"] == slug:
            fixed_row = dict(r)
    fixed_row["titleAr"] = title
    fixed_row["authorAr"] = author
    fixed_row["sourceLabel"] = source_label
    with open("scripts/batch_summary.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(fixed_row, ensure_ascii=False) + "\n")
    print(f"  patched {json_path} and appended corrected summary row")

print("done")
