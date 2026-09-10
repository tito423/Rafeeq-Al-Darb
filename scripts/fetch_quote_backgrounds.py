# -*- coding: utf-8 -*-
"""Collect photographic backgrounds for the quote card from Wikimedia Commons,
keeping only files whose licence is verifiably public domain or CC0.

WHY COMMONS AND NOT A STOCK SITE.
The owner asked for «صور من النت، كمية كبيرة وجودة عالية». CLAUDE.md trap #18
is that a free image is not automatically free to rehost, and this project
reads the licence before it takes anything. Pixabay and Pexels both answer 403
without an API key; Mixkit's licence text is rendered by JavaScript and could
not be read at all — and an unreadable licence is a no. Wikimedia Commons
states the licence of every file **machine-readably**, through
`prop=imageinfo&iiprop=extmetadata`, so each candidate can be checked one by
one instead of trusting a site-wide claim.

WHAT IS ACCEPTED.
Only `LicenseShortName` matching the public-domain / CC0 set below. CC BY and
CC BY-SA are deliberately excluded: BY needs an attribution beside the image
and this is a full-bleed background with a saying on it, and SA's reach over a
composited derivative is not something to guess at. Nothing whose licence
cannot be read is kept.

WHAT IS PRODUCED.
`dist/quote_backgrounds/<id>.jpg` — 1080×1920, cropped to the phone's shape so
nothing has to be upscaled at draw time — plus `quote_backgrounds.json`, the
manifest carrying each file's Commons page, author and licence, which is what
the Sources screen and `assets/data/quote_backgrounds.json` are built from.

    py -3 scripts/fetch_quote_backgrounds.py
"""

import io
import json
import os
import re
import subprocess
import time
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "dist", "quote_backgrounds")
MANIFEST = os.path.join(ROOT, "quote_backgrounds.json")
API = "https://commons.wikimedia.org/w/api.php"
# Wikimedia's User-Agent policy wants the tool named and a way to reach
# whoever is running it. Without a contact in the UA, `upload.wikimedia.org`
# answers **429 to every single request** — the first run of this script wrote
# 2,280-byte rate-limit pages into .jpg files and reported nothing downloaded.
# CLAUDE.md trap #19 is the same shape: R2 403s a request with no UA at all.
UA = ("RafeeqAlDarb/3.10 (https://github.com/tito423/Rafeeq-Al-Darb; "
      "personal non-commercial Islamic app) curl/8")

# Commons asks for one request at a time from a script; this is slower
# than the burst that got a 429 and finishes in well under a minute.
PAUSE = 1.2

# Downloads need a longer gap than API calls do. At 1.2 s upload.wikimedia.org
# throttled every single one of 37 files while a hand-run curl to the same URL
# in the same minute answered 200 with 7.3 MB — the limiter is per-burst, not
# per-request, and a script that never pauses never gets out of it.
DOWNLOAD_PAUSE = 3.0

# CATEGORIES, NOT A FREE-TEXT SEARCH.
# The first attempt searched Commons for phrases like «islamic star pattern
# stone» and the top hits were **Hindu temple carvings from Karnataka** —
# which would have shipped as "Islamic backgrounds" if the pictures had not
# been looked at. Category membership is curated by Commons editors and is a
# far stronger claim about what a file IS than a text match on its
# description. Every category below is an Islamic-ornament or
# Islamic-architecture category.
CATEGORIES = [
    "Islamic geometric patterns",
    "Muqarnas",
    "Zellige",
    "Girih",
    "Mashrabiya",
    "Iznik pottery",
    "Mihrabs",
    "Islamic ornaments",
    "Arabesques",
    "Ceilings of mosques",
    "Domes of mosques (interior)",
    "Tile mosaics in Iran",
]

# Anything outside this set is dropped, whatever else the page says.
FREE = re.compile(
    r"^(public domain|cc0|cc-zero|pd-\w+|no restrictions)", re.I)


def api(**params):
    """One API call, politely.

    Commons answers **HTTP 429** to a burst, and the first run of this script
    fired ten searches and five batched lookups back to back and got throttled
    on every lookup. Because `api()` swallowed the failure and returned `{}`,
    the script printed «0 of them are public domain or CC0» — a measurement
    artefact that reads exactly like "there is nothing there". Rate limiting
    is now waited out and retried, and a call that still fails says so instead
    of returning an empty answer that looks like data.
    """
    params.update(format="json", formatversion="2")
    url = "%s?%s" % (API, urllib.parse.urlencode(params))
    for attempt in range(6):
        # The status code is appended on its own line so a 429 can be told
        # from a 200 without `--fail` hiding the body.
        out = subprocess.run(
            ["curl", "-sS", "-w", chr(10) + "%{http_code}", "-A", UA, url],
            capture_output=True)
        body = out.stdout.decode("utf-8", "replace")
        code = body.rsplit(chr(10), 1)[-1].strip()
        body = body.rsplit(chr(10), 1)[0]
        if code == "200":
            time.sleep(PAUSE)
            try:
                return json.loads(body)
            except ValueError:
                return {}
        if code == "429":
            time.sleep(4 * (attempt + 1))
            continue
        time.sleep(2)
    raise RuntimeError("Commons kept refusing: %s (last code %s)"
                       % (url[:120], code))


def candidates():
    seen = []
    for cat in CATEGORIES:
        r = api(action="query", list="categorymembers",
                cmtitle="Category:%s" % cat, cmtype="file", cmlimit=40)
        for hit in r.get("query", {}).get("categorymembers", []):
            t = hit["title"]
            if t.lower().endswith((".jpg", ".jpeg", ".png")) and t not in seen:
                seen.append(t)
    return seen


def licence_of(titles):
    """{title: {...}} for the ones whose licence is verifiably free."""
    keep = {}
    for i in range(0, len(titles), 25):
        batch = titles[i:i + 25]
        r = api(action="query", titles="|".join(batch), prop="imageinfo",
                iiprop="url|extmetadata|size",
                iiextmetadatafilter="LicenseShortName|UsageTerms|Artist|"
                                    "Credit|ImageDescription")
        for page in r.get("query", {}).get("pages", []):
            info = (page.get("imageinfo") or [{}])[0]
            meta = info.get("extmetadata") or {}
            lic = (meta.get("LicenseShortName", {}).get("value") or "").strip()
            if not FREE.match(lic):
                continue
            if info.get("width", 0) < 1600 or info.get("height", 0) < 1200:
                continue      # too small to fill a phone without upscaling
            artist = re.sub(r"<[^>]+>", "",
                            meta.get("Artist", {}).get("value") or "").strip()
            keep[page["title"]] = {
                "title": page["title"],
                "url": info.get("url"),
                "page": info.get("descriptionurl"),
                "licence": lic,
                "usage_terms": (meta.get("UsageTerms", {}).get("value")
                                or "").strip(),
                "author": artist or "—",
                "width": info.get("width"),
                "height": info.get("height"),
            }
    return keep


def fetch_file(url, dst):
    """Download one image, waiting out the 429 that a burst earns.

    `upload.wikimedia.org` throttles as readily as the API does, and a
    truncated 2 KB error page written to a .jpg is the kind of "downloaded
    fine" that ships broken content.
    """
    last = ""
    for attempt in range(6):
        out = subprocess.run(
            ["curl", "-sS", "-A", UA, "-w", "%{http_code}", url, "-o", dst],
            capture_output=True)
        code = out.stdout.decode("utf-8", "replace").strip()[-3:]
        size = os.path.getsize(dst) if os.path.exists(dst) else 0
        last = "code=%s size=%d" % (code, size)
        # 50 KB is well under any real photograph and well over the 2,280-byte
        # rate-limit page that the first run wrote into .jpg files.
        if code == "200" and size > 50000:
            time.sleep(DOWNLOAD_PAUSE)
            return True
        if os.path.exists(dst):
            os.remove(dst)
        time.sleep(6 * (attempt + 1))
    print("    last attempt: %s" % last)
    return False


def slug(title):
    s = title[len("File:"):] if title.startswith("File:") else title
    s = os.path.splitext(s)[0].lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    return s[:48] or "bg"


def main():
    os.makedirs(OUT, exist_ok=True)
    titles = candidates()
    print("%d candidate files" % len(titles))
    free = licence_of(titles)
    print("%d of them are public domain or CC0" % len(free))

    ffmpeg = r"C:\Program Files\ShareX\ffmpeg.exe"
    rows = []
    for t, row in sorted(free.items()):
        vid = slug(t)
        # Named from the slug, NOT from the URL. The API appends
        # `?utm_source=...&utm_campaign=...` to every file URL, and a Windows
        # filename cannot contain `?` or `*` — curl reported **code=200
        # size=0** for all 37 files because it could not create the path it
        # was given. A 200 that writes nothing is the most misleading kind of
        # success there is.
        src = os.path.join(OUT, "_src_%s%s" % (
            vid, os.path.splitext(urllib.parse.urlparse(row["url"]).path)[1]))
        dst = os.path.join(OUT, "%s.jpg" % vid)
        if not os.path.exists(dst):
            if not fetch_file(row["url"], src):
                print("  could not fetch %s" % row["title"])
                continue
            # Cover-crop to the phone's shape here rather than at draw time,
            # so the device never scales up and the file stays small.
            subprocess.run([
                ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                "-i", src,
                "-vf", "scale=1080:1920:force_original_aspect_ratio=increase,"
                       "crop=1080:1920",
                "-q:v", "4", dst], capture_output=True)
            if os.path.exists(src):
                os.remove(src)
        if not os.path.exists(dst):
            continue
        row["id"] = vid
        row["bytes"] = os.path.getsize(dst)
        rows.append(row)

    with io.open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("\n%-50s %-22s %9s" % ("id", "licence", "bytes"))
    for r in rows:
        print("%-50s %-22s %9d" % (r["id"], r["licence"][:22], r["bytes"]))
    print("\n%d prepared in %s\nmanifest: %s" % (len(rows), OUT, MANIFEST))
    print("LOOK AT THEM before uploading (CLAUDE.md \u00a71.1/\u00a71.3).")


if __name__ == "__main__":
    main()
