# -*- coding: utf-8 -*-
"""Curate the extracted quotes down to the ones that stand alone, and ship them
in all seven languages.

WHY CURATED AT ALL
------------------
`build_quotes.py` pulls standalone paragraphs out of four books and filters
hard, and it still cannot tell a maxim from the middle of an argument:
«الفائدة الأولى: …», «الدرجة السادسة: …», «أنه يورث حياة القلب» — each is item
N of a list that began on the page before, and each reads on a card as a
sentence with its head cut off. Of the 260 the filter produced, the ones named
in `quotes_curated_*.json` are the ones that stand on their own, read by hand.

WHY TRANSLATED
--------------
«ترجم كل اللي ينفع يترجم بس بناء على اعلى معايير الجودة والدقة». The quote card
was Arabic-only, which meant six of the seven languages did not have it at all.

THE ARABIC IS NEVER RETYPED. A curated entry is a POINTER — «book id | index in
that book's quote list» — and the Arabic is copied out of the builder's own
output at build time. That is the only way to be certain a diacritic was not
lost in transcription, and it is what §1.2 asks for.

    py -3 scripts/build_quotes.py        # extract (writes quotes_built.json)
    py -3 scripts/quotes_curated.py      # curate + translate -> the asset
"""
import glob
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILT = os.path.join(ROOT, "scripts", "quotes_built.json")
OUT = os.path.join(ROOT, "rafeeq_app", "assets", "data", "quotes.json")
REPORT = os.path.join(ROOT, "scripts", "quotes_curated_out.txt")

LANGS = ["en", "es", "fr", "pt", "ru", "ur"]


def load_translations():
    t = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts",
                                              "quotes_curated_*.json"))):
        part = json.load(io.open(path, encoding="utf-8"))
        for k, v in part.items():
            if k in t:
                raise SystemExit("duplicate curated key: %s" % k)
            t[k] = v
    return t


def main():
    built = json.load(io.open(BUILT, encoding="utf-8"))
    tr = load_translations()
    used = set()

    books = []
    total = 0
    for b in built["books"]:
        kept = []
        for i, q in enumerate(b["quotes"]):
            key = "%s|%d" % (b["id"], i)
            if key not in tr:
                continue
            used.add(key)
            row = {"p": q["p"], "t": {"ar": q["t"]}}
            for lang in LANGS:
                value = (tr[key].get(lang) or "").strip()
                if not value:
                    raise SystemExit("%s has no %s" % (key, lang))
                row["t"][lang] = value
            kept.append(row)
        if not kept:
            continue
        total += len(kept)
        books.append({
            "id": b["id"],
            "titleAr": b["titleAr"],
            "authorAr": b["authorAr"],
            "sourceLabel": b["sourceLabel"],
            "quotes": kept,
        })

    missing = sorted(set(tr) - used)
    if missing:
        raise SystemExit("these curated keys match no extracted quote — the "
                         "extraction changed under them:\n  " +
                         "\n  ".join(missing))

    doc = {"schema": 2, "langs": ["ar"] + LANGS, "books": books}
    raw = json.dumps(doc, ensure_ascii=False)
    io.open(OUT, "w", encoding="utf-8", newline="").write(raw)

    with io.open(REPORT, "w", encoding="utf-8") as r:
        r.write("curated quotes: %d in %d books\n\n" % (total, len(books)))
        for b in books:
            r.write("%-34s %3d\n" % (b["id"], len(b["quotes"])))
        r.write("\nfirst of each book, in every language:\n")
        for b in books:
            q = b["quotes"][0]
            r.write("\n=== %s ص%s\n" % (b["titleAr"], q["p"]))
            for lang in ["ar"] + LANGS:
                r.write("  [%s] %s\n" % (lang, q["t"][lang]))
    print("%d quotes, %d books -> %s (%d bytes)"
          % (total, len(books), OUT, len(raw.encode("utf-8"))))


if __name__ == "__main__":
    main()
