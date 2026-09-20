"""Build the ayah-highlight layer for the quran.com Madinah page images.

WHY THIS EXISTS. Until 2026-09-20 the app's paper mushaf was the vector
`hafs_kfqc` edition: correct, but 286 MB of SVG for 604 pages, and the reader
sees it rasterised at page size anyway (trap #48). The quran.com Madinah
scan-set is the same 604-page Madinah pagination at 1260x2038 for ~62 MB, and
its publisher ships the ayah coordinates WITH it — `ayahinfo_1260.db`, 88,246
glyph boxes covering all 604 pages and all 6,236 ayahs. Nothing here is
measured, fitted or guessed: the boxes are the typesetter's own.

WHAT IT PRODUCES. `madinah_qc_polygons.json`, in the exact schema the app
already reads for `hafs_kfqc`:

    pages[page] = [ [surah, ayah, [ring, ...]], ... ]
    ring        = [[x, y], [x, y], [x, y], [x, y]]   normalised 0..1, y down

One ring per LINE the ayah occupies, each the union of that line's word boxes.
That is deliberately not one ring per word: «انا مش عايز تظليل كلمة كلمة لسبب
ان لما اضغط الاية بيظهر كرتها مش كرت الكلمة». The word boxes are raw material;
what the app gets is the ayah.

EVERY PAGE IS MEASURED, not assumed (trap #22): the ring is normalised by the
real pixel size read from that page's own PNG header, and a page whose image is
missing is reported rather than silently skipped.

Usage:  py -3 scripts/build_madinah_qc_polygons.py <pages-dir> <ayahinfo.db> <out.json>
"""
import json
import os
import sqlite3
import struct
import sys
from collections import defaultdict

EDITION = 'madinah_qc'


def png_size(path):
    """Width and height from the PNG header - no decode, no PIL."""
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        raise ValueError('%s is not a PNG' % path)
    return struct.unpack('>II', head[16:24])


def main():
    pages_dir, db_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    con = sqlite3.connect(db_path)

    rows = con.execute(
        'select page_number, line_number, sura_number, ayah_number,'
        ' position, min_x, max_x, min_y, max_y from glyphs'
        ' order by page_number, line_number, position').fetchall()
    print('%d glyph boxes' % len(rows))

    by_page = defaultdict(list)
    for r in rows:
        by_page[r[0]].append(r[1:])

    sizes = {}
    missing = []
    pages = {}
    total_rings = 0
    for page in range(1, 605):
        img = os.path.join(pages_dir, '%03d.png' % page)
        if not os.path.exists(img):
            missing.append(page)
            continue
        w, h = png_size(img)
        sizes[(w, h)] = sizes.get((w, h), 0) + 1

        # ayah -> line -> box, keeping the order the ayahs first appear in
        order = []
        lines = defaultdict(dict)
        for (line, sura, ayah, _pos, x0, x1, y0, y1) in by_page[page]:
            key = (sura, ayah)
            if key not in lines:
                order.append(key)
            # Some rows store their bounds the other way round (2,678 of
            # 88,246 in the 1260 set) - an RTL artefact of the generator.
            x0, x1 = min(x0, x1), max(x0, x1)
            y0, y1 = min(y0, y1), max(y0, y1)
            box = lines[key].get(line)
            lines[key][line] = box and (
                min(box[0], x0), max(box[1], x1),
                min(box[2], y0), max(box[3], y1)) or (x0, x1, y0, y1)

        entries = []
        for key in order:
            rings = []
            for line in sorted(lines[key]):
                x0, x1, y0, y1 = lines[key][line]
                a, b = round(x0 / w, 4), round(x1 / w, 4)
                c, d = round(y0 / h, 4), round(y1 / h, 4)
                rings.append([[a, c], [b, c], [b, d], [a, d]])
            total_rings += len(rings)
            entries.append([key[0], key[1], rings])
        pages[str(page)] = entries

    doc = {
        'version': 1,
        'edition': EDITION,
        'source': 'quran.com ayahinfo_1260 (quran/quran_android data; '
                  'CC BY-NC-ND per its README)',
        'coords': 'normalized 0..1 of each page image, y grows downward',
        'schema': 'pages[page] = [ [surah, ayah, [ring,...]], ... ]; '
                  'ring = [[x,y],...]',
        'pages': pages,
    }
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(doc, f, ensure_ascii=False, separators=(',', ':'))

    ayahs = sum(len(v) for v in pages.values())
    print('pages written : %d' % len(pages))
    print('ayah entries  : %d' % ayahs)
    print('rings         : %d' % total_rings)
    print('image sizes   : %s' % sorted(sizes.items(), key=lambda kv: -kv[1]))
    print('missing pages : %s' % (missing or 'none'))
    print('out           : %d bytes' % os.path.getsize(out_path))
    if missing:
        raise SystemExit('refusing to be trusted: %d pages had no image'
                         % len(missing))


main()
