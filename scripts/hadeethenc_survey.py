# -*- coding: utf-8 -*-
"""Measure HadeethEnc before crawling it. Numbers, not estimates.

موسوعة الأحاديث النبوية (hadeethenc.com) publishes, for every hadith, the Arabic
text **and a translation** with its own `attribution` (تخريج) and `grade`
(درجة) in each language it carries — which is what makes it usable here at all:
CLAUDE.md §1.2 forbids a grading without a named source, and this API names one
per language.

This script only counts. It writes `hadeethenc_survey.txt` (UTF-8 — the Windows
console is cp1256 and cannot print Arabic, CLAUDE.md trap #10) with:
  * which of the app's seven locales the API actually serves
  * the top-level categories and how many hadiths each holds
  * one full record, so the field names are read rather than assumed

Run this before the crawler, and read the output.
"""

import io
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://hadeethenc.com/api/v1"
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]

# Some hosts answer a bare urllib request with 403 (CLAUDE.md trap #19).
_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) RafeeqAlDarb/1.0 "
       "(personal, non-commercial)")


def get(path, tries=4):
    url = "%s/%s" % (API, path)
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": _UA})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001 - retried, then reported
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise SystemExit("%s failed after %d tries: %s" % (url, tries, last))


def main():
    out = io.open(os.path.join(ROOT, "hadeethenc_survey.txt"), "w",
                  encoding="utf-8")

    langs = get("languages")
    codes = {x["code"] for x in langs}
    out.write("languages served: %d\n" % len(langs))
    out.write("of the app's seven: %s\n" % ", ".join(
        "%s=%s" % (c, "yes" if c in codes else "NO") for c in LOCALES))
    missing = [c for c in LOCALES if c not in codes]
    out.write("MISSING: %s\n\n" % (", ".join(missing) if missing else "none"))

    cats = get("categories/list/?language=ar")
    tops = [c for c in cats if str(c.get("parent_id") or "0") == "0"]
    out.write("categories: %d total, %d top-level\n\n" % (len(cats), len(tops)))

    total = 0
    for c in tops:
        # per_page=1 still reports the full count in the pagination block.
        page = get("hadeeths/list/?language=ar&category_id=%s&page=1"
                   "&per_page=1" % c["id"])
        meta = page.get("pagination") or {}
        n = int(meta.get("total_records") or meta.get("total") or 0)
        total += n
        out.write("  id=%-5s %-40s %6d\n" % (c["id"], c.get("title", ""), n))
    out.write("\ntop-level total: %d hadiths\n" % total)
    out.write("requests for a full crawl (7 languages): %d\n\n"
              % (total * len(LOCALES)))

    # One whole record per language, so the field names are read, not guessed.
    ids = get("hadeeths/list/?language=ar&category_id=%s&page=1&per_page=1"
              % tops[0]["id"])
    sample_id = (ids.get("data") or ids.get("hadeeths") or [])[0]["id"]
    out.write("---- one record, id=%s ----\n" % sample_id)
    for code in LOCALES:
        try:
            rec = get("hadeeths/one/?language=%s&id=%s" % (code, sample_id))
        except SystemExit as e:
            out.write("\n== %s: FAILED %s\n" % (code, e))
            continue
        out.write("\n== %s   keys: %s\n" % (code, ", ".join(sorted(rec))))
        for k in ("title", "hadeeth", "attribution", "grade", "explanation"):
            v = rec.get(k)
            if isinstance(v, str) and v.strip():
                out.write("   %-12s %s\n" % (k, v.strip()[:220]))
    out.close()
    print("wrote hadeethenc_survey.txt")


if __name__ == "__main__":
    sys.exit(main())
