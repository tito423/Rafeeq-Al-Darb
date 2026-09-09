# -*- coding: utf-8 -*-
"""Crawl HadeethEnc into `hadeethenc.db` — resumable, and honest about gaps.

WHY THIS SOURCE AND NOT A TRANSLATION OF OUR OWN
The nine collections in `hadith.db` are 67,153 hadiths and nothing translates
that corpus into Spanish, French, Portuguese, Russian or Urdu with a grading
anyone would stand behind. موسوعة الأحاديث النبوية (hadeethenc.com) publishes a
smaller, curated corpus **with a per-language `attribution` (تخريج) and `grade`
(درجة)** — measured, not assumed: see `hadeethenc_survey.txt`, which prints one
whole record in all seven of the app's languages. CLAUDE.md §1.2 forbids a
grading without a named source; this API carries one, in the reader's own
language, which is exactly what makes it usable.

An earlier session told the owner no Spanish or Portuguese hadith translation
existed in any redistributable source. That was wrong. This is the correction.

WHAT IS STORED, AND WHAT IS NOT INVENTED
Each hadith's list entry names the languages that hadith actually has
(`translations`). Only those are fetched, and a language a hadith lacks is
simply absent — never filled from another language, never guessed. The Arabic
comes back with every call, so `hadeeth_ar`, `grade_ar` and `attribution_ar`
are stored beside each translation and can be compared later.

RESUMABLE ON PURPOSE
Roughly 4,300 hadiths across seven languages is ~30,000 requests; a session
that dies mid-crawl must not start over. Every (id, language) row is committed
as it arrives and skipped on the next run.

    py -3 scripts/hadeethenc_crawl.py            # ids, then all languages
    py -3 scripts/hadeethenc_crawl.py --ids      # just refresh the id list
    py -3 scripts/hadeethenc_crawl.py --status   # what is in the DB so far
"""

import io
import json
import os
import sqlite3
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "hadeethenc.db")
API = "https://hadeethenc.com/api/v1"
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) RafeeqAlDarb/1.0 "
      "(personal, non-commercial)")

# Polite, and slow enough that a personal project is not a load problem.
PAUSE = 0.25


def get(path, tries=5):
    url = "%s/%s" % (API, path)
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(2.0 * (attempt + 1))
    raise RuntimeError("%s failed: %s" % (url, last))


def db():
    con = sqlite3.connect(DB)
    con.execute("""CREATE TABLE IF NOT EXISTS hadeeths (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        category_title_ar TEXT,
        langs TEXT)""")
    con.execute("""CREATE TABLE IF NOT EXISTS texts (
        id TEXT, lang TEXT,
        title TEXT, hadeeth TEXT, attribution TEXT, grade TEXT,
        explanation TEXT, hints TEXT, reference TEXT,
        hadeeth_ar TEXT, attribution_ar TEXT, grade_ar TEXT,
        PRIMARY KEY (id, lang))""")
    con.execute("CREATE INDEX IF NOT EXISTS texts_lang ON texts(lang)")
    con.commit()
    return con


def collect_ids(con):
    cats = get("categories/list/?language=ar")
    tops = [c for c in cats if str(c.get("parent_id") or "0") == "0"]
    print("top-level categories: %d" % len(tops))
    seen = 0
    for c in tops:
        page, last = 1, 1
        while page <= last:
            res = get("hadeeths/list/?language=ar&category_id=%s&page=%d"
                      "&per_page=100" % (c["id"], page))
            meta = res.get("meta") or {}
            last = int(meta.get("last_page") or 1)
            rows = res.get("data") or []
            for h in rows:
                con.execute(
                    "INSERT OR IGNORE INTO hadeeths"
                    " (id, category_id, category_title_ar, langs)"
                    " VALUES (?,?,?,?)",
                    (str(h["id"]), str(c["id"]), c.get("title", ""),
                     ",".join(h.get("translations") or [])))
                seen += 1
            con.commit()
            print("  cat %-4s page %3d/%-3d  ids so far %d"
                  % (c["id"], page, last, seen), flush=True)
            page += 1
            time.sleep(PAUSE)
    total = con.execute("SELECT COUNT(*) FROM hadeeths").fetchone()[0]
    print("distinct hadith ids: %d" % total)
    return total


def fetch_texts(con):
    rows = con.execute("SELECT id, langs FROM hadeeths ORDER BY id").fetchall()
    done = {(i, l) for i, l in
            con.execute("SELECT id, lang FROM texts").fetchall()}
    todo = []
    for hid, langs in rows:
        have = set((langs or "").split(","))
        for code in LOCALES:
            if code in have and (hid, code) not in done:
                todo.append((hid, code))
    print("to fetch: %d (id, language) pairs" % len(todo), flush=True)

    n = 0
    for hid, code in todo:
        try:
            rec = get("hadeeths/one/?language=%s&id=%s" % (code, hid))
        except RuntimeError as e:
            print("  SKIP %s/%s: %s" % (hid, code, e), flush=True)
            continue
        con.execute(
            "INSERT OR REPLACE INTO texts (id, lang, title, hadeeth,"
            " attribution, grade, explanation, hints, reference, hadeeth_ar,"
            " attribution_ar, grade_ar) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (hid, code,
             rec.get("title") or "", rec.get("hadeeth") or "",
             rec.get("attribution") or "", rec.get("grade") or "",
             rec.get("explanation") or "",
             json.dumps(rec.get("hints") or [], ensure_ascii=False),
             rec.get("reference") or "",
             rec.get("hadeeth_ar") or "", rec.get("attribution_ar") or "",
             rec.get("grade_ar") or ""))
        n += 1
        if n % 50 == 0:
            con.commit()
            print("  %d / %d" % (n, len(todo)), flush=True)
        time.sleep(PAUSE)
    con.commit()
    print("stored %d records" % n)


def status(con):
    out = io.open(os.path.join(ROOT, "hadeethenc_status.txt"), "w",
                  encoding="utf-8")
    total = con.execute("SELECT COUNT(*) FROM hadeeths").fetchone()[0]
    out.write("hadith ids: %d\n\n" % total)
    out.write("%-5s %8s %8s %8s\n" % ("lang", "stored", "graded", "attrib"))
    for code in LOCALES:
        got = con.execute("SELECT COUNT(*) FROM texts WHERE lang=?",
                          (code,)).fetchone()[0]
        graded = con.execute(
            "SELECT COUNT(*) FROM texts WHERE lang=? AND TRIM(grade)<>''",
            (code,)).fetchone()[0]
        attrib = con.execute(
            "SELECT COUNT(*) FROM texts WHERE lang=? AND TRIM(attribution)<>''",
            (code,)).fetchone()[0]
        out.write("%-5s %8d %8d %8d\n" % (code, got, graded, attrib))
    out.close()
    print("wrote hadeethenc_status.txt")


def main():
    con = db()
    args = sys.argv[1:]
    if "--status" in args:
        status(con)
        return
    if con.execute("SELECT COUNT(*) FROM hadeeths").fetchone()[0] == 0 \
            or "--ids" in args:
        collect_ids(con)
    if "--ids" not in args:
        fetch_texts(con)
    status(con)


if __name__ == "__main__":
    main()
