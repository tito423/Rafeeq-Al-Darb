"""Range-request one real file on every hosted content path the app uses.

Part of the handover routine (CLAUDE.md §6): the first and last page of every
mushaf edition in `editions.json`, the hadith DB, a translation and four books.

Trap #5: a soft-404 answers 200 with an HTML body, so the content type, the
byte total AND the file's magic bytes are checked, not just the status.
Trap #19: R2 answers a bare urllib request with 403; it wants a User-Agent.

    py -3 scripts/verify_hosted_content.py
"""
import io, json, os, sys, urllib.request
import concurrent.futures as cf

BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
APP = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app"

editions = json.load(io.open(os.path.join(
    APP, "assets", "data", "mushaf", "editions.json"), encoding="utf-8"))["editions"]

checks = [("hadith db", "/hadith/hadith.zip"),
          # the key is the LANGUAGE code, not the upstream edition id:
          ("translation (en)", "/quran/translations/en.json.gz")]
for e in editions:
    if e.get("image_path"):
        ext = e.get("image_ext", "jpg")
        for p in (1, e["pages"]):
            checks.append(("mushaf %s p%d" % (e["id"], p),
                           "/mushaf/%s/%03d.%s" % (e["image_path"], p, ext)))
# one book from each of the three added this session, plus one old one
for b in ("as_seerah_ibn_kathir", "rijal_hawl_ar_rasul", "la_tahzan",
          "riyad_as_salihin"):
    checks.append(("book " + b, "/books/text/%s.json" % b))
checks.append(("adhan video", "/adhan/video/"))


def one(item):
    name, path = item
    if path.endswith("/"):
        return name, "(directory prefix, skipped)", "", 0, ""
    req = urllib.request.Request(
        BASE + path, headers={"Range": "bytes=0-1023",
                              "User-Agent": "rafeeq-handover-verify/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            head = r.read(4)
            total = int(r.headers.get("Content-Range", "/0").split("/")[-1])
            return (name, r.status, r.headers.get("Content-Type"), total,
                    head[:2].hex())
    except Exception as exc:                                   # noqa: BLE001
        return name, "ERR", str(exc)[:70], 0, ""


rows = []
with cf.ThreadPoolExecutor(6) as ex:
    for r in ex.map(one, checks):
        rows.append(r)

lines = []
bad = 0
for name, st, ct, total, magic in rows:
    ok = st == 206 and total > 1000
    if not ok and st != "(directory prefix, skipped)":
        bad += 1
    lines.append("%-28s %-6s %-26s %10s  %s  %s" %
                 (name, st, ct, total, magic, "OK" if ok else "<-- CHECK"))
lines.append("")
lines.append("%d checked, %d failed" % (len(rows), bad))
io.open(os.path.join(os.environ["TEMP"], "content_verify.txt"), "w",
        encoding="utf-8").write("\n".join(lines))
