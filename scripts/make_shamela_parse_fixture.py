"""Fixture for the app's Dart port of `parse_nass` (lib/features/shamela).

Takes real pages from the local Shamela crawl (`shamela_raw/`) and records,
for each, the `nass` HTML and what the pipeline's own `parse_nass` makes of
it. The Dart test must produce the same paragraphs, so the book a reader
imports on the phone is parsed exactly like the books the pipeline built.

    py -3 scripts/make_shamela_parse_fixture.py
"""
import gzip, io, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_book_text import parse_nass  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BOOKS = ["al_adhkar_nawawi", "adab_dukhul_al_hammam", "al_arbaun_an_nawawiyyah"]
OUT = os.path.join(HERE, "..", "rafeeq_app", "test", "fixtures",
                   "shamela_parse_nass.json.gz")

cases = []
for b in BOOKS:
    with io.open(os.path.join(HERE, "shamela_raw", b + ".jsonl"), encoding="utf-8") as f:
        rows = [json.loads(l) for l in f if l.strip()]
    rows.sort(key=lambda d: int(d.get("pageId") or 0))
    # Every page of the short books, every 5th of a long one, capped.
    step = 1 if len(rows) <= 120 else max(1, len(rows) // 120)
    for d in rows[::step][:120]:
        nass = d.get("nass") or ""
        cases.append({"book": b, "pageId": d.get("pageId"),
                      "nass": nass, "paras": parse_nass(nass)})
# Ayah coverage: the three books above hold 2 ayahs and no reference.
# These two hold the most ayahs WITH a reference in the crawl (measured:
# al_fiqh_al_manhaji 19 of 32, sfh_alnfaq 18 of 18 in their first 400
# pages) - every such page is kept.
for b in ["al_fiqh_al_manhaji", "sfh_alnfaq_wnat_almnafqyn_laby_naym"]:
    with io.open(os.path.join(HERE, "shamela_raw", b + ".jsonl"),
                 encoding="utf-8", errors="replace") as f:
        rows = [json.loads(l) for l in list(f)[:400] if l.strip()]
    for d in rows:
        paras = parse_nass(d.get("nass") or "")
        if any(p["k"] == "aya" for p in paras):
            cases.append({"book": b, "pageId": d.get("pageId"),
                          "nass": d.get("nass") or "", "paras": paras})
with gzip.open(OUT, "wt", encoding="utf-8") as g:
    json.dump(cases, g, ensure_ascii=False)
print(len(cases), "pages ->", OUT, os.path.getsize(OUT), "B")
