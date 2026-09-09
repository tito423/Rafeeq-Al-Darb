# -*- coding: utf-8 -*-
"""How often HadeethEnc hands back a takhrij or a grading it never translated.

The brief for this stage says to measure this before deciding what the hadith
card looks like, because a card that always promises «التخريج» and «الدرجة» in
the reader's language will be lying wherever the source did not translate them
— and CLAUDE.md §1.2 does not allow filling that in from another language.

Two things are counted per language, per field:

  * **verbatim Arabic** — the field is byte-identical to the Arabic original
    the same record carries (`attribution_ar` / `grade_ar`). That is the source
    saying "no translation" without saying so.
  * **empty** — the field came back blank.

For the five Latin-script languages a third number is reported: the share of
letters in the field that are Arabic. It catches a field that is *mostly*
Arabic without being byte-identical, which equality alone would miss.

    py -3 scripts/hadeethenc_gap_report.py

Writes `hadeethenc_gaps.txt` in UTF-8 and prints nothing but ASCII — the
Windows console here is cp1256 and cannot print Arabic (CLAUDE.md #10).
"""

import io
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "hadeethenc.db")
OUT = os.path.join(ROOT, "hadeethenc_gaps.txt")

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]
# Urdu is written in Arabic script, so "how Arabic does this look" says
# nothing there — only the verbatim test does.
LATIN_SCRIPT = {"en", "es", "fr", "pt", "ru"}


def arabic_share(text):
    letters = [c for c in text if c.isalpha()]
    if not letters:
        return None
    arabic = sum(1 for c in letters if 0x0600 <= ord(c) <= 0x06FF)
    return arabic / float(len(letters))


def main():
    if not os.path.exists(DB):
        sys.stdout.write("hadeethenc.db is not here yet\n")
        return
    con = sqlite3.connect("file:%s?mode=ro" % DB.replace("\\", "/"), uri=True)
    out = io.open(OUT, "w", encoding="utf-8")

    total = con.execute("SELECT COUNT(*) FROM texts").fetchone()[0]
    ids = con.execute("SELECT COUNT(*) FROM hadeeths").fetchone()[0]
    out.write(u"rows crawled so far: %d   distinct hadiths: %d\n\n"
              % (total, ids))
    out.write(u"%-5s %7s | %-26s | %-26s\n"
              % ("lang", "rows", "attribution (takhrij)", "grade"))
    out.write(u"%-5s %7s | %8s %8s %8s | %8s %8s %8s\n"
              % ("", "", "same", "empty", "arabic", "same", "empty", "arabic"))
    out.write(u"-" * 84 + u"\n")

    for code in LOCALES:
        rows = con.execute(
            "SELECT attribution, attribution_ar, grade, grade_ar"
            " FROM texts WHERE lang=?", (code,)).fetchall()
        if not rows:
            continue
        n = len(rows)
        counts = {"a_same": 0, "a_empty": 0, "a_arabic": 0,
                  "g_same": 0, "g_empty": 0, "g_arabic": 0}
        for attribution, attribution_ar, grade, grade_ar in rows:
            attribution = (attribution or "").strip()
            attribution_ar = (attribution_ar or "").strip()
            grade = (grade or "").strip()
            grade_ar = (grade_ar or "").strip()

            if not attribution:
                counts["a_empty"] += 1
            elif attribution == attribution_ar:
                counts["a_same"] += 1
            if not grade:
                counts["g_empty"] += 1
            elif grade == grade_ar:
                counts["g_same"] += 1

            if code in LATIN_SCRIPT:
                share = arabic_share(attribution)
                if share is not None and share > 0.5:
                    counts["a_arabic"] += 1
                share = arabic_share(grade)
                if share is not None and share > 0.5:
                    counts["g_arabic"] += 1

        def pct(k):
            return u"%5.1f%%" % (100.0 * counts[k] / n)

        out.write(u"%-5s %7d | %8s %8s %8s | %8s %8s %8s\n"
                  % (code, n, pct("a_same"), pct("a_empty"),
                     pct("a_arabic") if code in LATIN_SCRIPT else u"    -",
                     pct("g_same"), pct("g_empty"),
                     pct("g_arabic") if code in LATIN_SCRIPT else u"    -"))

    # A couple of real examples, so the numbers can be read against the text
    # they describe rather than trusted on their own.
    out.write(u"\nsamples where Urdu kept the Arabic verbatim:\n")
    for hid, attribution, grade in con.execute(
            "SELECT id, attribution, grade FROM texts"
            " WHERE lang='ur' AND TRIM(attribution)<>''"
            " AND attribution = attribution_ar LIMIT 3"):
        out.write(u"  id %s\n    takhrij: %s\n    grade:   %s\n"
                  % (hid, attribution, grade))

    out.write(u"\nsamples where Urdu DID translate:\n")
    for hid, attribution, grade in con.execute(
            "SELECT id, attribution, grade FROM texts"
            " WHERE lang='ur' AND TRIM(attribution)<>''"
            " AND attribution <> attribution_ar LIMIT 3"):
        out.write(u"  id %s\n    takhrij: %s\n    grade:   %s\n"
                  % (hid, attribution, grade))

    out.close()
    sys.stdout.write("wrote hadeethenc_gaps.txt\n")


if __name__ == "__main__":
    main()
