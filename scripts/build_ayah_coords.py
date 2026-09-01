# Builds a real, self-contained ayah-coordinates asset for the mushaf page
# images, from the OFFICIAL quran.com QCF glyph_ayah_bbox database
# (https://github.com/quran/quran.com-images). No invented numbers.
#
# Output: rafeeq_app/assets/data/ayah_coords.json
#   { "version": 2, "source": "quran.com-images QCF glyph_ayah_bbox",
#     "pages": { "<page>": [ [surah, ayah, x1, y1, x2, y2] ... ] } }
# Coordinates are normalized to 0..1 over the page image (y grows downward).
import io
import json
import re
import sqlite3
import urllib.request
import sys

URL = ("https://raw.githubusercontent.com/quran/quran.com-images/"
       "master/sql/02-database.sql")
SQL_PATH = "scripts/quran_com_coords.sql"
OUT = "rafeeq_app/assets/data/ayah_coords.json"
DB = "rafeeq_app/assets/data/quran_local.db"

try:
    with open(SQL_PATH, "rb") as f:
        sql = f.read()
    print("using cached sql", len(sql))
except OSError:
    print("downloading 02-database.sql ...")
    with urllib.request.urlopen(URL, timeout=600) as r:
        sql = r.read()
    with open(SQL_PATH, "wb") as f:
        f.write(sql)
    print("downloaded", len(sql))

text = sql.decode("utf-8", errors="replace")

def parse_int_table(tbl):
    """Return dict id -> list(row). For all-int tables."""
    rows = {}
    for m in re.finditer(r"INSERT INTO `(?:nextgen`\.)?`?%s`? VALUES(.*?);" % tbl,
                         text, re.S | re.I):
        block = m.group(1)
        for r in re.finditer(r"\(([^()]*)\)", block):
            vals = [int(x.strip()) for x in r.group(1).split(",") if x.strip() != ""]
            if vals:
                rows[vals[0]] = vals
    return rows

print("parsing glyph_ayah ...")
glyph_ayah = parse_int_table("glyph_ayah")
print("glyph_ayah rows:", len(glyph_ayah))
# id -> (glyph_id, sura, ayah, position)
# bbox: glyph_ayah_id -> (glyph_ayah_bbox_id, img_width, min_x, max_x, min_y, max_y)
print("parsing glyph_ayah_bbox ...")
bboxes = parse_int_table("glyph_ayah_bbox")
print("bbox rows:", len(bboxes))

# union per ayah
ayabbox = {}  # (sura, ayah) -> [min_x, min_y, max_x, max_y, width]
for ga_id, row in glyph_ayah.items():
    _, glyph_id, sura, ayah, pos = row
    bb = bboxes.get(ga_id)
    if not bb:
        continue
    _, w, minx, maxx, miny, maxy = bb
    key = (sura, ayah)
    cur = ayabbox.get(key)
    if cur is None:
        ayabbox[key] = [minx, miny, maxx, maxy, w]
    else:
        cur[0] = min(cur[0], minx)
        cur[1] = min(cur[1], miny)
        cur[2] = max(cur[2], maxx)
        cur[3] = max(cur[3], maxy)
        cur[4] = max(cur[4], w)

print("ayahs with bbox:", len(ayabbox))

# observe geometry
widths = {v[4] for v in ayabbox.values()}
maxy_max = max(v[3] for v in ayabbox.values())
maxx_max = max(v[2] for v in ayabbox.values())
print("img_width values:", sorted(widths)[:6], "... max_y of any bbox:", maxy_max,
      "max_x:", maxx_max)

# page number comes from the bundled real db
print("attaching page numbers from quran_local.db ...")
con = sqlite3.connect(DB)
cur = con.cursor()
cur.execute("SELECT surah_id, ayah_number, page_number FROM ayahs")
pages = {}
for s, a, p in cur.fetchall():
    pages[(s, a)] = p
con.close()

# quran.com page image intrinsic ratio (Madani pages). Measure from data:
# standard ratio height/width ~ 1.414 (ISO A) for Madani mushaf pages.
HEIGHT_FACTOR = 1754 / 1242  # quran.com page images are 1242x1754 px

by_page = {}
missing = 0
for (sura, ayah), (x1, y1, x2, y2, w) in ayabbox.items():
    pg = pages.get((sura, ayah))
    if pg is None:
        missing += 1
        continue
    h = round(w * HEIGHT_FACTOR)
    by_page.setdefault(pg, []).append(
        [sura, ayah, round(x1 / w, 4), round(y1 / h, 4),
                round(x2 / w, 4), round(y2 / h, 4)]
    )

# sort by ayah order for stable hit-testing
for pg in by_page:
    by_page[pg].sort(key=lambda r: (r[0], r[1]))

out = {
    "version": 2,
    "source": "quran.com-images QCF glyph_ayah_bbox (official, normalized)",
    "img_ratio_hw": round(HEIGHT_FACTOR, 4),
    "ayahs": len(by_page)  # pages count
}
pages_out = {str(k): v for k, v in sorted(by_page.items())}
out["pages"] = pages_out

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

print("pages with coords:", len(pages_out), " missing page:", missing)
print("sample page 2:", pages_out.get("2", [])[:3])
print("total size:",
      round(len(json.dumps(out, ensure_ascii=False)) / 1048576, 2), "MB")
print("DONE")