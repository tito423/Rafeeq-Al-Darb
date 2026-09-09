# -*- coding: utf-8 -*-
"""Fetch the seven top-level HadeethEnc category titles in the app's seven
languages, into `hadeethenc_categories.json`.

WHY THIS IS A SEPARATE STEP
`hadeethenc_crawl.py` walked the category tree in Arabic only — it needed the
ids, not the names — so every row in `hadeeths` carries `category_title_ar` and
nothing else. Building the per-language packs from that alone would put Arabic
section headings above English, Spanish, French, Portuguese and Russian
hadiths. Seven categories times seven languages is 49 requests; there is no
reason to ship the Arabic instead.

Uses `curl`, not `urllib`: CLAUDE.md trap #12 / the seventh session's note —
`urllib` took 43 s per request against `api.aladhan.com` where `curl` took
0.5 s, and msys Python has no CA bundle at all.

    py -3 scripts/hadeethenc_categories.py
"""

import io
import json
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "hadeethenc_categories.json")
API = "https://hadeethenc.com/api/v1"
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) RafeeqAlDarb/1.0 "
      "(personal, non-commercial)")


def get(path):
    out = subprocess.run(
        ["curl", "-sS", "--fail", "-A", UA, "%s/%s" % (API, path)],
        capture_output=True)
    if out.returncode != 0:
        raise RuntimeError("curl failed on %s: %s"
                           % (path, out.stderr.decode("utf-8", "replace")))
    return json.loads(out.stdout.decode("utf-8"))


def main():
    titles = {}
    for lang in LOCALES:
        cats = get("categories/list/?language=%s" % lang)
        # `parent_id` 0 is a top level section; the crawl indexed those and
        # only those, so the packs must not offer any other.
        tops = [c for c in cats if str(c.get("parent_id") or "0") == "0"]
        for c in tops:
            titles.setdefault(str(c["id"]), {})[lang] = c.get("title") or ""
        print("%s: %d top-level categories" % (lang, len(tops)))

    # Refuse to write a half-filled table: a missing title would surface as a
    # blank section heading, which is worse than not shipping the language.
    for cid, byLang in sorted(titles.items(), key=lambda kv: int(kv[0])):
        missing = [l for l in LOCALES if not byLang.get(l)]
        if missing:
            raise SystemExit("category %s has no title in %s"
                             % (cid, ", ".join(missing)))

    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(titles, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print("wrote %s (%d categories x %d languages)"
          % (OUT, len(titles), len(LOCALES)))


if __name__ == "__main__":
    main()
