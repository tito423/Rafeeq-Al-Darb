"""Build assets/data/mushaf/rub_el_hizb_ayahs.json: the first ayah of each of
the 240 quarter-hizb divisions, as [surah, ayah, marked], index 0 = quarter 1.
`marked` is 1 when the bundled mushaf text carries the mark U+06DE on that
ayah (199 of the 240, measured 2026-11-10).

Source: api.quran.com v4 `rub_el_hizb_number` per verse (the same source as
rub_el_hizb_pages.json). Checked here against the bundled mushaf text:
every ayah that carries the mark U+06DE must be a quarter start, and each
start's page must equal rub_el_hizb_pages.json. The script fails otherwise.

Run: py -3 scripts/build_rub_el_hizb_ayahs.py
"""
import json
import sqlite3
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "rafeeq_app" / "assets" / "data"
OUT = DATA / "mushaf" / "rub_el_hizb_ayahs.json"
API = ("https://api.quran.com/api/v4/verses/by_chapter/{s}"
       "?per_page=50&page={p}&fields=rub_el_hizb_number")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2 + attempt * 2)


def main():
    rub_of = {}
    for s in range(1, 115):
        page = 1
        while True:
            j = fetch(API.format(s=s, p=page))
            for v in j["verses"]:
                rub_of[(s, v["verse_number"])] = v["rub_el_hizb_number"]
            nxt = j["pagination"]["next_page"]
            if not nxt:
                break
            page = nxt

    db = sqlite3.connect(DATA / "quran_local.db")
    rows = db.execute(
        "select surah_id, ayah_number, page_number, text_uthmani "
        "from ayahs order by id").fetchall()
    if len(rows) != 6236 or len(rub_of) != 6236:
        sys.exit(f"ayah count: db {len(rows)}, api {len(rub_of)}")

    starts, prev = [], 0
    for s, a, _, _ in rows:
        n = rub_of[(s, a)]
        if n != prev:
            if n != prev + 1:
                sys.exit(f"quarter jumps {prev} -> {n} at {s}:{a}")
            starts.append([s, a])
            prev = n
    if len(starts) != 240:
        sys.exit(f"{len(starts)} quarters, expected 240")

    start_set = {tuple(x) for x in starts}
    marked = [(s, a) for s, a, _, t in rows if "۞" in t]
    stray = [m for m in marked if m not in start_set]
    if stray:
        sys.exit(f"marked ayahs that are not quarter starts: {stray}")

    page_of = {(s, a): p for s, a, p, _ in rows}
    pages = json.loads((DATA / "mushaf" / "rub_el_hizb_pages.json").read_text())
    bad = [(i + 1, starts[i], page_of[tuple(starts[i])], pages[i])
           for i in range(240) if page_of[tuple(starts[i])] != pages[i]]
    if bad:
        sys.exit(f"page mismatch with rub_el_hizb_pages.json: {bad[:10]}")

    marked_set = set(marked)
    out = [[s, a, 1 if (s, a) in marked_set else 0] for s, a in starts]
    OUT.write_text(json.dumps(out, separators=(",", ":")) + "\n")
    print(f"240 quarters; {len(marked)} carry the mark, all are starts; "
          f"pages agree with rub_el_hizb_pages.json")


if __name__ == "__main__":
    main()
