"""Build the real cover thumbnail for each mushaf edition.

The edition tiles used to draw a cover: a leather-coloured board with a gold
frame and a medallion, generated in Flutter. It looked fine, but it was an
illustration — every printing got the same board in a different colour. The
owner asked for the actual covers of these printings instead.

Each one here is the edition's own cover or title page, taken from a public
archive.org item, trimmed of its scan margin and saved as a small JPEG that
ships inside the app so the tile is instant and works offline.

Note on `madinah_gold`: that edition has no printed cover, because it is not a
printing. Its archive.org item ("Smart Mushaf") describes itself as vector
Qur'an pages already on the internet with colours and borders added — the
Madinah typesetting, illuminated digitally. So its own first page is used,
which is honestly what the edition looks like, and its name says so.

    py -3 scripts/build_mushaf_covers.py
"""
import io
import os
import sys
import urllib.request

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "rafeeq_app", "assets", "mushaf_covers")

# edition id -> (source url, human note, bottom crop fraction)
# The bottom crop removes a banner that is not part of the cover.
SOURCES = {
    "hafs_kfqc": (
        "https://archive.org/download/Quran-hafs-1442/page/n0_w800.jpg",
        "مصحف المدينة، رواية حفص — صفحة عنوان مجمع الملك فهد", 0.0),
    "tajweed_color": (
        "https://archive.org/download/quraan-colored/page/n0_w800.jpg",
        "مصحف التجويد الملوّن، دار المعرفة — الغلاف المطبوع", 0.0),
    "warsh": (
        "https://archive.org/download/Warsh-HD/page/n0_w800.jpg",
        "مصحف المدينة، رواية ورش — صفحة عنوان مجمع الملك فهد", 0.0),
    "qaloon": (
        "https://archive.org/download/mushaf-qalun/page/n0_w800.jpg",
        "مصحف المدينة، رواية قالون — صفحة عنوان مجمع الملك فهد", 0.0),
    "shamarly": (
        "https://archive.org/download/QURANShamarly/page/n0_w800.jpg",
        "مصحف الشمرلي — صفحة العنوان بخط محمد سعد إبراهيم", 0.055),
    "indopak_tajweed": (
        "https://archive.org/download/TajweediColor-codedQuranByZia-ul-quran"
        "/page/n0_w800.jpg",
        "المصحف الهندي الملوّن، ضياء القرآن — الغلاف المطبوع", 0.0),
    "madinah_gold": (
        "https://archive.org/download/smartmushaf/1.jpg",
        "المصحف المذهّب (Smart Mushaf) — صفحته الأولى؛ لا غلاف مطبوع له", 0.0),
}

TARGET_W = 420          # 3:4 board; the tile draws it at ~60-90 logical px


def fetch(url, tries=4):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    last = None
    for _ in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except Exception as e:
            last = e
    raise SystemExit(f"could not fetch {url}: {last}")


def trim_border(im, tol=14):
    """Drop the uniform scan margin around the artwork."""
    bg = Image.new(im.mode, im.size, im.getpixel((2, 2)))
    diff = ImageChops.difference(im, bg).convert("L").point(
        lambda p: 255 if p > tol else 0)
    box = diff.getbbox()
    return im.crop(box) if box else im


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for eid, (url, note, cut_bottom) in SOURCES.items():
        raw = fetch(url)
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        before = im.size
        if cut_bottom:
            im = im.crop((0, 0, im.width, int(im.height * (1 - cut_bottom))))
        im = trim_border(im)
        # Fit to a 3:4 board without distorting the artwork.
        h = int(TARGET_W * 4 / 3)
        im = im.resize((TARGET_W, h), Image.LANCZOS)
        path = os.path.join(OUT_DIR, f"{eid}.jpg")
        im.save(path, "JPEG", quality=84, optimize=True, progressive=True)
        print(f"{eid:18s} {before[0]}x{before[1]} -> {TARGET_W}x{h}  "
              f"{os.path.getsize(path)//1024:3d} KB  | {note}")
    total = sum(os.path.getsize(os.path.join(OUT_DIR, f))
                for f in os.listdir(OUT_DIR))
    print(f"\n{len(SOURCES)} covers, {total//1024} KB total, in {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())
