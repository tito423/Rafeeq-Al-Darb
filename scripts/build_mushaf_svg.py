#!/usr/bin/env python3
"""
Build the Rafeeq mushaf asset set from quranpedia/quran-svg (CC0-1.0).

Source: https://github.com/quranpedia/quran-svg
  mushafs/<qiraa>/<publisher>/svg/NNN.svg   - vector page + <path class="ayahPolygon">
  mushafs/<qiraa>/<publisher>/json/surah.json

Why this source: every ayah ships as a real polygon (up to 3 rings, so an ayah
spanning several lines highlights correctly). No invented coordinates, no
reverse-engineered proprietary data.

Outputs
  scripts/mushaf_build/svg/NNN.svg                  page images (upload to R2)
  rafeeq_app/assets/data/mushaf/<id>_polygons.json  normalized tap regions
"""
import json, os, re, sys, time, urllib.request, urllib.error

EDITION   = os.environ.get("EDITION", "hafs/kfqc")
EDITION_ID= EDITION.replace("/", "_")
PAGES     = int(os.environ.get("PAGES", "604"))
ROOT      = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW       = "https://raw.githubusercontent.com/quranpedia/quran-svg/master/mushafs/" + EDITION
SVG_DIR   = os.path.join(ROOT, "scripts", "mushaf_build", EDITION_ID, "svg")
OUT_DIR   = os.path.join(ROOT, "rafeeq_app", "assets", "data", "mushaf")
OUT_JSON  = os.path.join(OUT_DIR, EDITION_ID + "_polygons.json")

os.makedirs(SVG_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)

POLY_RE = re.compile(r'<path class="ayahPolygon"[^>]*?>')
ATTR_RE = lambda n: re.compile(r'\b%s="([^"]*)"' % n)
SURAH_A, AYAH_A, D_A = ATTR_RE("surah"), ATTR_RE("ayah"), ATTR_RE("d")
VB_RE   = re.compile(r'viewBox="([^"]+)"')


def is_intact(data):
    """A usable page: complete XML document that carries the ayah hit layer.

    Guards against silently-truncated downloads, which otherwise look like an
    upstream data gap (page 294 arrived truncated on the first run and its
    ayah polygons vanished without any error).
    """
    if len(data) < 4096:
        return False
    if b"</svg>" not in data[-512:]:
        return False
    return b'class="ayahPolygon"' in data


def fetch(url, dest, tries=4):
    """Download url -> dest, skipping only a file that is already intact."""
    if os.path.exists(dest):
        with open(dest, "rb") as f:
            if is_intact(f.read()):
                return False
        os.remove(dest)  # truncated/partial from an earlier run
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                data = r.read()
            if not is_intact(data):
                raise ValueError("incomplete page payload (%d bytes)" % len(data))
            with open(dest, "wb") as f:
                f.write(data)
            return True
        except Exception:
            if attempt == tries - 1:
                raise
            time.sleep(1.5 * (attempt + 1))


def parse_rings(d):
    """'M x y L x y ... Z M ...' -> [[(x,y),...], ...]. Source uses only M/L/Z."""
    rings, cur = [], []
    for tok in re.finditer(r'([MLZ])([^MLZ]*)', d):
        cmd, body = tok.group(1), tok.group(2)
        nums = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', body)]
        if cmd == "M":
            if len(cur) >= 3:
                rings.append(cur)
            cur = []
        if cmd in ("M", "L"):
            cur.extend(zip(nums[0::2], nums[1::2]))
        elif cmd == "Z":
            if len(cur) >= 3:
                rings.append(cur)
            cur = []
    if len(cur) >= 3:
        rings.append(cur)
    return rings


def main():
    pages_out, stats = {}, {"polys": 0, "rings": 0, "multiline": 0, "downloaded": 0}
    for p in range(1, PAGES + 1):
        name = "%03d.svg" % p
        dest = os.path.join(SVG_DIR, name)
        if fetch(RAW + "/svg/" + name, dest):
            stats["downloaded"] += 1

        svg = open(dest, encoding="utf-8").read()
        vb = VB_RE.search(svg)
        if not vb:
            print("!! page %d has no viewBox" % p, file=sys.stderr)
            continue
        vx, vy, vw, vh = [float(v) for v in vb.group(1).split()]

        ayahs = []
        for tag in POLY_RE.findall(svg):
            su, ay, d = SURAH_A.search(tag), AYAH_A.search(tag), D_A.search(tag)
            if not (su and ay and d):
                continue
            rings = parse_rings(d.group(1))
            if not rings:
                continue
            # normalize to 0..1 of the page box so the client is resolution-agnostic
            norm = [[[round((x - vx) / vw, 4), round((y - vy) / vh, 4)] for x, y in r]
                    for r in rings]
            ayahs.append([int(su.group(1)), int(ay.group(1)), norm])
            stats["polys"] += 1
            stats["rings"] += len(rings)
            if len(rings) > 1:
                stats["multiline"] += 1

        ayahs.sort(key=lambda a: (a[0], a[1]))
        pages_out[str(p)] = ayahs
        if p % 50 == 0 or p == PAGES:
            print("page %d/%d  polys=%d" % (p, PAGES, stats["polys"]), flush=True)

    doc = {
        "version": 1,
        "edition": EDITION,
        "source": "quranpedia/quran-svg (CC0-1.0); KFQC glyphs free for digital use",
        "coords": "normalized 0..1 of each page viewBox, y grows downward",
        "schema": "pages[page] = [ [surah, ayah, [ring,...]], ... ]; ring = [[x,y],...]",
        "pages": pages_out,
    }
    with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))

    print("\n--- done ---")
    print("pages          :", len(pages_out))
    print("ayah polygons  :", stats["polys"])
    print("total rings    :", stats["rings"])
    print("multi-ring ayah:", stats["multiline"])
    print("svgs downloaded:", stats["downloaded"])
    print("json           :", OUT_JSON,
          "%.2f MB" % (os.path.getsize(OUT_JSON) / 1048576))


if __name__ == "__main__":
    main()
