"""Turn a scanned mushaf PDF into the `mushaf/<id>/NNN.jpg` page set the app
reads, and upload it to R2.

WHY A SCRIPT AND NOT A ONE-OFF
    The owner wants ten verified printings and five are shipping, so this will
    be run again. Everything that differs between printings is a constant at
    the top; nothing about a particular book is buried in the code.

THE TWO THINGS THAT MUST BE MEASURED, NEVER ASSUMED
    1. **Where page 1 is.** A scanned mushaf PDF carries a cover, title pages
       and an afterword. For مصحف قطر the mushaf's page 1 (al-Fatiha) is PDF
       index 4 and page 604 is index 607 — established by rendering indices
       606-608 and reading the printed folios (٦٠٣, ٦٠٤, then the afterword's
       أ). Get this wrong by one and every page in the app is off by one.
    2. **That the printing really has the pages you claim.** Page 604 of the
       Qatar printing sets al-Ikhlas, al-Falaq and an-Nas, and page 603 sets
       al-Kafirun, an-Nasr and al-Masad — the same division as the Madinah
       mushaf. That is what licenses `hafs_pagination: true`.

    Trap #5 applies at the other end too: nothing goes in the catalogue until
    a range request on the real public endpoint answers 206 with a real
    `Content-Type` and a real byte size. Eight editions once shipped whose
    pages all 404'd.

    py -3 scripts/build_mushaf_from_pdf.py qatar --render
    py -3 scripts/build_mushaf_from_pdf.py qatar --upload
    py -3 scripts/build_mushaf_from_pdf.py qatar --verify
"""

import argparse
import concurrent.futures as cf
import io
import json
import os
import sys
import urllib.request

import fitz                                   # PyMuPDF
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client       # noqa: E402  (Avast/TLS, trap #13)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "scripts", "mushaf_pdf_build")
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"

EDITIONS = {
    "qatar": dict(
        pdf="qatar.pdf",
        # archive.org identifier + the licence it states. The Qatar printing is
        # the only candidate found this session carrying an explicit open
        # licence; the Taj Company 16-line scan was rejected because its own
        # back page prints «جملہ حقوق محفوظ» and a copyright warning.
        source="https://archive.org/details/QuranMushafQatar",
        licence="CC BY-NC-SA 3.0 (as stated on the archive.org item)",
        pages=604,
        first_index=4,        # PDF index of mushaf page 1 — MEASURED, see above
        width=880,            # output width in px; height follows each scan
        quality=84,
        # SIX pages differ between this archive.org item and a second copy of
        # the SAME scan set (`holy-quran-in-high-quality-qatar-interpret-
        # network-15-lines`). That the two are one scan set is not assumed:
        # every one of the other 598 pages is byte-identical between them, and
        # each differing page has the same byte length in both — the signature
        # of a corrupted copy, not a different scan.
        #
        # Four of the six are visibly damaged here and clean there, so those
        # four are lifted from the second copy. This is recovery of the same
        # file, not a mix of sources.
        #   p5    a pink wash over the whole sheet
        #   p167  a grey wash over the whole sheet
        #   p210  a flat green block over most of the sheet
        #   p323  a torn orange band across the lower border
        # p241 and p385 also differ, but both copies of each are clean — the
        # difference there is confined to glyph edges, i.e. re-encoding, not
        # damage — so those keep the primary copy.
        patch_pdf="qatar_alt.pdf",
        patch_pages=(5, 167, 210, 323),
    ),
}


def render(spec, out_dir, only=None):
    doc = fitz.open(os.path.join(WORK, spec["pdf"]))
    patch = (fitz.open(os.path.join(WORK, spec["patch_pdf"]))
             if spec.get("patch_pdf") else None)
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for page in range(1, spec["pages"] + 1):
        if only and page not in only:
            continue
        idx = spec["first_index"] + page - 1
        patched = page in spec.get("patch_pages", ())
        src = (patch if patched else doc)[idx]
        if patched:
            # The second copy carries a "www.Quranpdf.blogspot.com" watermark
            # drawn as TEXT over the top of every page — it is not in the
            # embedded scan, only in the PDF. Redact the text and leave the
            # image alone, or the four repaired pages would ship defaced while
            # their 600 neighbours are clean.
            for b in src.get_text("dict")["blocks"]:
                if b["type"] != 0:
                    continue
                for line in b["lines"]:
                    for sp in line["spans"]:
                        src.add_redact_annot(fitz.Rect(sp["bbox"]))
            src.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)
        # Scale from the page's own rect so a scan cropped slightly differently
        # from its neighbours keeps its true proportions instead of being
        # stretched to a common box.
        zoom = spec["width"] / src.rect.width
        pix = src.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
        img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
        path = os.path.join(out_dir, "%03d.jpg" % page)
        img.save(path, "JPEG", quality=spec["quality"], optimize=True,
                 progressive=False)
        total += os.path.getsize(path)
        if page % 50 == 0 or page == spec["pages"]:
            print(f"  rendered {page}/{spec['pages']}  ({total/1e6:.1f} MB)")
    return total


def upload(edition, out_dir, spec):
    s3 = r2_client()

    def one(page):
        path = os.path.join(out_dir, "%03d.jpg" % page)
        key = f"mushaf/{edition}/%03d.jpg" % page
        with open(path, "rb") as f:
            s3.upload_fileobj(f, BUCKET, key,
                              ExtraArgs={"ContentType": "image/jpeg"})
        remote = s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
        return page, remote, os.path.getsize(path)

    bad = []
    done = 0
    with cf.ThreadPoolExecutor(8) as ex:
        for page, remote, localsz in ex.map(one, range(1, spec["pages"] + 1)):
            done += 1
            if remote != localsz:
                bad.append((page, remote, localsz))
            if done % 100 == 0:
                print(f"  uploaded {done}/{spec['pages']}")
    print(f"  size mismatches: {bad if bad else 'none'}")
    return not bad


def verify(edition, spec):
    """A 1 KB range request per page against the REAL public endpoint."""
    def one(page):
        url = f"{PUBLIC}/mushaf/{edition}/%03d.jpg" % page
        req = urllib.request.Request(
            url, headers={"Range": "bytes=0-1023",
                          "User-Agent": "rafeeq-mushaf-verify/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                head = r.read(4)
                total = r.headers.get("Content-Range", "/0").split("/")[-1]
                return page, r.status, r.headers.get("Content-Type"), \
                    int(total), head[:2] == b"\xff\xd8"
        except Exception as e:                                # noqa: BLE001
            return page, f"ERR {e}", None, 0, False

    bad, sizes = [], []
    with cf.ThreadPoolExecutor(8) as ex:
        for page, st, ct, total, jpeg in ex.map(one, range(1, spec["pages"] + 1)):
            # Trap #5: a soft-404 answers 200 with an HTML body, so the
            # content type, the byte total AND the JPEG magic all get checked.
            if st != 206 or ct != "image/jpeg" or total < 20000 or not jpeg:
                bad.append((page, st, ct, total, jpeg))
            else:
                sizes.append(total)
    print(f"  {len(sizes)}/{spec['pages']} pages answer 206 image/jpeg with "
          f"a real JPEG header")
    if sizes:
        print(f"  bytes: min {min(sizes)}  max {max(sizes)}  "
              f"total {sum(sizes)/1e6:.1f} MB")
    if bad:
        print(f"  FAILED {len(bad)}: {bad[:10]}")
    return not bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("edition", choices=sorted(EDITIONS))
    ap.add_argument("--render", action="store_true")
    ap.add_argument("--only", nargs="*", type=int,
                    help="re-render just these pages (e.g. the patched ones)")
    ap.add_argument("--upload", action="store_true")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()

    spec = EDITIONS[a.edition]
    out_dir = os.path.join(WORK, a.edition)

    if a.render:
        total = render(spec, out_dir, only=set(a.only) if a.only else None)
        print(f"rendered {spec['pages']} pages, {total/1e6:.1f} MB -> {out_dir}")
    if a.upload:
        if not upload(a.edition, out_dir, spec):
            sys.exit(1)
    if a.verify:
        ok = verify(a.edition, spec)
        report = os.path.join(WORK, f"{a.edition}_verify.json")
        io.open(report, "w", encoding="utf-8").write(
            json.dumps({"edition": a.edition, "all_pages_ok": ok,
                        "source": spec["source"], "licence": spec["licence"]},
                       ensure_ascii=False, indent=1))
        print(f"wrote {report}")
        if not ok:
            sys.exit(1)


if __name__ == "__main__":
    main()
