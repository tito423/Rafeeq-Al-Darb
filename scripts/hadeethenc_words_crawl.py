# -*- coding: utf-8 -*-
"""Fetch the three Arabic fields the first crawl dropped, for every hadith.

WHAT WAS MISSING AND WHY IT MATTERS
`hadeethenc_crawl.py` stored `hadeeth_ar`, `attribution_ar` and `grade_ar`
beside each translation, but the API also returns **`words_meanings_ar`** —
معاني الكلمات, a per-hadith glossary of its difficult words — plus
`explanation_ar` and `hints_ar`. None of the three were kept. The glossary is
the one a reader actually reaches for: it is what turns a vocalised classical
sentence into something a non-specialist can follow.

Only the Arabic record is fetched, once per hadith, because these three fields
are the same whichever language you ask for. That is 3,574 requests rather
than 15,498.

RESUMABLE, like the original crawl: every row is committed as it arrives and
skipped on the next run, so a session that dies mid-crawl loses only the rows
it had not reached.

    py -3 scripts/hadeethenc_words_crawl.py            # crawl
    py -3 scripts/hadeethenc_words_crawl.py --status   # what is stored so far
"""

import io
import json
import os
import sqlite3
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "hadeethenc.db")
API = "https://hadeethenc.com/api/v1"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) RafeeqAlDarb/1.0 "
      "(personal, non-commercial)")
PAUSE = 0.2


def get(path, tries=5):
    """`curl`, not urllib — trap #12: urllib took 43 s per request against a
    host where curl took 0.5 s, and msys Python has no CA bundle at all."""
    url = "%s/%s" % (API, path)
    for attempt in range(tries):
        out = subprocess.run(["curl", "-sS", "--fail", "-A", UA, url],
                             capture_output=True)
        if out.returncode == 0 and out.stdout:
            try:
                return json.loads(out.stdout.decode("utf-8"))
            except ValueError:
                pass
        time.sleep(1.5 * (attempt + 1))
    return None


def ensure_columns(con):
    have = {r[1] for r in con.execute("PRAGMA table_info(hadeeths)")}
    for col in ("words_meanings_ar", "explanation_ar", "hints_ar"):
        if col not in have:
            con.execute("ALTER TABLE hadeeths ADD COLUMN %s TEXT" % col)
    con.commit()


def status(con):
    total = con.execute("SELECT COUNT(*) FROM hadeeths").fetchone()[0]
    done = con.execute(
        "SELECT COUNT(*) FROM hadeeths WHERE words_meanings_ar IS NOT NULL"
    ).fetchone()[0]
    withwords = con.execute(
        "SELECT COUNT(*) FROM hadeeths WHERE words_meanings_ar NOT IN ('', '[]')"
    ).fetchone()[0]
    print("%d hadiths, %d fetched, %d of those carry a glossary"
          % (total, done, withwords))


def main():
    con = sqlite3.connect(DB)
    ensure_columns(con)
    if "--status" in sys.argv:
        status(con)
        return

    todo = [r[0] for r in con.execute(
        "SELECT id FROM hadeeths WHERE words_meanings_ar IS NULL "
        "ORDER BY CAST(id AS INTEGER)")]
    print("%d to fetch" % len(todo))

    done = 0
    for hid in todo:
        rec = get("hadeeths/one/?language=ar&id=%s" % hid)
        if rec is None:
            print("  gave up on %s" % hid)
            continue
        con.execute(
            "UPDATE hadeeths SET words_meanings_ar=?, explanation_ar=?, "
            "hints_ar=? WHERE id=?",
            (json.dumps(rec.get("words_meanings_ar") or [],
                        ensure_ascii=False),
             rec.get("explanation_ar") or rec.get("explanation") or "",
             json.dumps(rec.get("hints_ar") or rec.get("hints") or [],
                        ensure_ascii=False),
             hid))
        done += 1
        if done % 100 == 0:
            con.commit()
            print("  %d/%d" % (done, len(todo)), flush=True)
        time.sleep(PAUSE)
    con.commit()
    status(con)


if __name__ == "__main__":
    main()
